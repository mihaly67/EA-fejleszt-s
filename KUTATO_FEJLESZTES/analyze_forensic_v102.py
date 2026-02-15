import pandas as pd
import numpy as np
import sys

def analyze_v102_forensic(file_path):
    print(f"\n🕵️‍♂️ COLUMBO FORENSIC ENGINE - v1.02 (Restricted Data) Analysis")
    print(f"File: {file_path}")

    try:
        df = pd.read_csv(file_path)
        df['Time'] = pd.to_datetime(df['Time'])
    except Exception as e:
        print(f"❌ Error: {e}")
        return

    # --- 1. Basic Timeline & Events ---
    print("\n--- 1. Timeline Overview ---")
    start = df['Time'].iloc[0]
    end = df['Time'].iloc[-1]
    duration = end - start
    print(f"Start: {start}")
    print(f"End:   {end}")
    print(f"Dur:   {duration}")

    # Detect Action Changes
    df['Action_Change'] = df['Action'] != df['Action'].shift(1)
    actions = df[df['Action_Change']]
    print("\n--- Action Log ---")
    print(actions[['Time', 'Action', 'PosCount', 'Spread', 'Velocity']].to_string())

    # --- 2. Hybrid Indicator Analysis (Pulse & Flow) ---
    print("\n--- 2. The Suspect's Pulse (Hybrid Indicators) ---")

    # We want to see how Hybrid Indicators behave during High Velocity or Spread Spikes
    # Define "Stress Events"

    # A. Velocity Spikes (> 95th percentile)
    vel_thresh = df['Velocity'].abs().quantile(0.95)
    stress_events = df[df['Velocity'].abs() > vel_thresh]

    print(f"Detected {len(stress_events)} High Velocity Events (> {vel_thresh:.4f})")

    if not stress_events.empty:
        # Check Hybrid Correlation
        avg_macd_stress = stress_events['Hybrid_MACD'].mean()
        avg_df_stress = stress_events['Hybrid_DFCurve'].mean()
        avg_flow_stress = stress_events['Flow_MFI'].mean()

        avg_macd_global = df['Hybrid_MACD'].mean()
        avg_df_global = df['Hybrid_DFCurve'].mean()
        avg_flow_global = df['Flow_MFI'].mean()

        print("\n   Compare Normal vs Stress:")
        print(f"   MACD:  Global {avg_macd_global:.4f} | Stress {avg_macd_stress:.4f}")
        print(f"   PULSE: Global {avg_df_global:.4f}   | Stress {avg_df_stress:.4f}")
        print(f"   FLOW:  Global {avg_flow_global:.2f}    | Stress {avg_flow_stress:.2f}")

        # Did Flow anticipate? (Check 5 ticks before stress)
        print("\n   Did Flow Anticipate the Spike? (Lookback 5 ticks)")
        anticipations = []
        for idx in stress_events.index:
            if idx < 5: continue
            pre_event = df.iloc[idx-5:idx]
            # Check if Flow was already diverging
            flow_trend = pre_event['Flow_MFI'].diff().mean()
            anticipations.append(flow_trend)

        avg_anticipation = np.mean(anticipations)
        print(f"   Avg Flow Trend before Spike: {avg_anticipation:.4f} (Pos=Rising, Neg=Falling)")

    # --- 3. PosCount & PL Anomalies ---
    print("\n--- 3. The Money Trail (PL & Positions) ---")
    # Check for sudden PL drops without PosCount change (Slippage/Fees/Bug)

    df['PL_Diff'] = df['Floating_PL'].diff()
    # Filter for significant drops
    drops = df[df['PL_Diff'] < -5.0] # Arbitrary threshold for visual check
    if not drops.empty:
        print("   ⚠️ Sudden PL Drops Detected:")
        print(drops[['Time', 'Floating_PL', 'Realized_PL', 'PosCount', 'Spread']].head(10).to_string())
    else:
        print("   ✅ No massive sudden PL drops detected in this session.")

    # --- 4. Broker Anomalies (Spread) ---
    max_spread = df['Spread'].max()
    print(f"\n--- 4. Broker Tactics ---")
    print(f"   Max Spread: {max_spread}")

    # Check if Spread correlates with Action
    spread_on_action = df.groupby('Action')['Spread'].mean()
    print("   Avg Spread by Action:")
    print(spread_on_action)

if __name__ == "__main__":
    analyze_v102_forensic("analysis_input/Mimic_Merged_v1.02.csv")
