import pandas as pd
import numpy as np
import os

# Configuration
THRESHOLD_HUGE = 80_000_000 # ~800 Lots (slightly lowered to catch more L2 events if any)
PIVOT_WINDOW = 20 # Look +/- 20 ticks for local min/max

def detect_pivots(df):
    """
    Simple pivot detection: Local Min/Max of BestBid/BestAsk
    Returns a boolean mask for Pivot Highs and Pivot Lows.
    """
    df['is_pivot_high'] = False
    df['is_pivot_low'] = False

    # We use a rolling window to find local extrema
    # (Not efficient for massive data but fine for these logs)
    for i in range(PIVOT_WINDOW, len(df) - PIVOT_WINDOW):
        # High (Ask)
        current_ask = df.at[i, 'BestAsk']
        window_ask = df['BestAsk'].iloc[i-PIVOT_WINDOW:i+PIVOT_WINDOW+1]
        if current_ask == window_ask.max():
            df.at[i, 'is_pivot_high'] = True

        # Low (Bid)
        current_bid = df.at[i, 'BestBid']
        window_bid = df['BestBid'].iloc[i-PIVOT_WINDOW:i+PIVOT_WINDOW+1]
        if current_bid == window_bid.min():
            df.at[i, 'is_pivot_low'] = True
    return df

def analyze_segment(df, segment_name, threshold):
    results = {
        'L2': {'total': 0, 'spoof': 0, 'at_pivot': 0, 'spoof_at_pivot': 0},
        'L3': {'total': 0, 'spoof': 0, 'at_pivot': 0, 'spoof_at_pivot': 0}
    }

    # Helper to check if row `idx` is near a pivot (within window)
    def is_near_pivot(idx, side): # side: 'High' or 'Low'
        start = max(0, idx - PIVOT_WINDOW)
        end = min(len(df), idx + PIVOT_WINDOW)
        col = 'is_pivot_high' if side == 'High' else 'is_pivot_low'
        return df[col].iloc[start:end].any()

    # Iterate levels
    for level in [2, 3]:
        bid_col = f'BidV{level}'
        ask_col = f'AskV{level}'

        # --- BIDS (Support) ---
        # Large Bid at Level X suggests Support.
        # If it disappears, does price drop? (Exec vs Spoof)
        # Is it near a Pivot Low?

        in_event = False
        peak_vol = 0
        start_price = 0.0

        for i in range(len(df)):
            vol = df.at[i, bid_col]
            price = df.at[i, 'BestBid']

            if not in_event:
                if vol >= threshold:
                    in_event = True
                    start_price = price
            else:
                if vol < 10_000_000: # End event
                    in_event = False
                    end_price = price

                    # Analysis
                    is_spoof = (end_price >= start_price - 0.00005) # Did not drop > 5 points
                    near_pivot = is_near_pivot(i, 'Low') # Near a bottom?

                    key = f'L{level}'
                    results[key]['total'] += 1
                    if is_spoof: results[key]['spoof'] += 1
                    if near_pivot:
                        results[key]['at_pivot'] += 1
                        if is_spoof: results[key]['spoof_at_pivot'] += 1

        # --- ASKS (Resistance) ---
        in_event = False
        for i in range(len(df)):
            vol = df.at[i, ask_col]
            price = df.at[i, 'BestAsk']

            if not in_event:
                if vol >= threshold:
                    in_event = True
                    start_price = price
            else:
                if vol < 10_000_000:
                    in_event = False
                    end_price = price

                    is_spoof = (end_price <= start_price + 0.00005) # Did not rise > 5 points
                    near_pivot = is_near_pivot(i, 'High') # Near a top?

                    key = f'L{level}'
                    results[key]['total'] += 1
                    if is_spoof: results[key]['spoof'] += 1
                    if near_pivot:
                        results[key]['at_pivot'] += 1
                        if is_spoof: results[key]['spoof_at_pivot'] += 1

    return results

def print_results(res, name):
    print(f"\n--- {name} ---")
    for lvl in ['L2', 'L3']:
        r = res[lvl]
        total = r['total']
        if total == 0:
            print(f"  {lvl}: No Large Events (> {THRESHOLD_HUGE:,.0f})")
            continue

        spoof_rate = (r['spoof'] / total) * 100
        pivot_total = r['at_pivot']
        pivot_spoof = r['spoof_at_pivot']
        pivot_spoof_rate = (pivot_spoof / pivot_total * 100) if pivot_total > 0 else 0

        print(f"  {lvl}: {total} Events. Spoof Rate: {spoof_rate:.1f}%")
        print(f"      Near Turns: {pivot_total} events. Spoofed at Turn: {pivot_spoof}/{pivot_total} ({pivot_spoof_rate:.1f}%)")

def process_file(filepath):
    print(f"\n==========================================")
    print(f"ANALYZING: {os.path.basename(filepath)}")
    print(f"THRESHOLD: {THRESHOLD_HUGE:,.0f}")
    print(f"==========================================")

    df = pd.read_csv(filepath)
    df = detect_pivots(df)

    # Split into 3 segments
    n = len(df)
    chunk_size = n // 3

    seg1 = df.iloc[:chunk_size].reset_index(drop=True)
    seg2 = df.iloc[chunk_size:2*chunk_size].reset_index(drop=True)
    seg3 = df.iloc[2*chunk_size:].reset_index(drop=True)

    res1 = analyze_segment(seg1, "Sample 1 (Start)", THRESHOLD_HUGE)
    res2 = analyze_segment(seg2, "Sample 2 (Mid)", THRESHOLD_HUGE)
    res3 = analyze_segment(seg3, "Sample 3 (End)", THRESHOLD_HUGE)

    print_results(res1, "SAMPLE 1 (Early)")
    print_results(res2, "SAMPLE 2 (Mid)")
    print_results(res3, "SAMPLE 3 (Late)")

# Run
files = [
    'dom_data/Hybrid_DOM_Log_EURUSD_1768426894.csv',
    'dom_data/Hybrid_DOM_Log_GBPUSD_1768425691.csv'
]

for f in files:
    if os.path.exists(f):
        process_file(f)
