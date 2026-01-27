import csv
import sys
import statistics
import os

class SLImpactAnalyzer:
    def __init__(self):
        self.data = []

    def load_data(self, filepath):
        print(f"Reading: {os.path.basename(filepath)}")
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if not header: return

            # Dynamic Column Mapping
            try:
                idx_bid = header.index("Bid")
                idx_ask = header.index("Ask")
                idx_vel = header.index("Velocity")
                idx_pos = header.index("PosCount")
                # Try to find ActiveSL
                idx_sl = -1
                if "ActiveSL" in header: idx_sl = header.index("ActiveSL")
            except:
                return # Can't analyze without structure

            for row in reader:
                if not row: continue
                try:
                    r = {
                        'time': row[0].split(' ')[1],
                        'bid': float(row[idx_bid]),
                        'ask': float(row[idx_ask]),
                        'mid': (float(row[idx_bid]) + float(row[idx_ask])) / 2,
                        'vel': abs(float(row[idx_vel])),
                        'pos': int(float(row[idx_pos])),
                        'sl': float(row[idx_sl]) if idx_sl != -1 else 0.0
                    }
                    self.data.append(r)
                except: continue

    def analyze_probing(self):
        print("\n--- ANALYZING 'PROBING' BEHAVIOR (Safety Zone) ---")

        in_trade = False
        entry_price = 0.0
        trade_start_idx = 0

        probes = []

        for i, r in enumerate(self.data):
            # Detect Entry
            if r['pos'] > 0 and not in_trade:
                in_trade = True
                entry_price = r['mid'] # Approx
                trade_start_idx = i
                print(f"[{r['time']}] Trade Start @ {entry_price:.5f} (SL: {r['sl']:.5f})")
                continue

            # Detect Exit
            if r['pos'] == 0 and in_trade:
                in_trade = False
                duration = i - trade_start_idx
                print(f"[{r['time']}] Trade End. Duration: {duration} ticks. Probes: {len(probes)}")
                probes = []
                continue

            if in_trade:
                # Check for Crossing (Probe)
                # Define Crossing: Price moves from one side of Entry to the other
                # Logic: Compare current vs prev relative to Entry
                prev = self.data[i-1]

                curr_side = 1 if r['mid'] > entry_price else -1
                prev_side = 1 if prev['mid'] > entry_price else -1

                if curr_side != prev_side:
                    # CROSSING DETECTED
                    probes.append(r)
                    print(f"   👉 [{r['time']}] PROBE: Crossed Entry. Vel: {r['vel']:.2f}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        analyzer = SLImpactAnalyzer()
        analyzer.load_data(sys.argv[1])
        analyzer.analyze_probing()
    else:
        print("Usage: python3 analyze_sl_impact.py <csv>")
