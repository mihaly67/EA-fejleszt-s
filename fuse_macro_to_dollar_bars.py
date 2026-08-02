import pandas as pd
import numpy as np
import ta

def process_zigzag_features(df):
    df = df.copy()
    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    df['ATR_14'] = ta.volatility.AverageTrueRange(high=df['High'], low=df['Low'], close=df['Close'], window=14).average_true_range()

    # Existing Geometric Distances
    df['Dist_Micro_R'] = (df['Micro_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Micro_S'] = (df['Close'] - df['Micro_S']) / (df['ATR_14'] + 1e-8)
    df['Dist_Sec_R'] = (df['Sec_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Sec_S'] = (df['Close'] - df['Sec_S']) / (df['ATR_14'] + 1e-8)
    df['Dist_Ter_R'] = (df['Ter_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Ter_S'] = (df['Close'] - df['Ter_S']) / (df['ATR_14'] + 1e-8)

    # NEW WICK GEOMETRY (Giving the model explicit awareness of dangerous wicks)
    df['Upper_Wick'] = df['High'] - np.maximum(df['Open'], df['Close'])
    df['Lower_Wick'] = np.minimum(df['Open'], df['Close']) - df['Low']

    df['Upper_Wick_ATR'] = df['Upper_Wick'] / (df['ATR_14'] + 1e-8)
    df['Lower_Wick_ATR'] = df['Lower_Wick'] / (df['ATR_14'] + 1e-8)

    stoch_m1 = ta.momentum.StochasticOscillator(high=df['High'], low=df['Low'], close=df['Close'], window=2, smooth_window=3)
    df['Stoch_State_M1'] = (stoch_m1.stoch() - 50.0) / 50.0

    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.dropna(inplace=True)

    cols_to_keep = ['Time', 'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S', 'Stoch_State_M1', 'Upper_Wick_ATR', 'Lower_Wick_ATR']
    return df[cols_to_keep]

def main():
    print("=== 🧬 LGBM FEATURE FUSION V2 (WICK GEOMETRY ADDED) ===")

    # FUSE HISTORICAL
    print("\n[1] Fusing Historical Data...")
    df_micro_hist = pd.read_csv("../data/features_dollar_bars_3MTF_v3.csv")
    df_micro_hist['End_Timestamp'] = pd.to_datetime(df_micro_hist['End_Timestamp'])
    df_micro_hist.sort_values('End_Timestamp', inplace=True)

    df_macro_raw = pd.read_csv("../../Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv")
    df_macro = process_zigzag_features(df_macro_raw)

    df_fused_hist = pd.merge_asof(df_micro_hist, df_macro, left_on='End_Timestamp', right_on='Time', direction='backward')
    if 'Time' in df_fused_hist.columns: df_fused_hist.drop(columns=['Time'], inplace=True)
    df_fused_hist.dropna(inplace=True)
    df_fused_hist.to_csv("../data/fused_features_dollar_bars.csv", index=False)

    # FUSE EXAM (July 20-24)
    print("\n[2] Fusing Exam Data...")
    df_micro_exam = pd.read_csv("../data/exam_blind_features.csv")
    df_micro_exam['End_Timestamp'] = pd.to_datetime(df_micro_exam['End_Timestamp'])
    df_micro_exam.sort_values('End_Timestamp', inplace=True)

    df_fused_exam = pd.merge_asof(df_micro_exam, df_macro, left_on='End_Timestamp', right_on='Time', direction='backward')
    if 'Time' in df_fused_exam.columns: df_fused_exam.drop(columns=['Time'], inplace=True)
    df_fused_exam.dropna(inplace=True)
    df_fused_exam.to_csv("../data/exam_blind_fused.csv", index=False)

    print(f"\n✅ Fusion Complete! Both Historical and Exam datasets updated with Wick Features.")

if __name__ == "__main__":
    main()
