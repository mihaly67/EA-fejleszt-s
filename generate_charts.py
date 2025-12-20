import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os
import glob
from matplotlib.gridspec import GridSpec

# --- Configuration ---
# Adjust these paths as needed for your VPS environment
INPUT_DIR = "Showcase_Indicators/"
OUTPUT_DIR = "py_chart_csart/"
FILE_PATTERN = "*_M1_1Day.csv"
CRYPTO_EXCLUSION = ["BTC", "ETH", "SOL", "LTC"] # Exclude high-volatility crypto if needed

# --- Mathematical Helpers ---

def calculate_ema(series, period):
    """Standard Exponential Moving Average"""
    return series.ewm(span=period, adjust=False).mean()

def calculate_dema(series, period):
    """Double Exponential Moving Average (DEMA)"""
    ema1 = calculate_ema(series, period)
    ema2 = calculate_ema(ema1, period)
    return 2 * ema1 - ema2

def calculate_zlema(series, period):
    """
    Zero-Lag Exponential Moving Average (ZLEMA)
    Formula: EMA(2*Price - Price[Lag], Period)
    """
    lag = int((period - 1) / 2)
    series_lagged = series.shift(lag)
    # Fill NaN caused by shift with original values to avoid data loss at start
    series_lagged = series_lagged.fillna(series)
    data = 2 * series - series_lagged
    return calculate_ema(data, period)

def calculate_vwma(series, volume, period):
    """Volume Weighted Moving Average"""
    pv = series * volume
    return pv.rolling(window=period).sum() / volume.rolling(window=period).sum()

def tanh_normalize(series, std_dev, sensitivity=1.0):
    """Hyperbolic Tangent Normalization"""
    # Avoid division by zero
    std_dev = std_dev.replace(0, 1.0)
    return 100.0 * np.tanh(series / (std_dev * sensitivity))

# --- INDICATOR LOGIC SECTION ---
# Add new indicator functions here.
# Each function should accept the DataFrame and return the plot-able series.

def legacy_logic(df, fast=12, slow=26, signal=9, phase=0.5, norm_period=100):
    """
    [LEGACY] HybridMomentumIndicator v1.7/v1.9 Logic
    Components: DEMA MACD + Phase Advance + Tanh Normalization
    Status: Noisy
    """
    close = df['Close']

    # 1. DEMA Components
    dema_fast = calculate_dema(close, fast)
    dema_slow = calculate_dema(close, slow)
    raw_macd = dema_fast - dema_slow

    # 2. DEMA Signal of MACD
    raw_signal = calculate_dema(raw_macd, signal)

    # 3. Phase Advance & Normalization
    rolling_std = raw_macd.rolling(window=norm_period).std()

    # Velocity (Derivative)
    velocity_macd = raw_macd.diff()
    velocity_signal = raw_signal.diff()

    # Boosted Signal (Phase Advance)
    boosted_macd = raw_macd + (velocity_macd * phase)
    boosted_signal = raw_signal + (velocity_signal * phase)

    # Normalized
    norm_macd = tanh_normalize(boosted_macd, rolling_std, 1.0)
    norm_signal = tanh_normalize(boosted_signal, rolling_std, 1.0)

    hist = norm_macd - norm_signal

    return norm_macd, norm_signal, hist

def candidate_zlema_logic(df, fast=12, slow=26, signal=9):
    """
    [CANDIDATE 1] ZeroLag EMA (ZLEMA) MACD
    Goal: Reduce lag without adding noise.
    """
    close = df['Close']

    zlema_fast = calculate_zlema(close, fast)
    zlema_slow = calculate_zlema(close, slow)

    raw_macd = zlema_fast - zlema_slow

    # Signal line also ZLEMA
    raw_signal = calculate_zlema(raw_macd, signal)

    # Normalization (No Phase Advance needed if ZLEMA works)
    rolling_std = raw_macd.rolling(window=100).std()

    norm_macd = tanh_normalize(raw_macd, rolling_std, 1.0)
    norm_signal = tanh_normalize(raw_signal, rolling_std, 1.0)

    hist = norm_macd - norm_signal

    return norm_macd, norm_signal, hist

def candidate_vwma_logic(df, fast=12, slow=26, signal=9):
    """
    [CANDIDATE 2] Volume Weighted MACD
    Goal: Filter low-volume noise.
    """
    close = df['Close']
    vol = df['Volume']

    vwma_fast = calculate_vwma(close, vol, fast)
    vwma_slow = calculate_vwma(close, vol, slow)

    raw_macd = vwma_fast - vwma_slow
    raw_signal = calculate_vwma(raw_macd, vol, signal)

    rolling_std = raw_macd.rolling(window=100).std()

    norm_macd = tanh_normalize(raw_macd, rolling_std, 1.0)
    norm_signal = tanh_normalize(raw_signal, rolling_std, 1.0)

    hist = norm_macd - norm_signal
    return norm_macd, norm_signal, hist


