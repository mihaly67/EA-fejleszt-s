import pandas as pd
import numpy as np
import glob
import os
import sys

# --- Configuration ---
LOG_DIR = "test_logs/eurusd_test"

def load_and_prep_data(log_dir):
    """Loads DOM and Trojan logs, creating a unified timeline."""

    # 1. Load DOM Log (Background Market Data)
    dom_files = glob.glob(os.path.join(log_dir, "Hybrid_DOM_Log_*.csv"))
    if not dom_files:
        print("CRITICAL: No DOM log found.")
        return None, None

    dom_path = max(dom_files, key=os.path.getmtime) # Use latest
    df_dom = pd.read_csv(dom_path)

    # Parse DateTime
    df_dom['Datetime'] = pd.to_datetime(df_dom['Time'] + '.' + df_dom['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')
    df_dom.set_index('Datetime', inplace=True)

    # Calculate Total Liquidity
    bid_cols = [f'BidV{i}' for i in range(1, 6)]
    ask_cols = [f'AskV{i}' for i in range(1, 6)]
    df_dom['TotalBidLiq'] = df_dom[bid_cols].sum(axis=1)
    df_dom['TotalAskLiq'] = df_dom[ask_cols].sum(axis=1)
    df_dom['L1_Bid_Vol'] = df_dom['BidV1']
    df_dom['L1_Ask_Vol'] = df_dom['AskV1']

    # 2. Load Trojan Logs (Stress Events)
    trojan_files = sorted(glob.glob(os.path.join(log_dir, "Trojan_Horse_Log_*.csv")))
    phases = []

    for i, f in enumerate(trojan_files):
        df = pd.read_csv(f)
        if df.empty: continue

        df['Datetime'] = pd.to_datetime(df['Time'] + '.' + df['MS'].astype(str), format='%Y.%m.%d %H:%M:%S.%f')

        start_time = df['Datetime'].min()
        end_time = df['Datetime'].max()
        trade_vol = df['TradeVol'].mean()
        trade_count = len(df)

        phase_name = f"Phase_{i+1}"
        if trade_vol < 1.0: phase_name += "_LowLoad"
        else: phase_name += "_StressTest"

        phases.append({
            'name': phase_name,
            'start': start_time,
            'end': end_time,
            'df': df,
            'avg_lot': trade_vol,
            'count': trade_count
        })

    return df_dom, phases

def analyze_phase(phase, df_dom_full):
    """Calculates metrics for a specific phase window."""

    # Filter DOM data to this phase window
    mask = (df_dom_full.index >= phase['start']) & (df_dom_full.index <= phase['end'])
    df_dom = df_dom_full[mask]

    if df_dom.empty:
        return {"error": "No DOM data coverage"}

    # 1. Latency / Execution Speed
    # Calculate time delta between consecutive trades in the EA log
    trade_times = phase['df']['Datetime'].sort_values()
    inter_arrival = trade_times.diff().dt.total_seconds() * 1000 # MS
    avg_latency = inter_arrival.mean()

    # 2. Liquidity Analysis
    avg_bid_liq = df_dom['TotalBidLiq'].mean()
    avg_ask_liq = df_dom['TotalAskLiq'].mean()

    # Spoofing Ratio: (Total - L1) / L1. Higher means more "fake" depth relative to best price.
    spoof_ratio_bid = ((df_dom['TotalBidLiq'] - df_dom['L1_Bid_Vol']) / df_dom['L1_Bid_Vol'].replace(0, 1)).mean()

    # 3. Price Stability
    spread_avg = df_dom['Spread'].mean()
    price_volatility = df_dom['BestBid'].std() * 100000 # Points

    # 4. Market Impact (Directional Drift)
    start_price = df_dom['BestBid'].iloc[0]
    end_price = df_dom['BestBid'].iloc[-1]
    drift_pts = (end_price - start_price) * 100000

    return {
        "Avg_InterTrade_Time_MS": avg_latency,
        "Avg_Total_Bid_Liq": avg_bid_liq,
        "Avg_Total_Ask_Liq": avg_ask_liq,
        "Spoofing_Ratio": spoof_ratio_bid,
        "Avg_Spread": spread_avg,
        "Price_Volatility": price_volatility,
        "Price_Drift_Pts": drift_pts
    }

def print_report(df_dom, phases):
    print("="*60)
    print(f"   BROKER ALGORITHM PSYCHOLOGY REPORT ({len(phases)} Phases)")
    print("="*60)

    results = []

    for p in phases:
        metrics = analyze_phase(p, df_dom)
        p.update(metrics)
        results.append(p)

        print(f"\n--- {p['name']} ---")
        print(f"Trades: {p['count']} | Avg Lot: {p['avg_lot']}")
        print(f"Duration: {(p['end'] - p['start']).total_seconds():.1f}s")

        if "error" in metrics:
            print(f"Warning: {metrics['error']}")
            continue

        print(f"Execution Speed (Avg Gap): {metrics['Avg_InterTrade_Time_MS']:.1f} ms")
        print(f"Liquidity (Bid/Ask): {metrics['Avg_Total_Bid_Liq']:.0f} / {metrics['Avg_Total_Ask_Liq']:.0f}")
        print(f"Spoofing Ratio (Depth/L1): {metrics['Spoofing_Ratio']:.2f}x")
        print(f"Spread Stability: {metrics['Avg_Spread']:.1f} pts (Vol: {metrics['Price_Volatility']:.2f})")
        print(f"Price Drift: {metrics['Price_Drift_Pts']:.1f} pts")

    print("\n" + "="*60)
    print("COMPARATIVE ANALYSIS (Stress vs Baseline)")
    print("="*60)

    if len(results) >= 3:
        base = results[0] # Phase 1
        stress = results[2] # Phase 3 (100 Lot)

        # 1. Liquidity Reaction
        liq_change = (stress['Avg_Total_Bid_Liq'] - base['Avg_Total_Bid_Liq']) / base['Avg_Total_Bid_Liq'] * 100
        print(f"1. LIQUIDITY REACTION:")
        print(f"   Baseline: {base['Avg_Total_Bid_Liq']:.0f} -> Stress: {stress['Avg_Total_Bid_Liq']:.0f}")
        print(f"   Change: {liq_change:+.1f}%")
        if liq_change < -20: print("   CONCLUSION: Broker PULLED liquidity aggressively (Defense Mode).")
        elif liq_change > 20: print("   CONCLUSION: Broker ADDED liquidity (Absorption Mode).")
        else: print("   CONCLUSION: No significant liquidity change.")

        # 2. Execution Speed (Stress Handling)
        speed_change = stress['Avg_InterTrade_Time_MS'] - base['Avg_InterTrade_Time_MS']
        print(f"\n2. SYSTEM LATENCY (Load Handling):")
        print(f"   Baseline Gap: {base['Avg_InterTrade_Time_MS']:.1f}ms -> Stress Gap: {stress['Avg_InterTrade_Time_MS']:.1f}ms")
        if stress['Avg_InterTrade_Time_MS'] < 200:
             print("   CONCLUSION: Broker system absorbed the load effortlessly (High Perf).")
        else:
             print("   CONCLUSION: Broker showed signs of lag/queuing.")

        # 3. Price Punishment (Trojan Theory)
        print(f"\n3. PRICE DRIFT (Trojan Hypothesis):")
        print(f"   During 100 Lot attack, price moved: {stress['Price_Drift_Pts']:.1f} points.")
        if abs(stress['Price_Drift_Pts']) < 2.0:
            print("   CONCLUSION: Price remained rigid. The broker absorbs flow without moving price.")
            print("               (Interpretation: Market Maker 'B-Book' behavior, eating the risk).")
        else:
            print("   CONCLUSION: Price moved significantly. The broker hedges/offsets the flow.")

if __name__ == "__main__":
    df_dom, phases = load_and_prep_data(LOG_DIR)
    if df_dom is not None and phases:
        print_report(df_dom, phases)
