import csv
import sys
import statistics
import os

class ThiefKeyHunter:
    def __init__(self):
        self.data = []

    def load_data(self, filepath):
        print(f"Reading: {os.path.basename(filepath)}")
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if not header: return

            try:
                idx_bid = header.index("Bid")
                idx_ask = header.index("Ask")
                idx_vel = header.index("Velocity")
                idx_pos = header.index("PosCount")
            except:
                idx_bid=3; idx_ask=4; idx_vel=6; idx_pos=19 # Fallback

            idx_press = -1
            if "Ext_VA_Vel" in header: idx_press = header.index("Ext_VA_Vel")

            for row in reader:
                if not row: continue
                try:
                    bid = float(row[idx_bid])
                    ask = float(row[idx_ask])
                    mid = (bid+ask)/2
                    vel = abs(float(row[idx_vel]))
                    pos = int(float(row[idx_pos]))

                    press = 0.0
                    if idx_press != -1 and idx_press < len(row):
                         try: press = float(row[idx_press])
                         except: pass

                    self.data.append({
                        'mid': mid,
                        'vel': vel,
                        'press': press,
                        'pos': pos,
                        'time': row[0].split(' ')[1]
                    })
                except: continue

    def analyze_signatures(self, is_gold=False):
        print(f"\n--- HUNTING FOR 'THIEF KEY' SIGNATURES ({'GOLD' if is_gold else 'FOREX'}) ---")

        window = 20
        BAIT_VEL = 20.0 if is_gold else 2.0
        BAIT_DISP = 0.5 if is_gold else 0.00005

        bait_events = 0
        spike_events = 0
        probe_events = 0

        # State for Probing
        in_trade = False
        entry_price = 0.0

        for i in range(window, len(self.data)):
            chunk = self.data[i-window:i]
            curr = self.data[i]

            # 1. BAIT INDEX
            start_price = chunk[0]['mid']
            end_price = chunk[-1]['mid']
            disp = abs(end_price - start_price)
            avg_vel = statistics.mean([x['vel'] for x in chunk])

            if avg_vel > BAIT_VEL and disp < BAIT_DISP:
                max_v = max([x['vel'] for x in chunk])
                if max_v > (avg_vel * 1.5):
                    if bait_events < 5:
                        print(f"[{chunk[-1]['time']}] 🪤 BAIT DETECTED: Vel {avg_vel:.1f} | Disp {disp:.5f} | 'Nyüzsgés'")
                    bait_events += 1

            # 2. OVER-REACH (Spike)
            if curr['press'] > 99.0 and curr['vel'] > (avg_vel * 3.0):
                 if spike_events < 5:
                     print(f"[{curr['time']}] ⚡ SPIKE DETECTED: Vel {curr['vel']:.1f} (3x Avg) | Pressure {curr['press']} | 'Túlszúrás'")
                 spike_events += 1

            # 3. PROBING (Safety Zone)
            if curr['pos'] > 0:
                if not in_trade:
                    in_trade = True
                    entry_price = curr['mid']

                # Check crossing
                prev = self.data[i-1]
                if (curr['mid'] - entry_price) * (prev['mid'] - entry_price) < 0:
                    # Crossed
                    probe_events += 1
                    if probe_events % 10 == 0:
                        print(f"[{curr['time']}] 🤏 PROBE DETECTED: {probe_events}th Crossing. Vel {curr['vel']:.2f} | 'Letapogatás'")
            else:
                if in_trade:
                    print(f"[{curr['time']}] Trade Closed. Total Probes: {probe_events}")
                in_trade = False
                probe_events = 0

        print(f"\nSUMMARY:")
        print(f"Bait Patterns: {bait_events}")
        print(f"Spike Patterns: {spike_events}")
        # Probes are trade-specific, printed inline

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
        hunter = ThiefKeyHunter()
        hunter.load_data(target)
        is_gold = "GOLD" in target
        hunter.analyze_signatures(is_gold)
    else:
        print("Usage: python3 simulate_thief_key.py <csv>")