# --- Plotting Engine ---

def generate_chart(filepath, filename):
    print(f"Processing {filename}...")
    try:
        df = pd.read_csv(filepath)
        df['Time'] = pd.to_datetime(df['Time'])
        df.set_index('Time', inplace=True)
    except Exception as e:
        print(f"Error reading {filename}: {e}")
        return

    # Calculate Indicators
    l_macd, l_sig, l_hist = legacy_logic(df)
    c1_macd, c1_sig, c1_hist = candidate_zlema_logic(df)
    c2_macd, c2_sig, c2_hist = candidate_vwma_logic(df)

    # Setup Plot (Headless safe)
    fig = plt.figure(figsize=(20, 15))
    gs = GridSpec(4, 1, height_ratios=[3, 1, 1, 1])

    # 1. Price Panel
    ax0 = fig.add_subplot(gs[0])
    ax0.plot(df.index, df['Close'], label='Close Price', color='black', linewidth=0.8)
    ax0.set_title(f"{filename} - Price Analysis", fontweight='bold')
    ax0.grid(True, alpha=0.3)
    ax0.legend(loc='upper left')

    # 2. Legacy Panel
    ax1 = fig.add_subplot(gs[1], sharex=ax0)
    ax1.plot(df.index, l_macd, label='MACD (Legacy: DEMA+Phase)', color='blue', linewidth=1)
    ax1.plot(df.index, l_sig, label='Signal', color='red', linestyle='--', linewidth=1)
    ax1.fill_between(df.index, l_hist, 0, color='gray', alpha=0.3, label='Hist')
    ax1.set_title("Legacy: DEMA(12,26,9) + Phase(0.5) + Tanh", fontsize=10)
    ax1.set_ylim(-110, 110)
    ax1.axhline(0, color='black', linewidth=0.5)
    ax1.legend(loc='upper left')
    ax1.grid(True, alpha=0.3)

    # 3. Candidate 1 Panel (ZLEMA)
    ax2 = fig.add_subplot(gs[2], sharex=ax0)
    ax2.plot(df.index, c1_macd, label='MACD (ZLEMA)', color='green', linewidth=1)
    ax2.plot(df.index, c1_sig, label='Signal', color='orange', linestyle='--', linewidth=1)
    ax2.fill_between(df.index, c1_hist, 0, color='green', alpha=0.1, label='Hist')
    ax2.set_title("Candidate 1: ZeroLag EMA (ZLEMA) MACD + Tanh", fontsize=10)
    ax2.set_ylim(-110, 110)
    ax2.axhline(0, color='black', linewidth=0.5)
    ax2.legend(loc='upper left')
    ax2.grid(True, alpha=0.3)

    # 4. Candidate 2 Panel (VWMA)
    ax3 = fig.add_subplot(gs[3], sharex=ax0)
    ax3.plot(df.index, c2_macd, label='MACD (VWMA)', color='purple', linewidth=1)
    ax3.plot(df.index, c2_sig, label='Signal', color='pink', linestyle='--', linewidth=1)
    ax3.fill_between(df.index, c2_hist, 0, color='purple', alpha=0.1, label='Hist')
    ax3.set_title("Candidate 2: Volume Weighted MACD + Tanh", fontsize=10)
    ax3.set_ylim(-110, 110)
    ax3.axhline(0, color='black', linewidth=0.5)
    ax3.legend(loc='upper left')
    ax3.grid(True, alpha=0.3)

    plt.tight_layout()

    # Ensure Output Dir Exists
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    out_path = os.path.join(OUTPUT_DIR, f"{filename.replace('.csv', '')}_Chart.png")
    plt.savefig(out_path)
    print(f"Saved {out_path}")
    plt.close()

# --- Main Execution ---

def main():
    print("Starting Chart Generation...")
    files = glob.glob(os.path.join(INPUT_DIR, FILE_PATTERN))

    if not files:
        print(f"No CSV files found in {INPUT_DIR} matching {FILE_PATTERN}")
        return

    print(f"Found {len(files)} files.")

    for filepath in files:
        filename = os.path.basename(filepath)

        # Check exclusion
        exclude = False
        for ex in CRYPTO_EXCLUSION:
            if ex in filename:
                exclude = True
                break

        if exclude:
            print(f"Skipping {filename} (Crypto)")
            continue

        generate_chart(filepath, filename)

    print("All done.")

if __name__ == "__main__":
    main()
