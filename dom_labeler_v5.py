import pandas as pd
import numpy as np

def apply_triple_barrier_strict_wick(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5):
    """
    V5 STRICT WICK LABELER:
    Evaluates barriers using Intra-bar High and Low to capture real-world stop-outs.
    If the Low hits the SL before the High hits the PT, the Long is dead.
    """
    print(f"Labeler V5: Strict Wick Triple Barrier (PT={pt_multiplier}$, SL={sl_multiplier}$, MaxBars={max_bars})")

    labels = np.zeros(len(df))
    high_prices = df['High'].values
    low_prices = df['Low'].values
    close_prices = df['Close'].values

    for i in range(len(df)):
        if i + 1 >= len(df):
            break

        # Entry at the OPEN of the NEXT bar (No lookahead bias)
        entry_price = df['Open'].iloc[i+1]

        # Absolute dollar barriers
        upper_long_barrier = entry_price + pt_multiplier
        lower_long_barrier = entry_price - sl_multiplier

        lower_short_barrier = entry_price - pt_multiplier
        upper_short_barrier = entry_price + sl_multiplier

        hit = 0 # Default Noise

        for j in range(i+1, min(i+1+max_bars, len(df))):
            curr_high = high_prices[j]
            curr_low = low_prices[j]
            curr_close = close_prices[j]

            # --- LONG EVALUATION ---
            long_pt_hit = curr_high >= upper_long_barrier
            long_sl_hit = curr_low <= lower_long_barrier

            # --- SHORT EVALUATION ---
            short_pt_hit = curr_low <= lower_short_barrier
            short_sl_hit = curr_high >= upper_short_barrier

            # Intra-bar ambiguity resolution (If both SL and PT hit in the SAME bar)
            # We assume worst-case scenario: the SL was hit first.
            if long_pt_hit and long_sl_hit:
                long_pt_hit = False
            if short_pt_hit and short_sl_hit:
                short_pt_hit = False

            if hit == 0:
                if long_pt_hit and not short_pt_hit:
                    hit = 1
                    break
                elif short_pt_hit and not long_pt_hit:
                    hit = -1
                    break
                elif long_sl_hit and short_sl_hit:
                    # Trapped in a massive expanding wick candle, total noise
                    break
                elif long_sl_hit and hit == 0:
                    # Long is dead. But could it still be a short?
                    # Yes, if it didn't hit short SL. But for simplicity and strictness,
                    # if a massive move hit our SL, we consider the immediate entry bad.
                    pass
        labels[i] = hit

    df['Target_Label'] = labels
    return df

def main():
    print("=== 🎯 SCALPER STRICT WICK LABELER V5 ===")

    # 1. Historical Dataset
    data_path = "../data/features_dollar_bars_3MTF_v3.csv"
    print(f"Processing Historical Data: {data_path}")
    df = pd.read_csv(data_path)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df.sort_values('Start_Timestamp', inplace=True)
    df.reset_index(drop=True, inplace=True)

    df_labeled = apply_triple_barrier_strict_wick(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5)
    df_labeled = df_labeled.iloc[:-5]

    print("Historical Label Distribution (V5 Strict):")
    print(df_labeled['Target_Label'].value_counts(normalize=True) * 100)
    df_labeled.to_csv("../data/labeled_dollar_bars_v5_strict.csv", index=False)

    # 2. Exam Dataset (Blind July 20-24)
    exam_path = "../data/exam_blind_features.csv"
    print(f"\nProcessing Exam Data: {exam_path}")
    df_exam = pd.read_csv(exam_path)
    df_exam['Start_Timestamp'] = pd.to_datetime(df_exam['Start_Timestamp'])
    df_exam.sort_values('Start_Timestamp', inplace=True)
    df_exam.reset_index(drop=True, inplace=True)

    df_exam_labeled = apply_triple_barrier_strict_wick(df_exam, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5)
    df_exam_labeled = df_exam_labeled.iloc[:-5]

    print("Exam Label Distribution (V5 Strict):")
    print(df_exam_labeled['Target_Label'].value_counts(normalize=True) * 100)
    df_exam_labeled.to_csv("../data/exam_blind_labeled_v5.csv", index=False)

    print("\n✅ V5 Strict Wick Labels successfully generated for both datasets.")

if __name__ == "__main__":
    main()
