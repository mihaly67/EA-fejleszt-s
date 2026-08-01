import pandas as pd
import numpy as np
from sklearn.neighbors import KernelDensity
from scipy.signal import find_peaks

def calculate_kde_support_resistance(df, bandwidth=2.0, num_levels=5):
    """
    Calculates statistical Support/Resistance levels using Kernel Density Estimation
    on the Close prices over the rolling window.
    """
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
    print("Engineer: Calculating Structural Features...")
    df = df.copy()

    # Ensure Time is datetime
    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    # 1. Fractional Differentiation Proxy (Returns or log returns as a simple stationary proxy for now)
    df['Log_Return'] = np.log(df['Close'] / df['Close'].shift(1))

    # 2. Rolling Volatility
    df['Rolling_Vol_20'] = df['Log_Return'].rolling(window=20).std()

    # 3. Structural Swing Metrics (Distance to rolling min/max)
    df['Rolling_Max_50'] = df['High'].rolling(window=50).max()
    df['Rolling_Min_50'] = df['Low'].rolling(window=50).min()

    df['Dist_to_Max_50'] = (df['Rolling_Max_50'] - df['Close']) / df['Close']
    df['Dist_to_Min_50'] = (df['Close'] - df['Rolling_Min_50']) / df['Close']

    # 4. KDE Support/Resistance Distances (Global approximation for baseline)
    global_levels = calculate_kde_support_resistance(df)

    df['Dist_Nearest_Level'] = df['Close'].apply(lambda x: min(abs(x - lvl) for lvl in global_levels) if len(global_levels) > 0 else 0)

    df.dropna(inplace=True)
    return df
