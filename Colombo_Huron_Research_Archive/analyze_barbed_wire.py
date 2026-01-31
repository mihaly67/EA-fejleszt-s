import pandas as pd
import sys
import numpy as np

def analyze_barbed_wire(file_path):
    print(f"--- Analyzing Barbed Wire Log: {file_path} ---")
    
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    # Basic Stats
    print(f"Total Ticks: {len(df)}")
    print(f"Duration: {df['Time'].iloc[0]} to {df['Time'].iloc[-1]}")
    
    # Event Analysis
    events = df[df['LastEvent'].notna() & (df['LastEvent'] != "")]
    print("\n--- Events Detected ---")
    print(events[['Time', 'LastEvent', 'Bid', 'Spread', 'PosCount', 'Session_PL']].to_string())
    
    # Wire Specifics
    layer_expansions = df[df['LastEvent'].str.contains("EXPAND", na=False)]
    breaches = df[df['LastEvent'].str.contains("LAYER_FILLED", na=False)]
    
    print(f"\nTotal Layers Created: {len(layer_expansions)}")
    print(f"Total Breaches (Traps Filled): {len(breaches)}")
    
    # Physics Analysis around Breaches
    print("\n--- Physics Reaction to Breaches (Window: +/- 10 ticks) ---")
    for idx, row in breaches.iterrows():
        start_idx = max(0, idx - 10)
        end_idx = min(len(df), idx + 20)
        window = df.iloc[start_idx:end_idx]
        
        max_vel = window['Velocity'].abs().max()
        max_spread = window['Spread'].max()
        avg_spread = window['Spread'].mean()
        
        print(f"Breach at {row['Time']} | Price: {row['Bid']} | Max Vel: {max_vel:.5f} | Max Spread: {max_spread} (Avg: {avg_spread:.1f})")

    # P/L Analysis
    max_dd = df['Floating_PL'].min()
    max_profit = df['Floating_PL'].max()
    final_pl = df['Session_PL'].iloc[-1]
    
    print("\n--- Financial Outcome ---")
    print(f"Max Drawdown (Floating): {max_dd}")
    print(f"Max Profit (Floating): {max_profit}")
    print(f"Final Session Realized PL: {final_pl}")
    
    # Check for "Kill" signs (Rapid Drop after Profit)
    # Simple heuristic: If PL drops > 20% of Max Profit in < 5 seconds
    
    print("\n--- Conclusion ---")
    if len(breaches) > 5:
        print("Status: HEAVY FIGHTING. The price is pushing through layers.")
    else:
        print("Status: QUIET / RANGE. The wire is holding or not reached.")
        
    if max_spread > 100: # Assuming points
        print("ALERT: HUGE SPREAD DETECTED. Broker might be widening defenses.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_barbed_wire.py <csv_file>")
    else:
        analyze_barbed_wire(sys.argv[1])
