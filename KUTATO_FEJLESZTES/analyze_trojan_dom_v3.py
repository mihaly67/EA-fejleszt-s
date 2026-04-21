import pandas as pd
import matplotlib.pyplot as plt
import glob
import os
import sys
from datetime import datetime

# --- Configuration ---
LOG_DIR = "test_logs/eurusd_test"
OUTPUT_DIR = "analysis_output_eurusd"

def find_logs(directory):
    """Finds all Trojan_Horse logs and the single DOM log."""
    if not os.path.exists(directory):
        print(f"Directory {directory} not found.")
        return [], None

    ea_files = sorted(glob.glob(os.path.join(directory, "Trojan_Horse_Log_*.csv")))
    dom_files = glob.glob(os.path.join(directory, "Hybrid_DOM_Log_*.csv"))

    if not ea_files:
        print("No Trojan Horse logs found!")
        return [], None
    if not dom_files:
        print("No DOM logs found!")
        return [], None

    # Assuming one DOM log covers the session (or taking the latest)
    dom_latest = max(dom_files, key=os.path.getmtime)

    print(f"Found {len(ea_files)} EA Log(s):")
    for f in ea_files: print(f" - {os.path.basename(f)}")
    print(f"Using DOM Log: {os.path.basename(dom_latest)}")

    return ea_files, dom_latest

def load_data(ea_files, dom_path):
    """Loads multiple EA logs into one DataFrame and loads DOM data."""
    try:
        # Load DOM Data
        df_dom = pd.read_csv(dom_path)
        df_dom['Datetime'] = pd.to_datetime(df_dom['Time'] + '.' + df_dom['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')

        # Load and Concatenate EA Data
        ea_dfs = []
        for f in ea_files:
            df = pd.read_csv(f)
            # Add a 'Phase' column based on filename timestamp or index
            phase_name = os.path.basename(f).split('_')[-1].replace('.csv', '') # e.g. 20260116_223335
            df['Phase'] = phase_name
            ea_dfs.append(df)

        df_ea = pd.concat(ea_dfs, ignore_index=True)
        df_ea['Datetime'] = pd.to_datetime(df_ea['Time'] + '.' + df_ea['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')

        return df_ea, df_dom
    except Exception as e:
        print(f"Error loading data: {e}")
        return None, None

def plot_velocity_trades_multi(df_ea, df_dom, output_path):
    """Plots Velocity with Trades colored by Phase."""
    plt.figure(figsize=(16, 8))

    # Plot Velocity
    plt.plot(df_dom['Datetime'], df_dom['Velocity'], label='Market Velocity', color='grey', alpha=0.4, linewidth=1)

    # Color map for phases
    phases = df_ea['Phase'].unique()
    colors = plt.cm.viridis(range(len(phases))) # Use a colormap

    for i, phase in enumerate(phases):
        subset = df_ea[df_ea['Phase'] == phase]
        opens = subset[subset['Action'] == 'OPEN']
        closes = subset[subset['Action'] == 'CLOSE_PROFIT']

        # Use different shades for Open/Close within the phase color, or just markers
        # Let's use Green/Red but lighter/darker? No, simpler: Phase = Color is confusing.
        # Better: Trades are Green/Red, but we add vertical lines or background shading for Phases.

        plt.scatter(opens['Datetime'], opens['Velocity'], color='green', marker='^', s=30, label=f'Open ({phase})' if i==0 else "")
        plt.scatter(closes['Datetime'], closes['Velocity'], color='red', marker='v', s=30, label=f'Close ({phase})' if i==0 else "")

    plt.title('Market Velocity & Trades (Multi-Phase)')
    plt.xlabel('Time')
    plt.ylabel('Velocity')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(output_path, "velocity_trades_multi.png"))
    print("Saved velocity_trades_multi.png")

def plot_liquidity_heatmap(df_dom, output_path):
    """Plots Total Bid/Ask Liquidity."""
    plt.figure(figsize=(14, 7))

    bid_cols = [f'BidV{i}' for i in range(1, 6)]
    ask_cols = [f'AskV{i}' for i in range(1, 6)]

    if not all(col in df_dom.columns for col in bid_cols):
        return

    df_dom['TotalBid'] = df_dom[bid_cols].sum(axis=1)
    df_dom['TotalAsk'] = df_dom[ask_cols].sum(axis=1)

    plt.plot(df_dom['Datetime'], df_dom['TotalBid'], label='Total Bid Depth', color='green', alpha=0.7)
    plt.plot(df_dom['Datetime'], df_dom['TotalAsk'], label='Total Ask Depth', color='red', alpha=0.7)

    plt.title('Orderbook Liquidity (Levels 1-5)')
    plt.xlabel('Time')
    plt.ylabel('Volume')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(os.path.join(output_path, "liquidity_depth.png"))
    print("Saved liquidity_depth.png")

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    ea_files, dom_path = find_logs(LOG_DIR)
    if not ea_files or not dom_path:
        return

    print("Loading and Merging Data...")
    df_ea, df_dom = load_data(ea_files, dom_path)

    if df_ea is not None and df_dom is not None:
        print(f"Loaded {len(df_ea)} total trades and {len(df_dom)} DOM snapshots.")

        plot_velocity_trades_multi(df_ea, df_dom, OUTPUT_DIR)
        plot_liquidity_heatmap(df_dom, OUTPUT_DIR)

        print(f"\nAnalysis Complete. Charts saved to {OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
