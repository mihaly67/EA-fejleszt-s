import csv
import math
import os
import glob
import statistics
from datetime import datetime, timedelta

# --- ANALYZER FOR MIMIC RESEARCH v2.07 (Fixed for missing TRAP_EXEC) ---

class MimicSessionAnalyzer:
    def __init__(self):
        self.data = []
        self.trap_events = []
        self.pair_name = "UNKNOWN"

    def parse_file(self, filepath):
        print(f"Parsing: {os.path.basename(filepath)}")
        self.pair_name = os.path.basename(filepath).split('_')[2] if '_' in os.path.basename(filepath) else "UNKNOWN"
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
                        continue

                    record['Phase'] = row[2]

                    # 2. Market Data
                    record['Bid'] = float(row[3])
                    record['Ask'] = float(row[4])
                    record['Spread'] = float(row[5])
                    record['Mid'] = (record['Bid'] + record['Ask']) / 2.0

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
                            record['Imbalance'] = 0.0
                    else:
                        record['BidVol'] = 0
                        record['AskVol'] = 0
                        record['Imbalance'] = 0.0

                    self.data.append(record)

                except Exception as e:
                    continue

        print(f"Loaded {len(self.data)} ticks for {self.pair_name}.")
        self.detect_traps()

    def detect_traps(self):
        self.trap_events = []
        in_trap = False
        trap_start_idx = -1

        # Logic: Trap starts when Phase becomes "POST_ANALYSIS" (implies execution happened)
        # OR "TRAP_EXEC" if caught.
        # It ends when Phase returns to "IDLE".

        for i, r in enumerate(self.data):
            phase = r['Phase']

            # Start Trigger
            is_active_phase = (phase == "TRAP_EXEC" or phase == "POST_ANALYSIS")

            if is_active_phase and not in_trap:
                in_trap = True
                trap_start_idx = i

            # End Trigger
            elif phase == "IDLE" and in_trap:
                in_trap = False
                trap_end_idx = i
                if trap_end_idx > trap_start_idx:
                    self.trap_events.append((trap_start_idx, trap_end_idx))

        if in_trap:
            self.trap_events.append((trap_start_idx, len(self.data)-1))

    def calculate_stats(self):
        print(f"\n==========================================")
        print(f"DEEP ANALYSIS REPORT: {self.pair_name}")
        print(f"==========================================")
        print(f"Total Traps Detected: {len(self.trap_events)}")

        if not self.trap_events:
            print("No trap sequences found.")
            return

        total_pl = 0.0
        win_count = 0
        loss_count = 0

        all_spreads = [r['Spread'] for r in self.data]
        baseline_spread = statistics.mean(all_spreads) if all_spreads else 0.0
        print(f"Baseline Spread (Session Avg): {baseline_spread:.1f} pts")

        for i, (start_idx, end_idx) in enumerate(self.trap_events):
            start_row = self.data[start_idx]
            end_row = self.data[end_idx]

            duration = (end_row['Timestamp'] - start_row['Timestamp']).total_seconds()

            # P/L Logic:
            # We want the Realized PL generated *during* this sequence.
            # In the log, 'Realized_PL' accumulates per tick?
            # Re-reading EA: "g_last_realized_pl += ..." in OnTradeTransaction.
            # In OnTick: "WriteLog(); g_last_realized_pl = 0.0;".
            # So Realized_PL column is INCREMENTAL (only shows newly closed profit this tick).
            # To get total realized for the trap, we SUM the column over the window.

            trap_realized = 0.0
            min_float = 0.0
            max_float = -9999.0

            spreads = []
            vels = []

            for k in range(start_idx, end_idx + 1):
                r = self.data[k]
                trap_realized += r['Realized_PL']

                f = r['Floating_PL']
                if f < min_float: min_float = f
                if f > max_float: max_float = f

                spreads.append(r['Spread'])
                vels.append(abs(r['Phy_Vel']))

            avg_spread_trap = statistics.mean(spreads) if spreads else 0
            avg_vel_trap = statistics.mean(vels) if vels else 0

            # Outcome Definition
            # If trap ends, positions are closed. Realized should capture it.
            # If manually closed, Realized captures it.
            total_outcome = trap_realized

            total_pl += total_outcome
            if total_outcome > 0: win_count += 1
            else: loss_count += 1

            # Context (Lookback 1 tick before start)
            ctx_idx = max(0, start_idx - 1)
            ctx_imb = self.data[ctx_idx]['Imbalance']

            tolerance_ratio = abs(min_float) / (max_float + 0.0001) if max_float > 0 else 999.0

            print(f"\n--- TRAP #{i+1} ({start_row['Timestamp'].strftime('%H:%M:%S')}) ---")
            print(f"   Duration: {duration:.1f}s")
            print(f"   Outcome:  {total_outcome:.2f}")
            print(f"   Risk Profile (Pain Ratio: {tolerance_ratio:.2f}):")
            print(f"     Max Drawdown: {min_float:.2f}")
            print(f"     Max Profit:   {max_float:.2f}")

            print(f"   Broker Behavior:")
            print(f"     Spread: {avg_spread_trap:.1f} (Diff: {avg_spread_trap - baseline_spread:.1f})")
            print(f"     Velocity: {avg_vel_trap:.5f}")
            print(f"     DOM Imbalance: {ctx_imb:.2f}")

        print(f"\n==========================================")
        print(f"SESSION SUMMARY")
        print(f"==========================================")
        print(f"Total P/L: {total_pl:.2f}")
        print(f"Win Rate:  {win_count}/{len(self.trap_events)} ({(win_count/len(self.trap_events))*100:.1f}%)")
        print(f"Data Source: {self.pair_name}")

def main():
    # Find logs
    files = glob.glob("analysis_input/new_session/Mimic_Research_*.csv")
    if not files:
        print("No logs found.")
        return

    for f in files:
        analyzer = MimicSessionAnalyzer()
        analyzer.parse_file(f)
        analyzer.calculate_stats()

if __name__ == "__main__":
    main()
