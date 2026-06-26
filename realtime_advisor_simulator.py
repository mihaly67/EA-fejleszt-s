import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
import warnings
warnings.filterwarnings('ignore')
import time

def calculate_atr(df, period):
    high_low = df["Bar_High"] - df["Bar_Low"]
    high_close = np.abs(df["Bar_High"] - df["Bar_Close"].shift())
    low_close = np.abs(df["Bar_Low"] - df["Bar_Close"].shift())
    ranges = pd.concat([high_low, high_close, low_close], axis=1)
    true_range = np.max(ranges, axis=1)
    return true_range.rolling(period).mean()

def prepare_data_and_features(df_raw, lookahead=15, target_mult_trend=0.5, target_mult_sideways=0.15):
    print("🔧 Feature Engineering (M1)...", flush=True)

    # 1. Delták
    indicators = ["Flow_ROC", "Hybrid_DFCurve", "Hybrid_MACD", "Spread", "WPR", "Stoch_K", "Flow_MFI"]
    for col in indicators:
        if col in df_raw.columns:
            df_raw[f"{col}_Delta"] = df_raw[col] - df_raw[col].shift(1)

    df_raw["Return_1"] = df_raw["Bar_Close"].pct_change(1)
    df_raw["Return_5"] = df_raw["Bar_Close"].pct_change(5)

    # 2. Z-Score a Flow-ra
    df_raw["Flow_ROC_Z"] = (df_raw["Flow_ROC"] - df_raw["Flow_ROC"].rolling(100).mean()) / df_raw["Flow_ROC"].rolling(100).std()
    df_raw["Flow_MFI_Z"] = (df_raw["Flow_MFI"] - df_raw["Flow_MFI"].rolling(100).mean()) / df_raw["Flow_MFI"].rolling(100).std()

    # 3. ATR és Távolságok
    df_raw["ATR"] = calculate_atr(df_raw, 7)
    df_raw["Candle_Range_ATR"] = (df_raw["Bar_High"] - df_raw["Bar_Low"]) / df_raw["ATR"]

    for col in ["Ctx_EMA_25", "Ctx_EMA_50", "Ctx_EMA_150"]:
        if col in df_raw.columns:
            df_raw[f"Dist_{col}"] = (df_raw["Bar_Close"] - df_raw[col]) / df_raw["ATR"]

    # 4. HMM Regime Betanítása a teljes adathalmazra (Mivel ez unsupervised, nem okoz lookahead biast)
    print("🧠 HMM Regime Training...", flush=True)
    hmm_features = df_raw[["Return_5", "Candle_Range_ATR", "Flow_MFI"]].dropna().copy()
    scaler = StandardScaler()
    scaled_features = scaler.fit_transform(hmm_features)
    hmm_model = hmm.GaussianHMM(n_components=3, covariance_type="full", n_iter=100, random_state=42)
    hmm_model.fit(scaled_features)
    regimes = hmm_model.predict(scaled_features)

    df_raw.loc[hmm_features.index, "Regime"] = regimes
    sideways_state = df_raw.groupby("Regime")["Candle_Range_ATR"].mean().idxmin()
    df_raw["Is_Sideways"] = (df_raw["Regime"] == sideways_state).astype(int)

    # 5. Labeling (Csak a train/test hasításhoz kell)
    closes = df_raw["Bar_Close"].values
    atrs = df_raw["ATR"].values

    target_trend = np.zeros(len(df_raw))
    target_sideways = np.zeros(len(df_raw))

    for i in range(len(df_raw) - lookahead):
        if np.isnan(atrs[i]) or atrs[i] == 0: continue

        delta = closes[i + lookahead] - closes[i]
        rel_move = delta / atrs[i]

        if rel_move >= target_mult_trend: target_trend[i] = 1
        elif rel_move <= -target_mult_trend: target_trend[i] = 2

        if rel_move >= target_mult_sideways: target_sideways[i] = 1
        elif rel_move <= -target_mult_sideways: target_sideways[i] = 2

    for i in range(len(df_raw) - lookahead, len(df_raw)):
        target_trend[i] = np.nan
        target_sideways[i] = np.nan

    df_raw["Target_Trend"] = target_trend
    df_raw["Target_Sideways"] = target_sideways

    features = ["Return_1", "Return_5", "Flow_ROC_Z", "Flow_MFI_Z", "Candle_Range_ATR"]
    for f in ["RSI", "Dist_Ctx_EMA_25", "Dist_Ctx_EMA_50", "Dist_Ctx_EMA_150"]:
        if f in df_raw.columns: features.append(f)
    for col in indicators:
        if col in df_raw.columns: features.append(col)
        if f"{col}_Delta" in df_raw.columns: features.append(f"{col}_Delta")

    # Remove duplicates from features list to prevent XGBoost DataFrame dtype errors
    features = list(dict.fromkeys(features))

    return df_raw, features, hmm_model, scaler, sideways_state

