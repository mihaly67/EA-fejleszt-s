import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.utils.class_weight import compute_sample_weight
import time

def calculate_atr(df, period):
    high_low = df["Bar_High"] - df["Bar_Low"]
    high_close = np.abs(df["Bar_High"] - df["Bar_Close"].shift())
    low_close = np.abs(df["Bar_Low"] - df["Bar_Close"].shift())
    ranges = pd.concat([high_low, high_close, low_close], axis=1)
    true_range = np.max(ranges, axis=1)
    return true_range.rolling(period).mean()

def run_matrix():
    start_time = time.time()

    DATA_PATH = "/home/misi/Merkava_ML_Ops/data/raw/Merkava_XAUUSD_MINER_MTF_v1.06_20260623_124144.csv" # A kérésnek megfelelően csökkentve az 5 perces időablak csv-re (azonosítva: Merkava_XAUUSD_MINER_MTF_v1.06_20260623_124144.csv a header/tail alapján)
    df_raw = pd.read_csv(DATA_PATH).tail(120000).copy() # 120k M5 gyertya ~ 1,5 év adat
    df_raw.reset_index(drop=True, inplace=True)

    oscillators = ["Flow_ROC", "Hybrid_DFCurve", "Hybrid_MACD", "RSI_M15", "RSI_H1", "MACD_M15"]
    for col in oscillators:
        if col in df_raw.columns:
            df_raw[f"{col}_Delta"] = df_raw[col] - df_raw[col].shift(1)

    # Újra bevett mikro-struktúra indikátorok deltái
    micro_indicators = ["Spread", "Velocity", "Acceleration", "WPR", "Stoch_K", "Flow_MFI"]
    for col in micro_indicators:
        if col in df_raw.columns:
            df_raw[f"{col}_Delta"] = df_raw[col] - df_raw[col].shift(1)

    df_raw["Return_1"] = df_raw["Bar_Close"].pct_change(1)
    df_raw["Return_5"] = df_raw["Bar_Close"].pct_change(5)

    periods = [3, 7, 13]
    multipliers = [0.5, 1.0, 1.5, 2.0]
    lookahead = 3 # 3 x 5 perc = 15 perc (M5 gyertya fixed horizon scalping)

    closes = df_raw["Bar_Close"].values

    results = []
    print("START M5 FIXED HORIZON MATRIX (15m predikció)", flush=True)

    for period in periods:
        atr_values = calculate_atr(df_raw, period).values
        for mult in multipliers:
            labels = np.zeros(len(df_raw))

            for i in range(len(df_raw) - lookahead):
                if np.isnan(atr_values[i]) or atr_values[i] == 0:
                    continue

                current_close = closes[i]
                future_close = closes[i + lookahead]

                delta = future_close - current_close
                rel_move = delta / atr_values[i]

                if rel_move >= mult:
                    labels[i] = 1 # BUY
                elif rel_move <= -mult:
                    labels[i] = 2 # SELL
                else:
                    labels[i] = 0 # HOLD

            for i in range(len(df_raw) - lookahead, len(df_raw)):
                labels[i] = np.nan

            df_raw["Target"] = labels
            df_raw["Candle_Range_ATR"] = (df_raw["Bar_High"] - df_raw["Bar_Low"]) / atr_values
            for col in ["Ctx_EMA_25", "EMA_50_M15"]:
                df_raw[f"Dist_{col}"] = (df_raw["Bar_Close"] - df_raw[col]) / atr_values

            features = ["Return_1", "Return_5", "Flow_ROC", "Flow_ROC_Delta", "Hybrid_MACD_Delta", "Candle_Range_ATR",
                        "Dist_Ctx_EMA_25", "Dist_EMA_50_M15", "RSI_M15", "RSI_H1", "MACD_M15"]

            # Adjuk hozzá a mikro indikátorokat is a feature készlethez, ha léteznek
            for col in micro_indicators:
                if col in df_raw.columns:
                    features.append(col)
                if f"{col}_Delta" in df_raw.columns:
                    features.append(f"{col}_Delta")

            df_model = df_raw[features + ["Target"]].copy()
            df_model = df_model.dropna()

            split_idx = int(len(df_model) * 0.8)
            train = df_model.iloc[:split_idx]
            test = df_model.iloc[split_idx:]

            X_train, y_train = train[features], train["Target"]
            X_test, y_test = test[features], test["Target"]

            # Súlyozott modell + Probability Thresholding
            sample_weights = compute_sample_weight('balanced', y_train)
            model = xgb.XGBClassifier(n_estimators=50, max_depth=4, learning_rate=0.1, n_jobs=-1, random_state=42)
            model.fit(X_train, y_train, sample_weight=sample_weights)

            probs = model.predict_proba(X_test)
            preds = np.zeros(len(probs))

            for idx, p in enumerate(probs):
                if p[1] > 0.65:
                    preds[idx] = 1
                elif p[2] > 0.65:
                    preds[idx] = 2
                else:
                    preds[idx] = 0

            acc = accuracy_score(y_test, preds) * 100

            hold_pct = (len(df_model[df_model["Target"] == 0]) / len(df_model)) * 100

            # Súlyozott metrikák
            precision_w = precision_score(y_test, preds, average='macro', labels=[1, 2], zero_division=0)
            recall_w = recall_score(y_test, preds, average='macro', labels=[1, 2], zero_division=0)
            f1_w = f1_score(y_test, preds, average='macro', labels=[1, 2], zero_division=0)

            results.append({
                "ATR": period,
                "Mult": mult,
                "Hold_%": round(hold_pct, 1),
                "XGB_Acc_%": round(acc, 1),
                "Precision": round(precision_w * 100, 2),
                "Recall": round(recall_w * 100, 2),
                "F1_Score": round(f1_w * 100, 2)
            })

    res_df = pd.DataFrame(results)
    print(res_df.sort_values(by="F1_Score", ascending=False).to_string(index=False), flush=True)

if __name__ == "__main__":
    run_matrix()
