import pandas as pd
import numpy as np
from sklearn.neighbors import KernelDensity
from scipy.signal import find_peaks
import ta
from kaufman_ama import calculate_kama

def calculate_kde_support_resistance(df, bandwidth=2.0, num_levels=5):
    prices = df['Close'].values.reshape(-1, 1)
    kde = KernelDensity(kernel='gaussian', bandwidth=bandwidth).fit(prices)
    price_range = np.linspace(prices.min(), prices.max(), 1000).reshape(-1, 1)
    log_dens = kde.score_samples(price_range)
    peaks, _ = find_peaks(log_dens, distance=20)
    levels = price_range[peaks].flatten()
    if len(levels) > num_levels:
        peak_densities = log_dens[peaks]
        top_indices = np.argsort(peak_densities)[-num_levels:]
        levels = levels[top_indices]
    levels.sort()
    return levels

def process_macro_features(df):
    """
    Computes multiple variations of the AMA across simulated timeframes
    directly from raw M1 data to let the Ridge Classifier find the optimal parameters.
    """
    print("Engineer: Generating Multi-Param AMA Geometric Coordinates...")
    df = df.copy()

    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    df['ATR_5'] = ta.volatility.AverageTrueRange(high=df['High'], low=df['Low'], close=df['Close'], window=5).average_true_range()

    # ---------------------------------------------------------
    # Generate AMA Variants (Period, Fast, Slow)
    # ---------------------------------------------------------
    # M1 Timeframe Variants (Micro)
    df['AMA_M1_20_2_30'] = calculate_kama(df['Close'], period=20, fast_ema=2, slow_ema=30)
    df['AMA_M1_10_2_20'] = calculate_kama(df['Close'], period=10, fast_ema=2, slow_ema=20)

    # Simulated M5 Timeframe Variants (Intermediate)
    # Period * 5
    df['AMA_M5_20_2_30'] = calculate_kama(df['Close'], period=100, fast_ema=10, slow_ema=150)
    df['AMA_M5_30_5_50'] = calculate_kama(df['Close'], period=150, fast_ema=25, slow_ema=250)

    # Simulated M15 Timeframe Variants (Macro)
    # Period * 15
    df['AMA_M15_20_2_30'] = calculate_kama(df['Close'], period=300, fast_ema=30, slow_ema=450)

    # ---------------------------------------------------------
    # Convert ALL AMAs to ATR-Normalized Geometric Distances
    # ---------------------------------------------------------
    df['X_micro_ama1_dist'] = (df['Close'] - df['AMA_M1_20_2_30']) / (df['ATR_5'] + 1e-8)
    df['X_micro_ama2_dist'] = (df['Close'] - df['AMA_M1_10_2_20']) / (df['ATR_5'] + 1e-8)

    df['X_int_ama1_dist'] = (df['Close'] - df['AMA_M5_20_2_30']) / (df['ATR_5'] + 1e-8)
    df['X_int_ama2_dist'] = (df['Close'] - df['AMA_M5_30_5_50']) / (df['ATR_5'] + 1e-8)

    df['X_macro_ama1_dist'] = (df['Close'] - df['AMA_M15_20_2_30']) / (df['ATR_5'] + 1e-8)

    # ---------------------------------------------------------
    # AMA Slopes (Velocities)
    # ---------------------------------------------------------
    df['Slope_AMA_M1'] = (df['AMA_M1_20_2_30'] - df['AMA_M1_20_2_30'].shift(5)) / (df['ATR_5'] + 1e-8)
    df['Slope_AMA_M5'] = (df['AMA_M5_20_2_30'] - df['AMA_M5_20_2_30'].shift(25)) / (df['ATR_5'] + 1e-8)
    df['Slope_AMA_M15'] = (df['AMA_M15_20_2_30'] - df['AMA_M15_20_2_30'].shift(75)) / (df['ATR_5'] + 1e-8)

    # ---------------------------------------------------------
    # Structural KDE Pivots
    # ---------------------------------------------------------
    global_levels = calculate_kde_support_resistance(df)
    def get_nearest_pivot(price):
        if len(global_levels) == 0: return price
        return min(global_levels, key=lambda x: abs(x - price))

    df['Nearest_Pivot'] = df['Close'].apply(get_nearest_pivot)
    df['X_pivot_dist'] = (df['Close'] - df['Nearest_Pivot']) / (df['ATR_5'] + 1e-8)

    # Labeler needs ATR_14
    df['ATR_14'] = ta.volatility.AverageTrueRange(high=df['High'], low=df['Low'], close=df['Close'], window=14).average_true_range()

    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.dropna(inplace=True)

    return df
