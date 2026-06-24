import pandas as pd
import numpy as np
import sys
import re

def parse_sltp(sltp_str):
    """
    Parses SLTP string like 'B:4712.92/4808.14|S:4807.74/4712.54'
    Returns lists of active SLs and TPs relative to current price direction.
    """
    if pd.isna(sltp_str) or sltp_str == 'NONE':
        return [], []

    sl_levels = []
    tp_levels = []

    # Split by pipe |
    positions = sltp_str.split('|')
    for pos in positions:
        # Expected format: B:SL/TP or S:SL/TP
        try:
            parts = pos.split(':')
            if len(parts) != 2: continue

            p_type = parts[0] # B or S
            levels = parts[1].split('/')

            if len(levels) != 2: continue

            sl = float(levels[0])
            tp = float(levels[1])

            if sl > 0: sl_levels.append(sl)
            if tp > 0: tp_levels.append(tp)

        except:
            continue

    return sl_levels, tp_levels

def analyze_sensitivity(file_path):
    print(f"Loading data from {file_path}...")
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"Error loading CSV: {e}")
        return

    # Basic cleanup
    df['Time'] = pd.to_datetime(df['Time'], errors='coerce')
    df['Bid'] = pd.to_numeric(df['Bid'], errors='coerce')
    df['Velocity'] = pd.to_numeric(df['Velocity'], errors='coerce').fillna(0).abs()

    # We focus on rows where active positions exist
    df = df[df['SLTP_Levels'] != 'NONE'].copy()
    print(f"Ticks with Active Positions: {len(df)}")

    # Metrics Lists
    min_dist_tp = []
    min_dist_sl = []
    tp_cluster_counts = []

    for idx, row in df.iterrows():
        sls, tps = parse_sltp(row['SLTP_Levels'])
        current_price = row['Bid']

        # Min Distance to TP
        if tps:
            # Distance is abs(Price - TP)
            dists = [abs(tp - current_price) for tp in tps]
            min_dist_tp.append(min(dists))
            tp_cluster_counts.append(len(tps))
        else:
            min_dist_tp.append(np.nan)
            tp_cluster_counts.append(0)

        # Min Distance to SL
        if sls:
            dists = [abs(sl - current_price) for sl in sls]
            min_dist_sl.append(min(dists))
        else:
            min_dist_sl.append(np.nan)

    df['Dist_TP'] = min_dist_tp
    df['Dist_SL'] = min_dist_sl
    df['TP_Count'] = tp_cluster_counts

    # --- ANALYSIS 1: SPREAD PROXIMITY & REACTION ---
    # User Hypothesis: "Reactions when spread distance is crossed"
    # We define "Spread Unit" distance.
    avg_spread = df['Spread'].mean()
    print(f"Average Spread: {avg_spread:.2f}")

    # Normalize distances by Spread
    df['Dist_TP_Ratio'] = df['Dist_TP'] / avg_spread
    df['Dist_SL_Ratio'] = df['Dist_SL'] / avg_spread

    # Group by Distance "Buckets" (e.g., < 0.5 spread, 0.5-1.0 spread, etc.)
    # We want to see AVG VELOCITY in each bucket.

    bins = [0, 0.5, 1.0, 1.5, 2.0, 5.0, 10.0, 100.0]
    labels = ['Danger (<0.5)', 'Close (0.5-1)', 'Near (1-1.5)', 'Safe (1.5-2)', 'Far (2-5)', 'Very Far (5-10)', 'Remote (>10)']

    df['TP_Zone'] = pd.cut(df['Dist_TP_Ratio'], bins=bins, labels=labels)
    df['SL_Zone'] = pd.cut(df['Dist_SL_Ratio'], bins=bins, labels=labels)

    print("\n--- TP PROXIMITY ANALYSIS (Thinking Zone?) ---")
    tp_stats = df.groupby('TP_Zone')['Velocity'].agg(['mean', 'count', 'std'])
    print(tp_stats)

    print("\n--- SL PROXIMITY ANALYSIS (Hunting Zone?) ---")
    sl_stats = df.groupby('SL_Zone')['Velocity'].agg(['mean', 'count', 'std'])
    print(sl_stats)

    # --- ANALYSIS 2: TP CLUSTER EFFECT ---
    # User Hypothesis: "Stops/Thinks if multiple TPs behind"
    # Compare Velocity when TP_Count > 1 vs TP_Count == 1 IN CLOSE RANGE (< 2.0 Spread)

    close_range_mask = df['Dist_TP_Ratio'] < 2.0
    cluster_df = df[close_range_mask]

    if not cluster_df.empty:
        print("\n--- TP CLUSTER EFFECT (Close Range < 2x Spread) ---")
        cluster_stats = cluster_df.groupby('TP_Count')['Velocity'].agg(['mean', 'count'])
        print(cluster_stats)
    else:
        print("\nNo events found in close range for Cluster Analysis.")

    # --- EXPORT FOR REPORT ---
    report_file = "FORENSIC_LAB/Distance_Sensitivity_Stats.csv"
    tp_stats.to_csv(report_file)
    print(f"\nStats exported to {report_file}")

if __name__ == "__main__":
    analyze_sensitivity("FORENSIC_LAB/data/Mimic_Research_GOLD_20260202_141322.csv")
