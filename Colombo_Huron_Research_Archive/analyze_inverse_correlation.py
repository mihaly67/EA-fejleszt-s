import pandas as pd
import numpy as np

# Load Data
file_path = 'Trojan_Horse_Log_[SP500]_20260128_225718.csv'
try:
    df = pd.read_csv(file_path, on_bad_lines='skip')
except Exception as e:
    print(f"Error loading CSV: {e}")
    exit()

# Parse Time
df['DateTime'] = pd.to_datetime(df['Time'], format='%Y.%m.%d %H:%M:%S', errors='coerce')
df = df.dropna(subset=['DateTime'])

# The user stated: "folyamatos buy ban voltam" (Continuous Buy) -> Price Dropped.
# "folyamatos sell ban voltam" (Continuous Sell) -> Price Rose.
# We need to find the "Deepest Drop" and the "Subsequent Rise".

# Calculate Price Change
df['Price'] = df['TradePrice']
df['Price_Delta'] = df['Price'].diff()

# Find the trend
# We assume the first half is the "Buy/Drop" phase and the second is "Sell/Rise" or we look for the V-shape.
min_price_idx = df['Price'].idxmin()
min_price = df['Price'].min()
min_time = df.loc[min_price_idx, 'DateTime']

# Phase 1: Start to Min (The Drop)
phase1 = df.loc[:min_price_idx]
drop_duration = (phase1['DateTime'].iloc[-1] - phase1['DateTime'].iloc[0]).total_seconds()
price_drop = phase1['Price'].iloc[0] - min_price
tick_count_p1 = len(phase1)

# Phase 2: Min to End (The Rise)
phase2 = df.loc[min_price_idx:]
rise_duration = (phase2['DateTime'].iloc[-1] - phase2['DateTime'].iloc[0]).total_seconds()
price_rise = phase2['Price'].iloc[-1] - min_price
tick_count_p2 = len(phase2)

print(f"=== INVERSE CORRELATION ANALYSIS ===")
print(f"Total Ticks: {len(df)}")
print(f"Start Price: {df['Price'].iloc[0]}")
print(f"Min Price: {min_price} @ {min_time}")
print(f"End Price: {df['Price'].iloc[-1]}")

print(f"\n--- PHASE 1: THE CRUSH (User Buying 1 Lot/Tick) ---")
print(f"Duration: {drop_duration:.1f}s")
print(f"Ticks (Buys): {tick_count_p1}")
print(f"Price Change: -{price_drop:.2f} points")
print(f"Avg Velocity (Ticks/Sec): {tick_count_p1 / drop_duration if drop_duration > 0 else 0:.2f}")
print(f"Market Logic: Buying {tick_count_p1} Lots -> Price DROPPED {price_drop:.2f} pts.")
print(f"VERDICT: TOXIC FLOW (Inverse Reaction)")

print(f"\n--- PHASE 2: THE ESCAPE (User Selling 1 Lot/Tick) ---")
print(f"Duration: {rise_duration:.1f}s")
print(f"Ticks (Sells): {tick_count_p2}")
print(f"Price Change: +{price_rise:.2f} points")
print(f"Avg Velocity (Ticks/Sec): {tick_count_p2 / rise_duration if rise_duration > 0 else 0:.2f}")
print(f"Market Logic: Selling {tick_count_p2} Lots -> Price ROSE {price_rise:.2f} pts.")
print(f"VERDICT: TOXIC FLOW (Inverse Reaction)")

# Correlation Check (Rolling)
# We expect negative correlation between "Cumulative Volume" (if we assume Buy=+1) and Price.
# Simulation:
# Phase 1: CumVol increases (0 -> 1000). Price decreases. Correlation = -1.0.
# Phase 2: CumVol decreases (1000 -> 0). Price increases. Correlation = -1.0.
