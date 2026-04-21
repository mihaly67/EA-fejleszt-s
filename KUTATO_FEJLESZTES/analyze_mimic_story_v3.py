import csv
import sys
import os
import glob
import statistics
from datetime import datetime, timedelta

# --- MIMIC STORYTELLER ANALYZER v3.0 (Colombo Huron - Pivot Edition) ---
# Purpose: Deep Forensic Analysis of Mimic Trap Strategy (v2.09 Log Compatible)
# Features: Pivot Context, Event Tag Parsing, Decoy Logic, Momentum Stall Detection

class MimicStoryTellerV3:
    def __init__(self):
        self.data = []
        self.baseline_vel = 0.0
        self.baseline_spread = 0.0
        self.schema_type = "UNKNOWN"

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        try:
            with open(filepath, 'r') as f:
                reader = csv.DictReader(f)

                # Normalize headers
                if reader.fieldnames:
                    reader.fieldnames = [name.strip() for name in reader.fieldnames]
                else:
                    print("Error: Empty CSV or no headers.")
                    return

                headers = reader.fieldnames

                # Schema Detection
                has_event = "LastEvent" in headers
                has_pivot = "Pivot_PP" in headers

                if has_event and has_pivot:
                    self.schema_type = "V2.09_HURON_PIVOT"
                    print("Schema Detected: v2.09 (Huron Pivot)")
                elif "Micro_Press" in headers:
                    self.schema_type = "V2.08_HURON"
                    print("Schema Detected: v2.08 (Huron)")
                else:
                    self.schema_type = "V2.07_LEGACY"
                    print("Schema Detected: v2.07 (Legacy)")

                vels = []

                for row in reader:
                    try:
                        dt_str = row.get('Time', '').strip()
                        if not dt_str: continue # Skip empty lines

                        ms = int(float(row.get('TickMS', 0)))
                        dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                        spread = float(row.get('Spread', 0))
                        vel = abs(float(row.get('Velocity', 0)))

                        float_pl = float(row.get('Floating_PL', 0))
                        realized_pl_tick = float(row.get('Realized_PL', 0)) # Tick P/L change
                        session_pl = float(row.get('Session_PL', 0))

                        bid = float(row.get('Bid', 0))
                        mid = (bid + float(row.get('Ask', 0))) / 2.0

                        # v2.09 Fields
                        pivot_pp = float(row.get('Pivot_PP', 0))
                        pivot_r1 = float(row.get('Pivot_R1', 0))
                        pivot_s1 = float(row.get('Pivot_S1', 0))
                        last_event = row.get('LastEvent', '')

                        r = {
                            'dt': dt,
                            'time_sec': 0.0,
                            'spread': spread,
                            'vel': vel,
                            'float_pl': float_pl,
                            'realized_tick': realized_pl_tick,
                            'session_pl': session_pl,
                            'mid': mid,
                            'pivot_pp': pivot_pp,
                            'last_event': last_event,
                            'phase': row.get('Phase', 'IDLE'),
                            'pos_count': int(row.get('PosCount', 0))
                        }
                        self.data.append(r)
                        vels.append(vel)

                    except Exception as e:
                        # print(f"Parse Error: {e}")
                        continue

                if vels:
                    self.baseline_vel = statistics.mean(vels)
                    print(f"Baseline Velocity: {self.baseline_vel:.4f}")

                if self.data:
                    start_time = self.data[0]['dt']
                    for r in self.data:
                        r['time_sec'] = (r['dt'] - start_time).total_seconds()

        except Exception as e:
            print(f"Critical File Error: {e}")

    def analyze_narrative(self):
        print("\n=== COLOMBO V3.0: PIVOT & MOMENTUM FORENSICS ===\n")

        if not self.data:
            print("No data loaded.")
            return

        last_pos_count = 0
        last_phase = "IDLE"
        idle_start_time = 0
        is_idling = False

        trade_start_vel = 0.0

        for i, r in enumerate(self.data):
            curr_time = r['time_sec']

            # --- IDLE FILTERING ---
            # If IDLE and nothing happening, don't spam. Group it.
            if r['phase'] == "IDLE" and r['last_event'] == "" and abs(r['realized_tick']) < 0.01:
                if not is_idling:
                    is_idling = True
                    idle_start_time = curr_time
                continue # Skip loop
            else:
                if is_idling:
                    duration = curr_time - idle_start_time
                    if duration > 10.0:
                        print(f"   ... (System Idle for {duration:.1f}s) ...")
                    is_idling = False

            # --- 1. EVENT TAGS (v2.09) ---
            if r['last_event']:
                events = r['last_event'].split(';')
                for e in events:
                    if not e: continue
                    print(f"[{curr_time:.1f}s] ⚡ EVENT: {e}")

                    if "CLOSE_ALL" in e:
                        self.check_momentum_stall(i)

            # --- 2. DECOY / PROFIT DETECTION (Legacy & Modern) ---
            # Logic: PosCount drop + Positive Realized PL = Profit Take
            if r['pos_count'] < last_pos_count:
                diff = last_pos_count - r['pos_count']
                if r['realized_tick'] > 0.01:
                    print(f"[{curr_time:.1f}s] 💰 PROFIT TAKE! {diff} position(s) closed. Banked: {r['realized_tick']:.2f}")
                    # Was it a decoy? (Heuristic for legacy)
                    if r['realized_tick'] < 15.0 and self.schema_type != "V2.09_HURON_PIVOT":
                         print("       (Likely Decoy Closure based on size)")
                elif r['realized_tick'] < -0.01:
                    print(f"[{curr_time:.1f}s] ❌ LOSS TAKEN. {diff} position(s) closed. Loss: {r['realized_tick']:.2f}")

            # --- 3. PIVOT CONTEXT ---
            if r['pivot_pp'] > 0 and (i % 100 == 0 or r['last_event']): # Check periodically or on event
                dist_pp = abs(r['mid'] - r['pivot_pp'])
                dist_r1 = abs(r['mid'] - r['pivot_r1'])
                dist_s1 = abs(r['mid'] - r['pivot_s1'])

                # If close to a level (e.g. 50 points = 0.00050)
                limit = 0.00050
                level_str = ""
                if dist_pp < limit: level_str = "Daily Pivot"
                elif dist_r1 < limit: level_str = "R1 Resistance"
                elif dist_s1 < limit: level_str = "S1 Support"

                if level_str:
                    print(f"       📍 CONTEXT: Price is fighting at {level_str}!")

            # --- 4. PHASE CHANGE ---
            if r['phase'] != last_phase:
                print(f"[{curr_time:.1f}s] ⚙️ STATUS CHANGE: {last_phase} -> {r['phase']}")
                if r['phase'] == "ACTIVE_HOLD":
                    trade_start_vel = r['vel']

            # --- 5. DRAWDOWN ALERT ---
            if r['float_pl'] < -50.0 and (int(r['float_pl']) % 50 == 0):
                 # Simple de-dupe logic needed, but okay for now
                 pass

            last_pos_count = r['pos_count']
            last_phase = r['phase']

        print(f"\n=== FINAL SESSION P/L: {self.data[-1]['session_pl']:.2f} ===")

    def check_momentum_stall(self, index):
        # Look 5 seconds AFTER the event
        if index + 20 >= len(self.data): return

        # Velocity BEFORE (avg of prev 10)
        start = max(0, index-10)
        vel_before = statistics.mean([x['vel'] for x in self.data[start:index+1]])

        # Velocity AFTER (avg of next 20)
        vel_after = statistics.mean([x['vel'] for x in self.data[index:index+20]])

        print(f"       🔎 MOMENTUM CHECK: Vel Before: {vel_before:.2f} -> Vel After: {vel_after:.2f}")

        if vel_after < vel_before * 0.7:
            print("       🛑 CONFIRMED: Momentum Stalled/Dropped after exit!")
        elif vel_after > vel_before * 1.3:
            print("       🚀 WARNING: Price accelerated after exit! (Left money on table?)")
        else:
            print("       ➡️ Momentum Unchanged.")

if __name__ == "__main__":
    # Find latest csv or merged
    if len(sys.argv) > 1:
        target = sys.argv[1]
    else:
        # Default to merged if exists
        target = 'analysis_input/new_session/merged_session.csv'
        if not os.path.exists(target):
             list_of_files = glob.glob('Mimic_Research_*.csv')
             if list_of_files:
                 target = max(list_of_files, key=os.path.getctime)
             else:
                 target = None

    if target and os.path.exists(target):
        story = MimicStoryTellerV3()
        story.load_data(target)
        story.analyze_narrative()
    else:
        print("No input file found.")
