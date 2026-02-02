import pandas as pd
import numpy as np
import os

# Configuration
ARCHIVE_DIR = 'Colombo_Huron_Research_Archive'
CSV_FILE = 'Mimic_Research_Merged_Session.csv' # Adjust if specific gold file is needed, but this is the main one available
FULL_PATH = os.path.join(ARCHIVE_DIR, CSV_FILE)

def load_data(filepath):
    print(f"Loading data from {filepath}...")
    try:
        # Attempt to read with standard separator (comma for this dataset)
        df = pd.read_csv(filepath, sep=',')

        # Basic column cleaning
        df.columns = [c.strip() for c in df.columns]

        # Timestamp parsing (handling potential different formats)
        if 'Time_Current' in df.columns:
            df['Timestamp'] = pd.to_datetime(df['Time_Current'], errors='coerce')
        elif 'Time' in df.columns:
            df['Timestamp'] = pd.to_datetime(df['Time'], errors='coerce')

        return df
    except Exception as e:
        print(f"Error loading CSV: {e}")
        return None

def analyze_correlation(df):
    if df is None or df.empty:
        print("No data to analyze.")
        return

    print(f"Data shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")

    # Identify Price and Hybrid columns
    price_col = 'Bid' if 'Bid' in df.columns else 'Price_In'

    # Check if columns exist
    if price_col not in df.columns:
        print(f"Price column '{price_col}' not found.")
        return

    # Look for Hybrid column variations
    found_hybrid = None
    # Prioritize specific column names seen in logs
    if 'Mom_Hist' in df.columns:
        found_hybrid = 'Mom_Hist'
    else:
        for col in df.columns:
            if 'Hybrid' in col and 'Hist' in col:
                found_hybrid = col
                break

    if not found_hybrid:
        print("Hybrid Momentum Histogram column not found.")
        # Fallback search
        for col in df.columns:
             if 'Mom' in col:
                 print(f"Found potential momentum column: {col}")
        return

    print(f"Analyzing Correlation: {price_col} vs {found_hybrid}")

    # Calculate Price Change (Velocity)
    df['Price_Delta'] = df[price_col].diff()

    # Calculate Rolling Correlation
    window_size = 50
    df['Correlation'] = df['Price_Delta'].rolling(window=window_size).corr(df[found_hybrid])

    # Analyze Inverse Correlation (Toxic Flow / Counter-Trading)
    inverse_periods = df[df['Correlation'] < -0.5]

    print(f"\n--- Analysis Results ---")
    print(f"Total Ticks: {len(df)}")
    print(f"Periods of Strong Inverse Correlation (<-0.5): {len(inverse_periods)} ticks")

    if len(inverse_periods) > 0:
        print("Example Inverse Event:")
        print(inverse_periods[[price_col, found_hybrid, 'Correlation']].head(5))

    # Check specifically for the Flash Crash signature (High Volatility + Inverse)
    # Assuming crash implies large Price_Delta
    df['Volatility'] = df['Price_Delta'].abs()
    crash_events = df[df['Volatility'] > df['Volatility'].quantile(0.99)]

    print(f"\n--- Flash Crash Signatures (Top 1% Volatility) ---")
    if not crash_events.empty:
        print(crash_events[[price_col, found_hybrid, 'Price_Delta', 'Correlation']].head(10))
    else:
        print("No extreme volatility events found in this dataset.")

if __name__ == "__main__":
    if os.path.exists(FULL_PATH):
        df = load_data(FULL_PATH)
        analyze_correlation(df)
    else:
        # Fallback for testing if file was named differently in archive
        print(f"File not found at {FULL_PATH}. Listing Archive:")
        print(os.listdir(ARCHIVE_DIR))
