import pandas as pd
import numpy as np
import os
import sys

def calculate_atr(df, period=13):
    high_low = df["Bar_High"] - df["Bar_Low"]
    high_close = np.abs(df["Bar_High"] - df["Bar_Close"].shift())
    low_close = np.abs(df["Bar_Low"] - df["Bar_Close"].shift())
    ranges = pd.concat([high_low, high_close, low_close], axis=1)
    true_range = np.max(ranges, axis=1)
    return true_range.rolling(period).mean()

def apply_fixed_horizon(df, lookahead=1, mult=1.5):
    print("🎯 Fixed Horizon Labeling inditasa...")
    if "ATR" not in df.columns:
        df["ATR"] = calculate_atr(df, 13)

    labels = np.zeros(len(df))
    closes = df["Bar_Close"].values
    atrs = df["ATR"].values

    for i in range(len(df) - lookahead):
        if np.isnan(atrs[i]) or atrs[i] == 0:
            continue

        current_close = closes[i]
        future_close = closes[i + lookahead]

        delta = future_close - current_close
        rel_move = delta / atrs[i]

        if rel_move >= mult:
            labels[i] = 1 # BUY
        elif rel_move <= -mult:
            labels[i] = 2 # SELL
        else:
            labels[i] = 0 # HOLD

    for i in range(len(df) - lookahead, len(df)):
        labels[i] = np.nan

    df["Target"] = labels
    return df

def perform_feature_engineering(df):
    print("🔧 Feature Engineering (M15 Scalping)...")

    # 🔴 AZ UJ M15-hoz IGAZITOTT OSZLOPOK HASZNALATA (H1, H4)
    # A nyers EMA-kbol tavolsagot (Distance) szamolunk ATR-hez viszonyitva
    for col in ["Ctx_EMA_25", "Ctx_EMA_50", "EMA_50_H1"]:
        if col in df.columns:
            df[f"Dist_{col}"] = (df["Bar_Close"] - df[col]) / df["ATR"]

    df["Candle_Range_ATR"] = (df["Bar_High"] - df["Bar_Low"]) / df["ATR"]
    df["Return_1"] = df["Bar_Close"].pct_change(1)
    df["Return_5"] = df["Bar_Close"].pct_change(5)

    oscillators = ["Flow_ROC", "Hybrid_DFCurve", "Hybrid_MACD", "RSI_H1", "RSI_H4", "MACD_H1", "RSI"]
    for col in oscillators:
        if col in df.columns:
            df[f"{col}_Delta"] = df[col] - df[col].shift(1)

    # 🔴 SZEMET KIDOBASA
    cols_to_drop = [
        "Bar_Open", "Bar_High", "Bar_Low", "Bar_Close", "Bid", "Ask",
        "Ctx_EMA_25", "Ctx_EMA_50", "EMA_50_H1",
        "Ctx_EMA_150", "Ctx_EMA_300", "EMA_150_H4",
        "Dist_Ctx_EMA_150", "Dist_Ctx_EMA_300", "Dist_EMA_150_H4",
        "Velocity",
        "Stoch_K"
    ]

    df = df.drop(columns=[c for c in cols_to_drop if c in df.columns])
    df = df.dropna()
    return df

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=str, default="/home/misi/Merkava_ML_Ops/data/raw/Merkava_XAUUSD_MINER_MTF_v1.07_20260623_221200.csv")
    parser.add_argument("--output", type=str, default="/home/misi/Merkava_ML_Ops/data/processed/Merkava_XAUUSD_M15_Engineered.csv")
    args = parser.parse_args()

    DATA_PATH = args.input
    OUTPUT_PATH = args.output

    print(f"📥 Betoltes: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH)

    df = apply_fixed_horizon(df, lookahead=1, mult=1.5) # Alapertekkel, a matrix majt megvaltoztatja
    df = perform_feature_engineering(df)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    df.to_csv(OUTPUT_PATH, index=False)
    print(f"✅ Mentve: {OUTPUT_PATH}")
    print(f"📊 Adat forma: {df.shape}")
