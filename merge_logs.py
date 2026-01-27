import pandas as pd
import glob
import os

# Path to your CSV files
path = 'analysis_input/new_session/'
all_files = glob.glob(os.path.join(path, "Mimic_Research_*.csv"))

# Sort files by creation time
all_files.sort(key=os.path.getmtime)

print(f"Found {len(all_files)} log files.")

dfs = []
for filename in all_files:
    try:
        # The file might be using a separator that confuses the parser if there are variable columns
        # But the problem is actually that the header is complex or the index is being inferred wrong.
        # Let's force reading everything as string first to debug or simple parsing.

        # Actually, looking at the previous 'cat', the file looks standard.
        # The python one-liner output showed the index is being confused.
        # "2026.01.27 09:56:31" became the index? No, it's just the print output.

        # Let's try reading with NO index column.
        df = pd.read_csv(filename, index_col=False)

        # The column name is likely "Time"
        if 'Time' in df.columns:
             # Filter garbage
             df = df[df['Time'].astype(str).str.contains(r'202\d\.')]
             dfs.append(df)
             print(f"Loaded: {os.path.basename(filename)} ({len(df)} rows)")
        else:
             # Maybe the first column is the index?
             # Let's reset index if that happened
             if df.index.name == 'Time':
                 df.reset_index(inplace=True)
                 dfs.append(df)
                 print(f"Loaded (Index Reset): {os.path.basename(filename)}")
             else:
                 print(f"Skipping {filename}: Headers: {df.columns.tolist()}")

    except Exception as e:
        print(f"Error reading {filename}: {e}")

if dfs:
    merged_df = pd.concat(dfs, ignore_index=True)

    # Sort
    merged_df['Time'] = pd.to_datetime(merged_df['Time'], format='%Y.%m.%d %H:%M:%S', errors='coerce')
    merged_df.sort_values(by=['Time', 'TickMS'], inplace=True)
    merged_df['Time'] = merged_df['Time'].dt.strftime('%Y.%m.%d %H:%M:%S')

    output_path = 'analysis_input/new_session/merged_session.csv'
    merged_df.to_csv(output_path, index=False)
    print(f"Successfully created merged log: {output_path} with {len(merged_df)} rows.")
else:
    print("No valid dataframes to merge.")
