import pandas as pd
import numpy as np

def apply_triple_barrier(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5):
    """
    Applies Asymmetric Triple Barrier Labeling aligned with 5-Bar Micro-Scalping logic.
    - Long (+1) if Upper Barrier (PT) hit before Lower Barrier (SL) and within max_bars.
    - Short (-1) if Lower Barrier (PT) hit before Upper Barrier (SL) and within max_bars.
    - Noise (0) if neither hit within max_bars (Vertical Barrier).

    NOTE: The Dollar Bar target is an exact Dollar amount.
    PT = 1.5 Dollars (15 Ticks for Micro Gold)
    SL = 1.0 Dollar (10 Ticks)
    """
    print(f"Labeler V4: Applying Asymmetric Triple Barrier (PT={pt_multiplier}$, SL={sl_multiplier}$, MaxBars={max_bars})")

    labels = np.zeros(len(df))
    close_prices = df['Close'].values

    # We iterate over the dataset to evaluate future paths
    for i in range(len(df)):
        # We enter the trade at the OPEN of the next bar (i+1) to absolutely prevent Lookahead Bias!
        if i + 1 >= len(df):
            break

        entry_price = df['Open'].iloc[i+1]

        # Define the exact dollar barriers from the ENTRY price
        upper_long_barrier = entry_price + pt_multiplier
        lower_long_barrier = entry_price - sl_multiplier

        lower_short_barrier = entry_price - pt_multiplier
        upper_short_barrier = entry_price + sl_multiplier

        hit = 0 # Default is Noise (0)

        # Look forward up to 'max_bars'
        for j in range(i+1, min(i+1+max_bars, len(df))):
            # We strictly evaluate against future CLOSE prices to avoid intra-bar illusions
            future_close = close_prices[j]

            # --- EVALUATE LONG STATE ---
            if future_close >= upper_long_barrier:
                hit = 1
                break
            elif future_close <= lower_long_barrier:
                # Long stopped out. Can it still be a valid Short? We don't break immediately,
                # we just know it's not a Long. But to keep logic clean, if SL hit, it's noise for long.
                pass

            # --- EVALUATE SHORT STATE ---
            if future_close <= lower_short_barrier:
                if hit != 1: # Only if long didn't already hit
                    hit = -1
                break
            elif future_close >= upper_short_barrier:
                pass

        labels[i] = hit

    df['Target_Label'] = labels
    return df

def main():
    print("=== 🎯 SCALPER TRIPLE BARRIER LABELER V4 (5-BAR STRICT) ===")

    # Load the pure features dataset (which contains the OHLC required for barrier evaluation)
    data_path = "../data/features_dollar_bars_3MTF_v3.csv"
    print(f"Loading data from: {data_path}")
    df = pd.read_csv(data_path)

    # Ensure Time sorting
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df.sort_values('Start_Timestamp', inplace=True)
    df.reset_index(drop=True, inplace=True)

    # Apply strict 5-bar barrier
    # Optuna logic: Micro-trends exhaust quickly. If it doesn't move 1.5 points in 5 bars, it's noise.
    df_labeled = apply_triple_barrier(df, pt_multiplier=1.5, sl_multiplier=1.0, max_bars=5)

    # We drop the last rows that couldn't be evaluated fully
    df_labeled = df_labeled.iloc[:-5]

    print("\nLabel Distribution (5-Bar Strict):")
    print(df_labeled['Target_Label'].value_counts(normalize=True) * 100)

    out_path = "../data/labeled_dollar_bars_v4_5bar.csv"
    df_labeled.to_csv(out_path, index=False)
    print(f"\n✅ New Labels saved to: {out_path}")

if __name__ == "__main__":
    main()
