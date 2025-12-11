import time
import os
import pandas as pd
import numpy as np
from scipy.signal import savgol_filter, butter, filtfilt

# --- CONFIG ---
INPUT_FILE = "Common/Files/colombo_macd_data.csv" # Adjust path based on MT5 setup
OUTPUT_FILE = "Common/Files/colombo_processed.csv"
WATCH_INTERVAL = 0.5 # Seconds

def apply_zero_phase_filter(data, window=11, polyorder=2):
    """
    Applies a Savitzky-Golay filter which preserves peaks better than simple MA.
    Note: 'savgol_filter' is theoretically zero-phase if symmetric window is used.
    """
    try:
        if len(data) < window:
            return data

        # Savitzky-Golay Smoothing
        smoothed = savgol_filter(data, window_length=window, polyorder=polyorder)
        return smoothed
    except Exception as e:
        print(f"Error in filtering: {e}")
        return data

def extrapolate_and_filter(data, forecast_horizon=5):
    """
    Colombo Trick:
    1. Fit a polynomial to the end of data.
    2. Forecast X bars into future.
    3. Filter the extended series.
    4. Cut off the future part.
    This reduces the 'edge effect' lag of filters.
    """
    # Simple Linear Extrapolation for robustness
    # (Or use last slope)
    last_val = data.iloc[-1]
    slope = data.iloc[-1] - data.iloc[-2] if len(data) > 1 else 0

    future = [last_val + slope * (i+1) for i in range(forecast_horizon)]
    extended = np.concatenate([data.values, future])

    # Filter extended
    smoothed_extended = apply_zero_phase_filter(extended, window=15, polyorder=2)

    # Return valid part
    return smoothed_extended[:-forecast_horizon]

def main():
    print("🕵️‍♂️ Colombo DSP Agent Started...")
    print(f"Watching: {INPUT_FILE}")

    last_mtime = 0

    while True:
        try:
            if os.path.exists(INPUT_FILE):
                mtime = os.path.getmtime(INPUT_FILE)
                if mtime > last_mtime:
                    last_mtime = mtime

                    # Read Data
                    df = pd.read_csv(INPUT_FILE)
                    if not df.empty and 'MACD' in df.columns:
                        # Process MACD
                        df['MACD_Smooth'] = extrapolate_and_filter(df['MACD'])

                        # Process Signal
                        df['Signal_Smooth'] = extrapolate_and_filter(df['Signal'])

                        # Calculate Histogram (Processed)
                        df['Histogram'] = df['MACD_Smooth'] - df['Signal_Smooth']

                        # Write Output
                        df.to_csv(OUTPUT_FILE, index=False)
                        print(f"[{time.strftime('%H:%M:%S')}] Processed {len(df)} bars.")

            time.sleep(WATCH_INTERVAL)

        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
