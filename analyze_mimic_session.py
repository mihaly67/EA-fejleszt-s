import csv
import math
import os
import glob
from datetime import datetime, timedelta

# --- NEW SCHEMA (Research EA v2.07+) ---
# Time, TickMS, Phase, Bid, Ask, Spread,
# Velocity, Acceleration,
# Mom_Hist, Mom_Macd, Mom_Sig,
# Flow_MFI, Flow_DUp, Flow_DDown,
# Ext_VA_Vel, Ext_VA_Acc,
# Floating_PL, Realized_PL, Action,
# BestBid, BestAsk, BidV1..5, AskV1..5

class MimicSessionAnalyzer:
    def __init__(self):
        self.data = []
        self.trap_events = []

    def parse_file(self, filepath):
        print(f"Parsing: {filepath}")
        self.data = []
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            header = next(reader, None) # Skip Header

            for row in reader:
                if not row or len(row) < 19: continue

                try:
                    record = {}
                    # 1. Time & Phase
                    dt_str = row[0]
                    ms = int(row[1])
                    try:
                        dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S")
                        record['Timestamp'] = dt + timedelta(milliseconds=ms)
                    except:
                        continue # Invalid time

                    record['Phase'] = row[2]

                    # 2. Market Data
                    record['Bid'] = float(row[3])
                    record['Ask'] = float(row[4])
                    record['Spread'] = float(row[5])

                    # 3. Physics
                    record['Phy_Vel'] = float(row[6])
                    record['Phy_Acc'] = float(row[7])

                    # 4. Indicators
                    record['Mom_Hist'] = float(row[8])
                    record['Flow_MFI'] = float(row[11])
                    record['VA_Vel'] = float(row[14])

                    # 5. PL & Action
                    record['Floating_PL'] = float(row[16])
                    record['Realized_PL'] = float(row[17])
                    record['Action'] = row[18] # Comment field

                    # 6. DOM (If available - checks len)
                    if len(row) >= 30:
                        # BestBid(19), BestAsk(20), BidV1-5(21-25), AskV1-5(26-30)
                        record['BidVol'] = sum([int(row[i]) for i in range(21, 26)])
                        record['AskVol'] = sum([int(row[i]) for i in range(26, 31)])
                        if record['AskVol'] > 0:
                            record['Imbalance'] = record['BidVol'] / record['AskVol']
                        else:
                            record['Imbalance'] = 0
                    else:
                        record['BidVol'] = 0
                        record['AskVol'] = 0
                        record['Imbalance'] = 0

                    self.data.append(record)

                except Exception as e:
                    # print(f"Row error: {e}")
                    continue

        print(f"Loaded {len(self.data)} ticks.")
        self.detect_traps()

    def detect_traps(self):
        # Logic: Find transition from ARMED to TRAP_EXEC
        self.trap_events = []

        # We look for the moment Phase becomes "TRAP_EXEC"
        # Since we scan linearly, we can just look for the first occurrence in a sequence

        in_trap = False
        trap_start_idx = -1

        for i, r in enumerate(self.data):
            phase = r['Phase']

            if phase == "TRAP_EXEC" and not in_trap:
                in_trap = True
                trap_start_idx = i
            elif phase == "IDLE" and in_trap:
                # Trap sequence ended
                in_trap = False
                trap_end_idx = i
                self.trap_events.append((trap_start_idx, trap_end_idx))

    def analyze(self):
        print(f"\n--- ANALYSIS RESULT ({len(self.trap_events)} Traps) ---")

        for i, (start_idx, end_idx) in enumerate(self.trap_events):
            start_row = self.data[start_idx]
            end_row = self.data[end_idx]

            # Context (Data just before execution)
            context_idx = max(0, start_idx - 1)
            ctx = self.data[context_idx]

            # Outcome
            # Calculate Realized PL gained during this window
            pl_start = start_row['Realized_PL']
            pl_end = end_row['Realized_PL']
            pl_gain = pl_end - pl_start

            # Duration
            duration = (end_row['Timestamp'] - start_row['Timestamp']).total_seconds()

            print(f"\nTrap #{i+1} at {start_row['Timestamp'].strftime('%H:%M:%S')}")
            print(f"  Duration: {duration:.1f}s")
            print(f"  Context:")
            print(f"    Spread: {ctx['Spread']:.1f}")
            print(f"    Mom Hist: {ctx['Mom_Hist']:.2f}")
            print(f"    MFI: {ctx['Flow_MFI']:.1f}")
            print(f"    DOM Imbalance: {ctx['Imbalance']:.2f} (BidV:{ctx['BidVol']} / AskV:{ctx['AskVol']})")
            print(f"  Outcome:")
            print(f"    Realized P/L: {pl_gain:.2f}")

            # Check for drawdown during trap (Floating PL min)
            min_float = 0.0
            for k in range(start_idx, end_idx):
                f = self.data[k]['Floating_PL']
                if f < min_float: min_float = f
            print(f"    Max Drawdown: {min_float:.2f}")

def main():
    input_dir = "." # Current directory for testing or 'analysis_input'
    # Look for Mimic_Research_*.csv
    files = glob.glob("Mimic_Research_*.csv")

    if not files:
        # Fallback to analysis_input
        files = glob.glob(os.path.join("analysis_input", "Mimic_Research_*.csv"))

    if not files:
        print("No Mimic Research logs found.")
        return

    # Process latest file
    latest_file = max(files, key=os.path.getctime)

    analyzer = MimicSessionAnalyzer()
    analyzer.parse_file(latest_file)
    analyzer.analyze()

if __name__ == "__main__":
    main()