def train_ensemble(df, features):
    print("🤖 Ensemble Model Training (History)...", flush=True)
    df = df.dropna(subset=features + ["Target_Trend", "Target_Sideways", "Regime"])

    df_trend = df[df["Is_Sideways"] == 0].copy()
    X_trend, y_trend = df_trend[features], df_trend["Target_Trend"]
    weight_trend = compute_sample_weight('balanced', y_trend)
    model_trend = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.05, n_jobs=-1, random_state=42)
    model_trend.fit(X_trend, y_trend, sample_weight=weight_trend)

    df_side = df[df["Is_Sideways"] == 1].copy()
    X_side, y_side = df_side[features], df_side["Target_Sideways"]
    weight_side = compute_sample_weight('balanced', y_side)
    model_sideways = xgb.XGBClassifier(n_estimators=100, max_depth=4, learning_rate=0.05, n_jobs=-1, random_state=42)
    model_sideways.fit(X_side, y_side, sample_weight=weight_side)

    return model_trend, model_sideways

def walk_forward_simulation(df, features, model_trend, model_side, start_idx, end_idx, lookahead=15,
                            thresh_trend=0.55, thresh_side=0.50, mult_trend=0.5, mult_side=0.15):
    print(f"\n🚀 WALK-FORWARD ÉLES SZIMULÁCIÓ ({start_idx} - {end_idx})", flush=True)

    total_signals = 0
    winning_trades = 0
    losing_trades = 0
    whipsawed_trades = 0

    # A kiíratáshoz pici delay-t rakunk, hogy látszódjon a szimuláció, de ne fagyassza le a gépet
    # O(n) iteracio a dataframe-en
    closes = df["Bar_Close"].values
    atrs = df["ATR"].values
    is_sideways = df["Is_Sideways"].values

    for i in range(start_idx, end_idx):
        if np.isnan(atrs[i]): continue

        row_features = df.iloc[i:i+1][features]
        current_close = closes[i]
        future_close = closes[i + lookahead]

        sideways = is_sideways[i]

        # Inference
        if sideways == 1:
            probs = model_side.predict_proba(row_features)[0]
            thresh = thresh_side
            target_mult = mult_side
        else:
            probs = model_trend.predict_proba(row_features)[0]
            thresh = thresh_trend
            target_mult = mult_trend

        p_buy, p_sell = probs[1], probs[2]
        signal = 0 # 1 Buy, 2 Sell
        if p_buy > thresh: signal = 1
        elif p_sell > thresh: signal = 2

        if signal != 0:
            total_signals += 1
            # Ellenőrizzük az eredményt a jövőben
            target_price_buy = current_close + (atrs[i] * target_mult)
            target_price_sell = current_close - (atrs[i] * target_mult)

            actual_delta = future_close - current_close

            if signal == 1:
                if actual_delta >= (atrs[i] * target_mult):
                    winning_trades += 1
                else:
                    losing_trades += 1
            elif signal == 2:
                if actual_delta <= -(atrs[i] * target_mult):
                    winning_trades += 1
                else:
                    losing_trades += 1

            if total_signals % 20 == 0:
                print(f"   [{i}] Jelek: {total_signals} | Win: {winning_trades} | Loss: {losing_trades}", flush=True)

    print("\n" + "="*50)
    print("🏆 SZIMULÁCIÓS EREDMÉNYEK")
    print("="*50)
    print(f"Összes kiadott jelzés: {total_signals}")
    if total_signals > 0:
        win_rate = (winning_trades / total_signals) * 100
        print(f"Nyerő jelek (Célár elérve): {winning_trades}")
        print(f"Vesztes jelek: {losing_trades}")
        print(f"Valós Idejű Win-Rate: {win_rate:.2f}%")

        days_simulated = (end_idx - start_idx) / 1440.0
        print(f"Kötések naponta (Átlag): {total_signals / days_simulated:.1f}")
    print("="*50 + "\n")

if __name__ == "__main__":
    DATA_PATH = "/home/misi/Merkava_ML_Ops/data/raw/Merkava_XAUUSD_MINER_M1_v1.02_20260617_182426.csv"
    print("⏳ Nyers 3 hónapos M1 adat betöltése...")
    df_raw = pd.read_csv(DATA_PATH)

    df_engineered, features, hmm_model, hmm_scaler, sideways_state = prepare_data_and_features(df_raw, lookahead=15)

    # In-Sample Tanítási Szakasz (Az adatok első 70%-a)
    split_index = int(len(df_engineered) * 0.7)
    df_train = df_engineered.iloc[:split_index].copy()
    df_test = df_engineered.iloc[split_index:len(df_engineered)-15].copy() # Walk-forward teszthalmaz

    model_trend, model_side = train_ensemble(df_train, features)

    # Out-of-Sample Walk Forward Szimuláció (Az utolsó 30% napokon, ami vadonatúj adat a modellnek)
    # A DataFrame sorain lépkedünk iteratívan
    walk_forward_simulation(df_engineered, features, model_trend, model_side,
                            start_idx=split_index, end_idx=len(df_engineered)-15,
                            lookahead=15, thresh_trend=0.55, thresh_side=0.50,
                            mult_trend=0.5, mult_side=0.15)
