import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
import warnings
warnings.filterwarnings('ignore')

def calculate_atr(df, period):
    high_low = df["Bar_High"] - df["Bar_Low"]
    high_close = np.abs(df["Bar_High"] - df["Bar_Close"].shift())
    low_close = np.abs(df["Bar_Low"] - df["Bar_Close"].shift())
    ranges = pd.concat([high_low, high_close, low_close], axis=1)
    true_range = np.max(ranges, axis=1)
    return true_range.rolling(period).mean()

def prepare_data(df_raw, lookahead=15, target_mult_trend=1.0, target_mult_sideways=0.2):
    """ Feature Engineering és Target Labeling a teljes történelmi adathalmazon """
    
    # 1. Alapvető Delta Feature-ök
    oscillators = ["Flow_ROC", "Hybrid_DFCurve", "Hybrid_MACD", "RSI_M5", "RSI_M15", "MACD_M5"]
    micro_indicators = ["Spread", "Velocity", "Acceleration", "WPR", "Stoch_K", "Flow_MFI"]
    
    for col in oscillators + micro_indicators:
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
            
    # 4. HMM Regime
    hmm_features = df_raw[["Return_5", "Candle_Range_ATR", "Flow_MFI"]].dropna().copy()
    scaler = StandardScaler()
    scaled_features = scaler.fit_transform(hmm_features)
    hmm_model = hmm.GaussianHMM(n_components=3, covariance_type="full", n_iter=100, random_state=42)
    hmm_model.fit(scaled_features)
    regimes = hmm_model.predict(scaled_features)
    
    df_raw.loc[hmm_features.index, "Regime"] = regimes
    sideways_state = df_raw.groupby("Regime")["Candle_Range_ATR"].mean().idxmin()
    df_raw["Is_Sideways"] = (df_raw["Regime"] == sideways_state).astype(int)
    
    # 5. Labeling (Külön Trend és Sideways Target)
    closes = df_raw["Bar_Close"].values
    atrs = df_raw["ATR"].values
    
    target_trend = np.zeros(len(df_raw))
    target_sideways = np.zeros(len(df_raw))
    
    for i in range(len(df_raw) - lookahead):
        if np.isnan(atrs[i]) or atrs[i] == 0: continue
            
        delta = closes[i + lookahead] - closes[i]
        rel_move = delta / atrs[i]
        
        # Trend Label (Nagyobb cél)
        if rel_move >= target_mult_trend: target_trend[i] = 1
        elif rel_move <= -target_mult_trend: target_trend[i] = 2
        
        # Sideways Label (Kisebb cél)
        if rel_move >= target_mult_sideways: target_sideways[i] = 1
        elif rel_move <= -target_mult_sideways: target_sideways[i] = 2
            
    for i in range(len(df_raw) - lookahead, len(df_raw)):
        target_trend[i] = np.nan
        target_sideways[i] = np.nan
        
    df_raw["Target_Trend"] = target_trend
    df_raw["Target_Sideways"] = target_sideways
    
    features = ["Return_1", "Return_5", "Flow_ROC_Z", "Flow_MFI_Z", "Flow_ROC_Delta", "Hybrid_MACD_Delta", "Candle_Range_ATR"]
    for f in ["RSI", "MACD", "Dist_Ctx_EMA_25", "Dist_Ctx_EMA_50", "Dist_Ctx_EMA_150", "RSI_M5", "MACD_M5"]:
        if f in df_raw.columns: features.append(f)
    for col in micro_indicators:
        if col in df_raw.columns: features.append(col)
        if f"{col}_Delta" in df_raw.columns: features.append(f"{col}_Delta")
            
    return df_raw, features, hmm_model, scaler, sideways_state

def train_ensemble(df, features):
    """ Betanítja az Ensemble modelleket a Múlt (History) alapján """
    df = df.dropna(subset=features + ["Target_Trend", "Target_Sideways", "Regime"])
    
    # 1. Trend Modell (Ahol a HMM NEM Sideways)
    df_trend = df[df["Is_Sideways"] == 0].copy()
    X_trend, y_trend = df_trend[features], df_trend["Target_Trend"]
    weight_trend = compute_sample_weight('balanced', y_trend)
    model_trend = xgb.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.05, n_jobs=-1, random_state=42)
    model_trend.fit(X_trend, y_trend, sample_weight=weight_trend)
    
    # 2. Sideways Modell (Ahol a HMM Sideways)
    df_side = df[df["Is_Sideways"] == 1].copy()
    X_side, y_side = df_side[features], df_side["Target_Sideways"]
    weight_side = compute_sample_weight('balanced', y_side)
    model_sideways = xgb.XGBClassifier(n_estimators=100, max_depth=4, learning_rate=0.05, n_jobs=-1, random_state=42)
    model_sideways.fit(X_side, y_side, sample_weight=weight_side)
    
    return model_trend, model_sideways

