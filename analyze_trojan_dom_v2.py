import pandas as pd
import matplotlib.pyplot as plt
import glob
import os
import sys
from datetime import datetime

# --- Configuration ---
LOG_DIR = "test_logs"  # Default directory, falls back to current if not found
OUTPUT_DIR = "analysis_output"

def find_latest_logs(directory):
    """Finds the most recent Trojan_Horse and Hybrid_DOM logs."""
    if not os.path.exists(directory):
        directory = "." # Fallback to current dir

    # Pattern matching
    ea_files = glob.glob(os.path.join(directory, "Trojan_Horse_Log_*.csv"))
    dom_files = glob.glob(os.path.join(directory, "Hybrid_DOM_Log_*.csv"))

    if not ea_files:
        print("No Trojan Horse logs found!")
        return None, None
    if not dom_files:
        print("No DOM logs found!")
        return None, None

    # Sort by modification time (newest first)
    ea_latest = max(ea_files, key=os.path.getmtime)
    dom_latest = max(dom_files, key=os.path.getmtime)

    print(f"Latest EA Log: {ea_latest}")
    print(f"Latest DOM Log: {dom_latest}")

    return ea_latest, dom_latest

def load_data(ea_path, dom_path):
    """Loads and merges the datasets."""
    try:
        # Load EA Data
        # EA Columns: Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,BestBid...
        df_ea = pd.read_csv(ea_path)

        # Load DOM Data
        # DOM Columns: Time,MS,LOG,0,0.0... (Trade cols are dummy), BestBid, BestAsk...
        df_dom = pd.read_csv(dom_path)

        # Parse Dates
        # Format: 2026.01.17 11:23:36
        df_ea['Datetime'] = pd.to_datetime(df_ea['Time'] + '.' + df_ea['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')
        df_dom['Datetime'] = pd.to_datetime(df_dom['Time'] + '.' + df_dom['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')

        return df_ea, df_dom
    except Exception as e:
        print(f"Error loading data: {e}")
        return None, None

def plot_velocity_trades(df_ea, df_dom, output_path):
    """Plots Price Velocity with Trade markers."""
    plt.figure(figsize=(14, 7))

    # Plot Velocity (from DOM logger for higher resolution)
    plt.plot(df_dom['Datetime'], df_dom['Velocity'], label='Market Velocity', color='blue', alpha=0.6, linewidth=1)

    # Filter EA Events
    opens = df_ea[df_ea['Action'] == 'OPEN']
    closes = df_ea[df_ea['Action'] == 'CLOSE_PROFIT']

    # Plot Trades
    plt.scatter(opens['Datetime'], opens['Velocity'], color='green', marker='^', s=50, label='Open Buy', zorder=5)
    plt.scatter(closes['Datetime'], closes['Velocity'], color='red', marker='v', s=50, label='Close Profit', zorder=5)

    plt.title('Market Velocity & Trade Execution')
    plt.xlabel('Time')
    plt.ylabel('Velocity (pips/sec)')
    plt.legend()
    plt.grid(True, alpha=0.3)

    plt.savefig(os.path.join(output_path, "velocity_trades.png"))
    print("Saved velocity_trades.png")

def plot_liquidity_heatmap(df_dom, output_path):
    """Plots Total Bid/Ask Liquidity over time."""
    plt.figure(figsize=(14, 7))

    # Calculate Total Depths
    # Columns are BidV1..5, AskV1..5
    bid_cols = [f'BidV{i}' for i in range(1, 6)]
    ask_cols = [f'AskV{i}' for i in range(1, 6)]

    # Check if columns exist
    if not all(col in df_dom.columns for col in bid_cols):
        print("Liquidity columns missing/renamed. Skipping Liquidity Plot.")
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

def plot_spread_velocity(df_dom, output_path):
    """Scatter plot of Spread vs Velocity to detect stability issues."""
    plt.figure(figsize=(10, 10))

    plt.scatter(df_dom['Velocity'], df_dom['Spread'], alpha=0.5, c='purple', s=10)

    plt.title('Spread vs Velocity Correlation')
    plt.xlabel('Velocity')
    plt.ylabel('Spread (Points)')
    plt.grid(True)

    plt.savefig(os.path.join(output_path, "spread_velocity.png"))
    print("Saved spread_velocity.png")

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    ea_path, dom_path = find_latest_logs(LOG_DIR)
    if not ea_path or not dom_path:
        # Try current directory
        ea_path, dom_path = find_latest_logs(".")
        if not ea_path:
            return

    print("Loading data...")
    df_ea, df_dom = load_data(ea_path, dom_path)

    if df_ea is not None and df_dom is not None:
        print(f"Data Loaded. EA Rows: {len(df_ea)}, DOM Rows: {len(df_dom)}")

        plot_velocity_trades(df_ea, df_dom, OUTPUT_DIR)
        plot_liquidity_heatmap(df_dom, OUTPUT_DIR)
        plot_spread_velocity(df_dom, OUTPUT_DIR)

        print(f"\nAnalysis Complete. Charts saved to {OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
