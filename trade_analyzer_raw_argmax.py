import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import sys

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"

def determine_trend(rsi):
    if pd.isna(rsi): return 'Unknown'
    if rsi > 55: return 'Uptrend'
    elif rsi < 45: return 'Downtrend'
    else: return 'Sideways'

def main():
    print("=== 🕵️ AGENT DEEP DIVE ANALYZER V4 (RAW ARGMAX) ===")

    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X_test = df[features]

    df['Macro_Trend'] = df['M15_RSI_14'].apply(determine_trend)

    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # TISZTA ARGMAX
    df['Signal'] = np.argmax(probs, axis=1)

    # Keresünk egybefüggő blokkokat
    blocks = []
    current_trend = df['Macro_Trend'].iloc[0]
    start_idx = 0

    for i in range(1, len(df)):
        if df['Macro_Trend'].iloc[i] != current_trend:
            blocks.append((start_idx, i - 1, current_trend))
            current_trend = df['Macro_Trend'].iloc[i]
            start_idx = i
    blocks.append((start_idx, len(df) - 1, current_trend))

    print(f"Total Trend Blocks Found: {len(blocks)}")

    uptrends = [b for b in blocks if b[2] == 'Uptrend']
    # Keresünk egy kifejezetten hosszú Uptrendet
    uptrends.sort(key=lambda x: x[1]-x[0], reverse=True)

    print("\n--- A LEGHOSSZABB UPTRENDEK ELEMZÉSE ---")
    for start, end, trend in uptrends[:3]: # A top 3 leghosszabb
        block_df = df.iloc[start:end+1]
        length = len(block_df)

        # Árfolyam elmozdulás a blokk alatt
        start_price = block_df['Open'].iloc[0]
        end_price = block_df['Close'].iloc[-1]
        price_diff = end_price - start_price

        active_signals = (block_df['Signal'] != 1).sum()
        long_signals = (block_df['Signal'] == 2).sum()
        short_signals = (block_df['Signal'] == 0).sum()
        noise_signals = (block_df['Signal'] == 1).sum()

        print(f"\nBlock [{start}-{end}] | {trend} | Bárhossz: {length} bar")
        print(f"  -> Ármozgás: {start_price:.2f} -> {end_price:.2f} (Elmozdulás: {price_diff:+.2f} dollár)")
        print(f"  -> Total Aktivitás: {active_signals}/{length} ({active_signals/length*100:.1f}%)")
        print(f"  -> 🟢 Trend irányú belépés (LONG): {long_signals} db")
        print(f"  -> 🔴 Kontratrend belépés (SHORT): {short_signals} db")
        print(f"  -> ⚪ Néma marad (NOISE): {noise_signals} db")

if __name__ == "__main__":
    main()