def advisor_inference(df_present, features, hmm_model, hmm_scaler, sideways_state, model_trend, model_side):
    """ On-Demand Tanácsadó az épp aktuális pillanatra (Az utolsó sor) """
    
    latest_row = df_present.iloc[-1:]
    
    # Jelenlegi HMM Állapot lekérdezése
    hmm_feat = latest_row[["Return_5", "Candle_Range_ATR", "Flow_MFI"]].fillna(0)
    scaled_feat = hmm_scaler.transform(hmm_feat)
    current_regime = hmm_model.predict(scaled_feat)[0]
    
    is_sideways = (current_regime == sideways_state)
    market_phase = "OLDALAZÓ (Zajos, Range-Bound)" if is_sideways else "VOLATILIS TRENDELŐ"
    
    print("\n" + "="*60)
    print("📈 JULES ON-DEMAND ADVISOR: JELENIDEJŰ PIACI ELEMZÉS")
    print("="*60)
    print(f"Időpont: {latest_row['Time'].values[0]}")
    print(f"Árfolyam: {latest_row['Bar_Close'].values[0]:.2f}")
    print(f"ATR (Volatilitás): {latest_row['ATR'].values[0]:.2f} USD")
    print(f"PIACI REZSIM (HMM): {market_phase}")
    print("-" * 60)
    
    # XGBoost Predikció
    X_latest = latest_row[features]
    
    if is_sideways:
        print("🤖 Betöltött ML Engine: MIKRO-TREND SIDEWAYS MODELL (Cél: 0.2x ATR)")
        probs = model_side.predict_proba(X_latest)[0]
        # Sidewaysnél pici a hozamelvárás, de nagyobb a zaj
        thresh = 0.50
    else:
        print("🤖 Betöltött ML Engine: TREND SCALPING MODELL (Cél: 1.0x ATR)")
        probs = model_trend.predict_proba(X_latest)[0]
        # Trendnél nagyobb cél, szigorúbb küszöb
        thresh = 0.60
        
    p_hold, p_buy, p_sell = probs[0], probs[1], probs[2]
    
    print("\n🔮 XGBOOST VALÓSZÍNŰSÉGI ELOSZLÁS (Következő 15 perc):")
    print(f"   - HOLD (Oldalazás/Zaj): {p_hold*100:.1f}%")
    print(f"   - BUY (Felfelé kitörés): {p_buy*100:.1f}%")
    print(f"   - SELL (Lefelé letörés): {p_sell*100:.1f}%")
    print("-" * 60)
    
    # Tanács
    print("🎯 VÉGSŐ TANÁCS (ADVISOR JAVASLAT):")
    if p_buy > thresh:
        print("   >>> ERŐS VÉTEL (BUY) JELZÉS! <<<")
        print(f"   A Modell >{thresh*100}% magabiztossággal vár felfelé elmozdulást.")
    elif p_sell > thresh:
        print("   >>> ERŐS ELADÁS (SELL) JELZÉS! <<<")
        print(f"   A Modell >{thresh*100}% magabiztossággal vár lefelé elmozdulást.")
    else:
        print("   >>> KIVÁRÁS (Nincs egyértelmű jel) <<<")
        print(f"   A modell {p_hold*100:.1f}% eséllyel azt várja, hogy az ár nem éri el a profit szintet a megadott időn belül.")
        print("   Kockázatos belépni. Várj a következő gyertyára.")
    print("="*60 + "\n")

if __name__ == "__main__":
    DATA_PATH = "/home/misi/Merkava_ML_Ops/data/raw/Merkava_XAUUSD_MINER_M1_SCRIPT_v1.04_20260618_022831.csv"
    print("⏳ Múltbéli adatok betöltése a memóriába (History)...")
    
    # Tanító halmaz: Betöltjük a múltat (M1, utolsó 500k sor = ~1 év)
    df_raw = pd.read_csv(DATA_PATH).tail(500000).copy()
    df_raw.reset_index(drop=True, inplace=True)
    
    # Feature Engineering és HMM
    df_engineered, features, hmm_model, hmm_scaler, sideways_state = prepare_data(df_raw)
    
    # Betanítjuk az Ensemble modelleket (A jövőbeli EA-ban ezt elég hetente egyszer lefuttatni és ONNX-ként elmenteni)
    print("🧠 ML Modeller Betanítása (Ensemble: Trend + Sideways)...")
    # A tanításhoz levágjuk az utolsó 15 sort, hogy az On-Demand tesztnek tényleg "új" legyen
    df_train = df_engineered.iloc[:-15]
    model_trend, model_side = train_ensemble(df_train, features)
    
    # A jelen szimulálása: A felhasználó MOST megnyitja a chartot. Ráeresztjük a gépet a legutolsó létező sorra.
    print("🚀 Éles Rendszer (Advisor) Aktiválása a Jelenben...")
    df_present = df_engineered.tail(1) 
    
    advisor_inference(df_present, features, hmm_model, hmm_scaler, sideways_state, model_trend, model_side)
