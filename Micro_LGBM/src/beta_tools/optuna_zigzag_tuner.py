import pandas as pd
import numpy as np
import optuna
from full_zigzag import FullZigZagEngine
import warnings
warnings.filterwarnings('ignore')

# 1. Load Data
# We use the raw MT5 data file from earlier today to get M1 candles
df_raw = pd.read_csv('/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/Merkava_MGCV26_v1.10_20260812_033158.csv', on_bad_lines='skip')
df_raw['Datetime'] = pd.to_datetime(df_raw['Time'], format='mixed', errors='coerce')
df_raw = df_raw.dropna(subset=['Datetime']).sort_values('Datetime')
df_raw['Mid'] = (df_raw['Bid'] + df_raw['Ask']) / 2.0

df_raw.set_index('Datetime', inplace=True)
df_m1 = df_raw['Mid'].resample('1min').ohlc()
df_m1.dropna(inplace=True)
highs = df_m1['high'].values
lows = df_m1['low'].values
closes = df_m1['close'].values

print(f"Loaded {len(highs)} M1 Candlesticks for Optimization.")

def objective(trial):
    # We want to tune the Secondary Pivot distance.
    # The Micro pivot is usually very fast (e.g., Depth=12, Deviation=5)
    # We are searching for parameters for the SECONDARY pivot that make it "brave but reachable"

    sec_depth = trial.suggest_int('sec_depth', 20, 100)
    sec_dev = trial.suggest_int('sec_dev', 10, 50)

    engine = FullZigZagEngine(depth=sec_depth, deviation=sec_dev)
    rolling_r, rolling_s = engine.calculate(highs, lows, point_size=0.1) # GC has 0.1 point size natively in MT5

    # Calculate Distances
    dist_r = rolling_r - closes
    dist_s = closes - rolling_s

    # Remove zeros and negatives (where price breaks the pivot before it recalculates)
    valid_r = dist_r[dist_r > 0]
    valid_s = dist_s[dist_s > 0]

    if len(valid_r) == 0 or len(valid_s) == 0:
        return -9999.0

    avg_dist_r = np.mean(valid_r)
    avg_dist_s = np.mean(valid_s)
    avg_dist = (avg_dist_r + avg_dist_s) / 2.0

    # We want the secondary pivot to be comfortably above the 1.5 Pt TP, but not so far it's ignored.
    # Target distance for secondary pivot: ~2.5 to 4.0 points.
    # We penalize distances that are too close (acts like Micro) or too far (acts like Tertiary/Daily)
    target_distance = 3.5

    penalty = abs(avg_dist - target_distance)

    # We also want stability (fewer changes means it's a solid structural level)
    # But Optuna minimizes penalty, so we return negative penalty (or minimize positive penalty)

    return penalty

print("\n🚀 Starting Optuna Study for Secondary ZigZag Pivot...")
study = optuna.create_study(direction='minimize')
study.optimize(objective, n_trials=50)

print("\n✅ Optimization Complete.")
print("Best Parameters for Secondary Pivot (Target ~3.5 pts distance):")
print(study.best_params)
print(f"Average Distance achieved: {study.best_value + 3.5:.2f} pts")
