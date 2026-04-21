import pandas as pd
import numpy as np

def analyze_spoofing(filepath):
    print(f"--- Spoofing Analysis: {filepath} ---")
    try:
        df = pd.read_csv(filepath)
    except Exception as e:
        print(f"Error: {e}")
        return

    # Check necessary columns
    needed = ['TimeMS', 'BestBid', 'BestAsk', 'BidV3', 'AskV3'] # Focus on Level 3 as requested
    if not all(col in df.columns for col in needed):
        print("Missing columns for analysis.")
        return

    # Threshold for "Large Volume" (e.g. > 500,000 or user specified "1000 lot" -> 100,000 units?)
    # In MT5 logs, volume is usually raw units. 1 lot = 100,000 units usually.
    # The log shows values like 20,000,000 (200 lots?). Let's check the mean.
    mean_v3 = df['BidV3'].mean()
    threshold = mean_v3 * 1.5 # 50% above average

    print(f"Level 3 Mean Volume: {mean_v3:,.0f}")
    print(f"Threshold for 'Wall': {threshold:,.0f}")

    # Logic:
    # 1. Find rows where Vol > Threshold
    # 2. Look ahead 1-2 seconds (approx 2-4 rows depending on tick speed)
    # 3. If Vol drops significantly (> 50% drop) AND Price did NOT cross the level -> SPOOFING
    # 4. If Vol drops AND Price crossed -> EXECUTION

    spoof_events = 0
    exec_events = 0

    # Iterate (slow but clear)
    for i in range(len(df) - 5):
        row = df.iloc[i]

        # Check BID side
        if row['BidV3'] > threshold:
            # Look ahead
            next_row = df.iloc[i+2] # Check 2 ticks later (approx reaction time)

            # Did volume drop?
            if next_row['BidV3'] < (row['BidV3'] * 0.5):
                # Did price hit the bid?
                # L3 price is below BestBid. We don't have L3 Price in log, only L1.
                # Assumption: Spread is stable.

                # Check if BestBid moved DOWN (towards the wall? No, Bid wall is below price)
                # If BestBid moved DOWN, it might have hit the wall.

                price_drop = next_row['BestBid'] < row['BestBid']

                if price_drop:
                    exec_events += 1
                    # print(f"Executed at {row['TimeMS']}")
                else:
                    spoof_events += 1
                    # print(f"Spoofed at {row['TimeMS']} (Vol: {row['BidV3']} -> {next_row['BidV3']})")

    print(f"\nResults for BID Side Level 3:")
    print(f"Total High Volume Events: {len(df[df['BidV3'] > threshold])}")
    print(f"Potential Executions (Price moved to wall): {exec_events}")
    print(f"Potential Spoofing (Wall vanished, price stayed): {spoof_events}")

    if spoof_events + exec_events > 0:
        ratio = spoof_events / (spoof_events + exec_events)
        print(f"Spoofing Ratio: {ratio:.2%}")

if __name__ == "__main__":
    analyze_spoofing("dom_data/Hybrid_DOM_Log_EURUSD_1768426894.csv")
