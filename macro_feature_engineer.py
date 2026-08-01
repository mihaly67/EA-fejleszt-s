import pandas as pd
import numpy as np
from sklearn.neighbors import KernelDensity
from scipy.signal import find_peaks

def calculate_kde_support_resistance(df, bandwidth=2.0, num_levels=5):
    prices = df['Close'].values.reshape(-1, 1)

    # Fit KDE
    kde = KernelDensity(kernel='gaussian', bandwidth=bandwidth).fit(prices)

    # Evaluate KDE over the price range
    price_range = np.linspace(prices.min(), prices.max(), 1000).reshape(-1, 1)
    log_dens = kde.score_samples(price_range)

    # Find peaks in the density (these are the S&R levels)
    peaks, _ = find_peaks(log_dens, distance=20)

    levels = price_range[peaks].flatten()

    # If we have more levels than requested, take the ones with highest density
    if len(levels) > num_levels:
        peak_densities = log_dens[peaks]
        top_indices = np.argsort(peak_densities)[-num_levels:]
        levels = levels[top_indices]

    levels.sort()
    return levels

def process_macro_features(df):
    """
    Calculates purely structural features for the Macro/Regime Ridge Classifier.
    """
    print("Engineer: Calculating Structural Features (V2)...")
    df = df.copy()

    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    # 1. ATR (Average True Range) - Used later for dynamic labeling and volatility
    high_low = df['High'] - df['Low']
    high_close = np.abs(df['High'] - df['Close'].shift())
    low_close = np.abs(df['Low'] - df['Close'].shift())
    ranges = pd.concat([high_low, high_close, low_close], axis=1)
    true_range = np.max(ranges, axis=1)
    df['ATR_14'] = true_range.rolling(14).mean()

    # Fractional Return Proxy
    df['Log_Return'] = np.log(df['Close'] / df['Close'].shift(1))

    # 2. ATR Normalized Volatility State (Replaces simple standard deviation)
    df['Vol_State'] = df['ATR_14'] / df['Close']

    # 3. Structural Swing Metrics (Distance to rolling min/max)
    df['Rolling_Max_50'] = df['High'].rolling(window=50).max()
    df['Rolling_Min_50'] = df['Low'].rolling(window=50).min()

    # Normalize swing distances by ATR to make them volatility-invariant
    df['Dist_to_Max_50_ATR'] = (df['Rolling_Max_50'] - df['Close']) / df['ATR_14']
    df['Dist_to_Min_50_ATR'] = (df['Close'] - df['Rolling_Min_50']) / df['ATR_14']

    # 4. KDE Support/Resistance Distances
    global_levels = calculate_kde_support_resistance(df)
    df['Dist_Nearest_Level'] = df['Close'].apply(lambda x: min(abs(x - lvl) for lvl in global_levels) if len(global_levels) > 0 else 0)
    # Normalize by ATR
    df['Dist_Nearest_Level_ATR'] = df['Dist_Nearest_Level'] / df['ATR_14']

    df.dropna(inplace=True)
    return df
