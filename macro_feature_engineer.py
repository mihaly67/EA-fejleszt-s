import pandas as pd
import numpy as np
from sklearn.neighbors import KernelDensity
from scipy.signal import find_peaks

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
    Cleans up the pre-calculated multi-timeframe features from the MT5 V2 Miner
    and converts them into ATR-normalized geometric states for the Ridge Classifier.
    """
    print("Engineer: Converting MQL5 MTF Indicators to Geometric Features...")
    df = df.copy()

    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    # Calculate Global Pivot Levels (using KDE for structural geometry)
    global_levels = calculate_kde_support_resistance(df)

    def get_nearest_pivot(price):
        if len(global_levels) == 0: return price
        return min(global_levels, key=lambda x: abs(x - price))

    df['Nearest_Pivot'] = df['Close'].apply(get_nearest_pivot)

    # 1. MICRO-TREND (Burst & Entry - M1)
    # The MQL5 script gives us 'ATR_M1' and 'ROC_M1' directly.
    df['X_micro_pivot_dist'] = (df['Close'] - df['Nearest_Pivot']) / (df['ATR_M1'] + 1e-8)
    # Keep ROC as a raw velocity input
    df['Micro_ROC'] = df['ROC_M1']

    # 2. INTERMEDIATE TREND (Stairs & Retests - M5)
    # MQL5 provides: EMA13_M5, EMA34_M5, ADX_M5, DI_Plus_M5, DI_Minus_M5
    df['Int_EMA_Slope'] = (df['EMA13_M5'] - df['EMA13_M5'].shift(1)) / (df['ATR_M1'] + 1e-8)
    df['Int_DI_Diff'] = df['DI_Plus_M5'] - df['DI_Minus_M5']
    df['Int_ADX'] = df['ADX_M5']

    # Retest State: Is the intermediate EMA resting on the pivot?
    df['X_retest_state'] = (df['EMA13_M5'] - df['Nearest_Pivot']) / (df['ATR_M1'] + 1e-8)

    # 3. MACRO TREND (Global Map & Safety Filter - M15)
    # MQL5 provides: Donchian_High_M15, Donchian_Low_M15
    range_size = df['Donchian_High_M15'] - df['Donchian_Low_M15']
    # 0 = at the bottom of macro range, 1 = at the top
    df['X_macro_range_pos'] = np.where(range_size > 0,
                                       (df['Close'] - df['Donchian_Low_M15']) / range_size,
                                       0.5)

    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.dropna(inplace=True)

    # To keep compatibility with labeler which uses 'ATR_14', we rename ATR_M1
    df['ATR_14'] = df['ATR_M1']

    return df
