import pandas as pd
import numpy as np
import ta

def process_zigzag_features(df):
    """
    Converts raw M1 ZigZag CSV into ATR-normalized distances.
    """
    df = df.copy()
    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    df['ATR_14'] = ta.volatility.AverageTrueRange(high=df['High'], low=df['Low'], close=df['Close'], window=14).average_true_range()

    # Positive distance means price is below resistance (or above support)
    df['Dist_Micro_R'] = (df['Micro_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Micro_S'] = (df['Close'] - df['Micro_S']) / (df['ATR_14'] + 1e-8)
    df['Dist_Sec_R'] = (df['Sec_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Sec_S'] = (df['Close'] - df['Sec_S']) / (df['ATR_14'] + 1e-8)
    df['Dist_Ter_R'] = (df['Ter_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Ter_S'] = (df['Close'] - df['Ter_S']) / (df['ATR_14'] + 1e-8)

    stoch_m1 = ta.momentum.StochasticOscillator(high=df['High'], low=df['Low'], close=df['Close'], window=2, smooth_window=3)
    df['Stoch_State_M1'] = (stoch_m1.stoch() - 50.0) / 50.0

    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.dropna(inplace=True)

    # We only need the timestamps and the new structural columns
    cols_to_keep = ['Time', 'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S', 'Stoch_State_M1']
    return df[cols_to_keep]

def main():
    print("=== 🧬 LGBM FEATURE FUSION (DOLLAR BARS + ZIGZAG MACRO) ===")

    # 1. Load Micro Dollar Bars (Contains OBI, Velocity, etc.)
    dollar_bars_path = "../data/features_dollar_bars_3MTF_v3.csv"
    print(f"Loading Micro Dollar Bars: {dollar_bars_path}")
    df_micro = pd.read_csv(dollar_bars_path)
    df_micro['End_Timestamp'] = pd.to_datetime(df_micro['End_Timestamp'])
    df_micro.sort_values('End_Timestamp', inplace=True)

    # 2. Load Raw ZigZag M1 Data
    macro_path = "../../Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv"
    print(f"Loading Macro ZigZag Data: {macro_path}")
    df_macro_raw = pd.read_csv(macro_path)

    # Process ZigZag to exact geometric features
    print("Engineering ZigZag distances...")
    df_macro = process_zigzag_features(df_macro_raw)

    # 3. Perform AsOf Merge (Forward-Fill)
    # For every Dollar Bar, we look BACKWARDS to the most recent M1 structural data
    print("Fusing datasets (merge_asof)...")
    df_fused = pd.merge_asof(
        df_micro,
        df_macro,
        left_on='End_Timestamp',
        right_on='Time',
        direction='backward'
    )

    # Clean up redundant Time column from merge
    if 'Time' in df_fused.columns:
        df_fused.drop(columns=['Time'], inplace=True)

    df_fused.dropna(inplace=True)

    # 4. Save Fused Dataset
    out_path = "../data/fused_features_dollar_bars.csv"
    df_fused.to_csv(out_path, index=False)
    print(f"✅ Fusion Complete! Saved to: {out_path} ({len(df_fused)} rows)")

if __name__ == "__main__":
    main()
