import pandas as pd
import numpy as np
import os

# Configuration
THRESHOLD_L1_L2 = 5_000_000 # 50 Lots (Much lower for inner book analysis)
PIVOT_WINDOW = 20

def detect_pivots(df):
    df['is_pivot_high'] = False
    df['is_pivot_low'] = False
    for i in range(PIVOT_WINDOW, len(df) - PIVOT_WINDOW):
        if df.at[i, 'BestAsk'] == df['BestAsk'].iloc[i-PIVOT_WINDOW:i+PIVOT_WINDOW+1].max():
            df.at[i, 'is_pivot_high'] = True
        if df.at[i, 'BestBid'] == df['BestBid'].iloc[i-PIVOT_WINDOW:i+PIVOT_WINDOW+1].min():
            df.at[i, 'is_pivot_low'] = True
    return df

def analyze_inner_levels(df, symbol):
    print(f"\n=== INNER BOOK ANALYSIS (L1/L2) @ PIVOTS: {symbol} ===")

    # Filter only pivot points
    pivot_highs = df[df['is_pivot_high']]
    pivot_lows = df[df['is_pivot_low']]

    print(f"Detected {len(pivot_highs)} Pivot Highs and {len(pivot_lows)} Pivot Lows.")

    # Analyze Volume Behavior at these points
    # We look at the 5 ticks BEFORE the pivot to see what L1/L2 did

    results = {'L1': {'add': 0, 'pull': 0, 'avg_vol': 0}, 'L2': {'add': 0, 'pull': 0, 'avg_vol': 0}}

    # Check Pivot Highs (Resistance -> Look at ASKS)
    for idx in pivot_highs.index:
        start = max(0, idx-5)
        for lvl in [1, 2]:
            col = f'AskV{lvl}'
            # Trend of volume approaching pivot
            vol_start = df[col].iloc[start]
            vol_peak = df[col].iloc[start:idx+1].max()
            vol_end = df[col].iloc[idx] # At the turn

            # Did liquidity INCREASE to stop price? (Resistance building)
            if vol_end > vol_start * 1.5:
                results[f'L{lvl}']['add'] += 1
            # Did liquidity VANISH? (Spoofing/Trap)
            elif vol_end < vol_start * 0.5:
                results[f'L{lvl}']['pull'] += 1

            results[f'L{lvl}']['avg_vol'] += vol_end

    # Check Pivot Lows (Support -> Look at BIDS)
    for idx in pivot_lows.index:
        start = max(0, idx-5)
        for lvl in [1, 2]:
            col = f'BidV{lvl}'
            vol_start = df[col].iloc[start]
            vol_end = df[col].iloc[idx]

            if vol_end > vol_start * 1.5:
                results[f'L{lvl}']['add'] += 1
            elif vol_end < vol_start * 0.5:
                results[f'L{lvl}']['pull'] += 1

            results[f'L{lvl}']['avg_vol'] += vol_end

    total_pivots = len(pivot_highs) + len(pivot_lows)
    if total_pivots > 0:
        for lvl in ['L1', 'L2']:
            avg = results[lvl]['avg_vol'] / total_pivots
            added = results[lvl]['add']
            pulled = results[lvl]['pull']
            print(f"--- Level {lvl} ---")
            print(f"  Avg Volume at Turn: {avg:,.0f}")
            print(f"  Liquidity ADDED (Wall Build): {added} times ({added/total_pivots*100:.1f}%)")
            print(f"  Liquidity PULLED (Trap):      {pulled} times ({pulled/total_pivots*100:.1f}%)")
            print(f"  Neutral/Steady:               {total_pivots - added - pulled} times")

# Run
files = [
    ('EURUSD', 'dom_data/Hybrid_DOM_Log_EURUSD_1768426894.csv'),
    ('GBPUSD', 'dom_data/Hybrid_DOM_Log_GBPUSD_1768425691.csv')
]

for name, path in files:
    if os.path.exists(path):
        df = pd.read_csv(path)
        df = detect_pivots(df)
        analyze_inner_levels(df, name)
