import pandas as pd
import glob
import os

def merge_v102():
    print("Merging v1.02 files...")
    files = sorted(glob.glob("analysis_input/session_bad/Mimic_Merkava_WIRE_GOLD_v1.02_*.csv"))
    if not files:
        print("No v1.02 files found.")
        return

    dfs = []
    for f in files:
        try:
            df = pd.read_csv(f)
            dfs.append(df)
            print(f"Loaded {f}: {len(df)} rows")
        except Exception as e:
            print(f"Error loading {f}: {e}")

    if dfs:
        merged = pd.concat(dfs, ignore_index=True)
        merged['Time'] = pd.to_datetime(merged['Time'])
        merged = merged.sort_values('Time')
        output_path = "analysis_input/Mimic_Merged_v1.02.csv"
        merged.to_csv(output_path, index=False)
        print(f"Merged v1.02 saved to {output_path}: {len(merged)} rows")

        # Quick Inspect
        print("Columns in v1.02:", merged.columns.tolist())
        print(merged[['Time', 'Action', 'Hybrid_MACD', 'Hybrid_DFCurve', 'Flow_MFI']].head())

def check_v103():
    print("\nChecking v1.03 file...")
    files = glob.glob("analysis_input/session_better/Mimic_Merkava_WIRE_GOLD_v1.03_*.csv")
    if not files:
        print("No v1.03 files found.")
        return

    f = files[0] # Assuming one file based on ls output
    try:
        df = pd.read_csv(f)
        print(f"Loaded {f}: {len(df)} rows")
        print("Columns in v1.03:", df.columns.tolist())

        # Check for PL issues (duplicates?)
        pl_cols = [c for c in df.columns if 'PL' in c]
        print(f"PL Columns: {pl_cols}")

        # Check Hybrid Cols
        hybrid_cols = [c for c in df.columns if 'Hybrid' in c or 'Flow' in c]
        print(f"Hybrid Columns: {hybrid_cols}")

    except Exception as e:
        print(f"Error loading {f}: {e}")

if __name__ == "__main__":
    merge_v102()
    check_v103()
