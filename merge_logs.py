import glob
import os
import sys

def merge_csv_text(pattern, output_file):
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"No files found for pattern: {pattern}")
        return

    print(f"Merging {len(files)} files into {output_file}...")

    with open(output_file, 'w') as outfile:
        for i, filename in enumerate(files):
            print(f"Processing: {filename}")
            with open(filename, 'r') as infile:
                header = infile.readline()
                if i == 0:
                    outfile.write(header)

                # Write the rest
                for line in infile:
                    # Optional: Check if line is just a repeated header (some loggers do this)
                    if line.startswith("Time,TickMS"): continue
                    outfile.write(line)

    print("Merge complete.")

if __name__ == "__main__":
    # Hardcoded for the current task, or generic usage
    # EURUSD Pattern
    pattern = "analysis_input/Mimic_Research_EURUSD_20260127_*.csv"
    output = "analysis_input/Mimic_Research_EURUSD_Merged.csv"

    merge_csv_text(pattern, output)
