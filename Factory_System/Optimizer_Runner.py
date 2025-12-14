import pandas as pd
import numpy as np
import glob
import os

# Import core logic
try:
    from Hybrid_Optimizer import simulate_hybrid_indicator
except ImportError:
    # If running standalone, copy the function here or ensure path is set
    import sys
    sys.path.append('.')
    from Hybrid_Optimizer import simulate_hybrid_indicator

def run_optimizer_on_csvs(folder_path='.'):
    """
    Looks for *_M1_*.csv files in the folder and runs optimization.
    """
    csv_files = glob.glob(os.path.join(folder_path, "*_M1_*.csv"))

    if not csv_files:
        print("No CSV files found matching '*_M1_*.csv'. Run Data_Exporter.mq5 first!")
        return

    print(f"Found {len(csv_files)} files to analyze.")
    print("-" * 60)
    print(f"{'File':<25} | {'Rec. Saturation':<15} | {'Avg Signal'}")
    print("-" * 60)

    for csv_path in csv_files:
        try:
            df = pd.read_csv(csv_path)

            # Identify Instrument Type roughly by name
            filename = os.path.basename(csv_path).upper()
            if "XAU" in filename or "GOLD" in filename:
                inst_type = "Gold"
                sat_candidates = [50, 100, 200, 500, 1000]
            elif "BTC" in filename or "ETH" in filename:
                inst_type = "Crypto"
                sat_candidates = [100, 500, 1000, 5000]
            elif "JPY" in filename: # JPY pairs have different point scale?
                inst_type = "Forex"
                sat_candidates = [10, 20, 50, 100]
            elif "US30" in filename or "DAX" in filename:
                 inst_type = "Index"
                 sat_candidates = [20, 50, 100, 200]
            else:
                inst_type = "Forex"
                sat_candidates = [10, 20, 50, 100] # Points

            # Determine Point Value
            # Heuristic: If price ~ 1.0 (EURUSD), Point=0.00001. If price ~ 150 (USDJPY), Point=0.001.
            # If price ~ 2000 (Gold), Point=0.01. If price ~ 30000 (BTC), Point=1.0 or 0.01?
            # Better: Estimate from data granularity or assume standard MetaTrader points.
            # Let's assume input CSV is standard.
            # We can calculate average tick size?

            # Simple heuristic for Point Value based on price magnitude (Standard FX/CFD)
            avg_price = df['Close'].mean()
            point_val = 0.00001
            if avg_price > 500: point_val = 0.01 # Gold/Index
            if avg_price > 20000: point_val = 1.0 # BTC
            if "JPY" in filename: point_val = 0.001

            best_sat = 0
            best_score = 100 # Closer to 0.6 is better (AvgAbsVal)

            # Optimization Loop
            for sat in sat_candidates:
                params = {
                    'FastPeriod': 12, 'SlowPeriod': 26, 'WPRPeriod': 14,
                    'FastWeight': 0.6, 'SaturationPoints': sat, 'PointValue': point_val
                }
                res = simulate_hybrid_indicator(df, params)
                avg_amp = res['Hybrid'].abs().mean()

                # We want Avg Amplitude to be "healthy" (e.g., around 0.5 - 0.7).
                # If < 0.2, too weak (Scale too high). If > 0.9, saturated (Scale too low).
                # Target: 0.6
                score = abs(avg_amp - 0.6)

                if score < best_score:
                    best_score = score
                    best_sat = sat

            # Run final verification
            params = {'FastPeriod': 12, 'SlowPeriod': 26, 'WPRPeriod': 14, 'FastWeight': 0.6, 'SaturationPoints': best_sat, 'PointValue': point_val}
            final_res = simulate_hybrid_indicator(df, params)
            final_avg = final_res['Hybrid'].abs().mean()

            print(f"{filename:<25} | {best_sat:<15} | {final_avg:.4f}")

        except Exception as e:
            print(f"Error processing {csv_path}: {e}")

if __name__ == "__main__":
    run_optimizer_on_csvs()
