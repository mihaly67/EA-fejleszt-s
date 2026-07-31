import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import sys
import os

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"

def calculate_macro_regime(df, fast_period=50, slow_period=200):
    """
    Calculates a macro trend regime using EMA crossover logic on the Close prices.
    Since we are using Dollar Bars, we need longer periods to simulate macro trends.
    """
    close_series = df['Close']

    ema_fast = close_series.ewm(span=fast_period, adjust=False).mean()
    ema_slow = close_series.ewm(span=slow_period, adjust=False).mean()

    # 1 for Uptrend, -1 for Downtrend
    regime = np.where(ema_fast > ema_slow, 1, -1)

    # Let's add a 'Sideways' regime if the EMAs are very close to each other
    # This requires defining a threshold, maybe based on ATR or absolute dollar difference
    # For now, keep it binary (Trend/Downtrend) as a strict directional filter

    return pd.Series(regime, index=df.index)

def apply_hard_filter(signal_series, regime_series):
    """
    Applies the Regime Filter as a strict Hard Filter.
    Blocks Short signals (0) in Uptrends (1).
    Blocks Long signals (2) in Downtrends (-1).
    Blocked signals are converted to Noise/Hold (1).
    """
    filtered_signal = signal_series.copy()

    # Block Shorts during Uptrend
    filtered_signal = np.where((regime_series == 1) & (filtered_signal == 0), 1, filtered_signal)

    # Block Longs during Downtrend
    filtered_signal = np.where((regime_series == -1) & (filtered_signal == 2), 1, filtered_signal)

    return filtered_signal

def main():
    print("=== 🛡️ AGENT META-REGIME ANALYZER V5 (HARD FILTER) ===")

    if not os.path.exists(DATA_PATH):
        print(f"Error: {DATA_PATH} not found.")
        return

    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X_test = df[features]

    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # Raw Argmax Signal (0=Short, 1=Noise, 2=Long)
    df['Raw_Signal'] = np.argmax(probs, axis=1)

    # Calculate Macro Regime
    df['Macro_Regime'] = calculate_macro_regime(df, fast_period=50, slow_period=200)

    # Apply Hard Filter
    df['Filtered_Signal'] = apply_hard_filter(df['Raw_Signal'], df['Macro_Regime'])

    # Map Regime to Strings for easier reading
    regime_map = {1: 'Uptrend', -1: 'Downtrend'}
    df['Macro_Trend_Str'] = df['Macro_Regime'].map(regime_map)

    # Find Trend Blocks based on the New Macro Regime
    blocks = []
    current_trend = df['Macro_Trend_Str'].iloc[0]
    start_idx = 0

    for i in range(1, len(df)):
        if df['Macro_Trend_Str'].iloc[i] != current_trend:
            blocks.append((start_idx, i - 1, current_trend))
            current_trend = df['Macro_Trend_Str'].iloc[i]
            start_idx = i
    blocks.append((start_idx, len(df) - 1, current_trend))

    print(f"Total EMA Regime Blocks Found: {len(blocks)}")

    uptrends = [b for b in blocks if b[2] == 'Uptrend']
    uptrends.sort(key=lambda x: x[1]-x[0], reverse=True)

    print("\n--- A LEGHOSSZABB UPTRENDEK ELEMZÉSE (META-REGIME SZŰRŐVEL) ---")
    for start, end, trend in uptrends[:3]:
        block_df = df.iloc[start:end+1]
        length = len(block_df)

        start_price = block_df['Open'].iloc[0]
        end_price = block_df['Close'].iloc[-1]
        price_diff = end_price - start_price

        # Raw Signals
        raw_active = (block_df['Raw_Signal'] != 1).sum()
        raw_longs = (block_df['Raw_Signal'] == 2).sum()
        raw_shorts = (block_df['Raw_Signal'] == 0).sum()

        # Filtered Signals
        filt_active = (block_df['Filtered_Signal'] != 1).sum()
        filt_longs = (block_df['Filtered_Signal'] == 2).sum()
        filt_shorts = (block_df['Filtered_Signal'] == 0).sum()
        filt_noise = (block_df['Filtered_Signal'] == 1).sum()

        blocked_shorts = raw_shorts - filt_shorts

        print(f"\nBlock [{start}-{end}] | {trend} | Bárhossz: {length} bar")
        print(f"  -> Ármozgás: {start_price:.2f} -> {end_price:.2f} (Elmozdulás: {price_diff:+.2f} dollár)")
        print(f"  -> Eredeti Nyers LGBM Aktivitás: {raw_longs} Long / {raw_shorts} Short (Össz: {raw_active})")
        print(f"  -> 🛡️ Meta-Regime Szűrő Eredménye:")
        print(f"     🟢 Engedélyezett Trend irányú (LONG): {filt_longs} db")
        print(f"     🔴 Blokkolt Kontratrend (SHORT): {blocked_shorts} db blokkolva -> NOISE lett")
        print(f"     ⚪ Végleges Aktivitás: {filt_active}/{length} ({filt_active/length*100:.1f}%)")

if __name__ == "__main__":
    main()
