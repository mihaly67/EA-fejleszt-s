import pandas as pd
import numpy as np
import sys
import matplotlib.pyplot as plt

def analyze_hybrid_microscope(file_path):
    print(f"\n🔬 COLUMBO HYBRID MICROSCOPE - v1.03 Analysis")
    print(f"File: {file_path}")

    try:
        df = pd.read_csv(file_path)
        df['Time'] = pd.to_datetime(df['Time'])
    except Exception as e:
        print(f"❌ Error: {e}")
        return

    # --- 1. Data Integrity Check (Hybrid) ---
    print("\n--- 1. Hybrid Sensor Check ---")
    sensors = ['Hybrid_MACD', 'Hybrid_DFCurve', 'Flow_MFI', 'Flow_DUp', 'Flow_DDown']
    for s in sensors:
        unique_vals = df[s].nunique()
        mean_val = df[s].mean()
        print(f"   {s}: {unique_vals} unique values (Mean: {mean_val:.4f})")
        if unique_vals < 5:
            print(f"   ⚠️ WARNING: {s} appears FLATLINED or inactive!")

    # --- 2. Micro-Stall Detection ---
    # Def: Velocity drops from High to Near-Zero, followed by Price Reversal
    print("\n--- 2. Micro-Stall Signature Hunting ---")

    # Calc Acceleration (Velocity Delta)
    df['Vel_Diff'] = df['Velocity'].diff()

    # Find sudden stops (Negative Spike in Vel_Diff when Vel was High)
    high_vel_mask = df['Velocity'].shift(1) > df['Velocity'].quantile(0.80)
    sudden_stop_mask = df['Vel_Diff'] < -10.0 # Tuning needed

    stall_candidates = df[high_vel_mask & sudden_stop_mask]

    print(f"   Found {len(stall_candidates)} potential Micro-Stalls.")

    if not stall_candidates.empty:
        print("   Analyzing Top 5 Stalls:")
        for idx in stall_candidates.index[:5]:
            row = df.loc[idx]
            print(f"   🛑 Time: {row['Time']} | Vel Drop: {row['Vel_Diff']:.2f} | Pulse: {row['Hybrid_DFCurve']:.2f} | Flow: {row['Flow_MFI']:.2f}")

            # Check Next 10 Ticks for Reversal
            future = df.loc[idx:idx+10]
            price_change = future['Bid'].iloc[-1] - future['Bid'].iloc[0]
            print(f"      ➡️ 10-Tick Result: {price_change:.2f} pts")

    # --- 3. Hybrid Divergence ---
    # Does Pulse/Flow diverge from Price?
    # Simple Divergence: Price High vs Pulse Low (Bearish)

    print("\n--- 3. Hybrid Divergence Check ---")
    # Correlations
    corr_pulse = df['Bid'].corr(df['Hybrid_DFCurve'])
    corr_flow = df['Bid'].corr(df['Flow_MFI'])

    print(f"   Correlation Price vs Pulse (DFCurve): {corr_pulse:.4f}")
    print(f"   Correlation Price vs Flow (MFI): {corr_flow:.4f}")

    if abs(corr_pulse) < 0.3:
        print("   ℹ️ Low Pulse Correlation implies it's providing independent info (Good).")
    else:
        print("   ⚠️ High Pulse Correlation implies it just mirrors price.")

    # --- 4. Broker Hunting (Spread & Stops) ---
    print("\n--- 4. The Hunter's Footprints ---")
    # Check "SL Hiba" context if "Verdict" or "ActionDetails" mentions it
    sl_errors = df[df['Verdict'].str.contains("SL", na=False) | df['ActionDetails'].str.contains("SL", na=False)]

    if not sl_errors.empty:
        print(f"   ⚠️ Found {len(sl_errors)} SL Error Logs:")
        print(sl_errors[['Time', 'Spread', 'Verdict', 'ActionDetails']].to_string())
    else:
        print("   ℹ️ No explicit 'SL' errors in Verdict/ActionDetails column.")

    # Check Max Spread Spikes
    spread_spike = df[df['Spread'] > df['Spread'].median() * 1.5]
    if not spread_spike.empty:
         print(f"   ⚠️ {len(spread_spike)} Spread Spikes Detected (> 1.5x median).")
         print(spread_spike[['Time', 'Spread', 'Velocity', 'Hybrid_DFCurve']].head().to_string())

if __name__ == "__main__":
    analyze_hybrid_microscope("analysis_input/session_better/Mimic_Merkava_WIRE_GOLD_v1.03_2026.02.03_223253.csv")
