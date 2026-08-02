import pandas as pd
import numpy as np

def apply_triple_barrier(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5):
    print(f"Labeler V4 (Exam): Applying Asymmetric Triple Barrier (PT={pt_multiplier}$, SL={sl_multiplier}$, MaxBars={max_bars})")

    labels = np.zeros(len(df))
    close_prices = df['Close'].values

    for i in range(len(df)):
        if i + 1 >= len(df):
            break

        entry_price = df['Open'].iloc[i+1]

        upper_long_barrier = entry_price + pt_multiplier
        lower_long_barrier = entry_price - sl_multiplier

        lower_short_barrier = entry_price - pt_multiplier
        upper_short_barrier = entry_price + sl_multiplier

        hit = 0

        for j in range(i+1, min(i+1+max_bars, len(df))):
            future_close = close_prices[j]

            if future_close >= upper_long_barrier:
                hit = 1
                break
            elif future_close <= lower_long_barrier:
                pass

            if future_close <= lower_short_barrier:
                if hit != 1:
                    hit = -1
                break
            elif future_close >= upper_short_barrier:
                pass

        labels[i] = hit

    df['Target_Label'] = labels
    return df

def main():
    print("=== 🎯 SCALPER TRIPLE BARRIER LABELER V4 (EXAM BLIND SET) ===")

    data_path = "../data/exam_blind_fused.csv"
    print(f"Loading data from: {data_path}")
    df = pd.read_csv(data_path)

    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df.sort_values('Start_Timestamp', inplace=True)
    df.reset_index(drop=True, inplace=True)

    df_labeled = apply_triple_barrier(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5)
    df_labeled = df_labeled.iloc[:-5]

    print("\nLabel Distribution (5-Bar Strict):")
    print(df_labeled['Target_Label'].value_counts(normalize=True) * 100)

    out_path = "../data/exam_blind_labeled.csv"
    df_labeled.to_csv(out_path, index=False)
    print(f"\n✅ Exam Labels saved to: {out_path}")

if __name__ == "__main__":
    main()
