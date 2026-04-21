import csv
import sys
import os
import glob
import statistics
from datetime import datetime, timedelta

# --- MIMIC STORYTELLER ANALYZER v2.2 (Colombo Huron Edition) ---
# Purpose: Deep Forensic Analysis of Mimic Trap Strategy (v2.08 Log Compatible)
# Features: Microstructure Analysis, Mimic vs Direct Comparison, Dynamic Schema Handling

class MimicStoryTellerV2:
    def __init__(self):
        self.data = []
        self.baseline_vel = 0.0
        self.baseline_spread = 0.0
        self.schema_type = "UNKNOWN"

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        with open(filepath, 'r') as f:
            # Use DictReader for robust column mapping
            reader = csv.DictReader(f)

            # Normalize headers (remove whitespace)
            reader.fieldnames = [name.strip() for name in reader.fieldnames]

            # Detect Schema Features
            headers = reader.fieldnames
            has_micro = "Micro_Press" in headers
            has_mimic = "MimicMode" in headers

            if has_micro and has_mimic:
                self.schema_type = "V2.08_HURON"
                print("Schema Detected: v2.08 (Huron/Research)")
            elif "DOM_Snapshot" in headers:
                self.schema_type = "V2.07_LEGACY"
                print("Schema Detected: v2.07 (Legacy)")
            else:
                print("Unknown Schema. Attempting best effort.")

            vels = []
            spreads = []

            for row in reader:
                try:
                    # Basic Parsing (Common to all versions)
                    dt_str = row['Time']
                    ms = int(row.get('TickMS', 0))
                    dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                    spread = float(row.get('Spread', 0))
                    vel = abs(float(row.get('Velocity', 0)))
                    acc = float(row.get('Acceleration', 0))

                    # P/L
                    float_pl = float(row.get('Floating_PL', 0))
                    realized_pl_tick = float(row.get('Realized_PL', 0)) # Change in realized PL this tick
                    session_pl = float(row.get('Session_PL', 0))

                    # Bid/Ask
                    bid = float(row.get('Bid', 0))
                    mid = (bid + float(row.get('Ask', 0))) / 2.0

                    # New v2.08 Fields
                    mimic_mode = int(row.get('MimicMode', 1)) # Default to 1 (True) if missing
                    micro_press = float(row.get('Micro_Press', 0))
                    target_tp = float(row.get('TargetTP', 0))

                    r = {
                        'dt': dt,
                        'time_sec': 0.0, # Calculated later
                        'spread': spread,
                        'vel': vel,
                        'acc': acc,
                        'float_pl': float_pl,
                        'realized_tick': realized_pl_tick,
                        'session_pl': session_pl,
                        'mid': mid,
                        'mimic_mode': bool(mimic_mode),
                        'micro_press': micro_press,
                        'target_tp': target_tp,
                        'phase': row.get('Phase', 'IDLE'),
                        'action': row.get('Action', '')
                    }
                    self.data.append(r)

                    vels.append(vel)
                    spreads.append(spread)

                except Exception as e:
                    # print(f"Row Parse Error: {e}")
                    continue

            if vels:
                self.baseline_vel = statistics.mean(vels)
                self.baseline_spread = statistics.mean(spreads)
                print(f"Baselines -> Velocity: {self.baseline_vel:.4f}, Spread: {self.baseline_spread:.2f}")

            # Normalize Time
            if self.data:
                start_time = self.data[0]['dt']
                for r in self.data:
                    r['time_sec'] = (r['dt'] - start_time).total_seconds()

    def analyze_narrative(self):
        print("\n=== COLOMBO HURON: FORENSIC REPORT ===\n")

        if not self.data:
            print("No data loaded.")
            return

        in_position = False
        trade_start_time = 0
        max_drawdown = 0.0

        last_phase = "IDLE"

        for i, r in enumerate(self.data):
            curr_time = r['time_sec']

            # 1. EVENT: REALIZED PROFIT (Banked)
            if abs(r['realized_tick']) > 0.001:
                print(f"[{curr_time:.1f}s] 💰 KA-CHING! Profit Banked: {r['realized_tick']:.2f}. Total Session: {r['session_pl']:.2f}")
                self.analyze_reaction(i, "Profit Take")

            # 2. EVENT: PHASE CHANGE (Trap Execution)
            if r['phase'] != last_phase:
                if r['phase'] == "TRAP_EXEC":
                    mode_str = "MIMIC (Decoys Deployed)" if r['mimic_mode'] else "DIRECT (No Decoys)"
                    print(f"[{curr_time:.1f}s] ⚡ TRAP SPRUNG! Mode: {mode_str}")

                    # Huron Analysis: What was the microstructure doing?
                    self.analyze_microstructure_context(i)

                if r['phase'] == "ARMED":
                    print(f"[{curr_time:.1f}s] 🔫 TRAP ARMED. Waiting for trigger...")

                last_phase = r['phase']

            # 3. EVENT: TARGET HIT
            if r['target_tp'] > 0 and r['float_pl'] >= r['target_tp'] and in_position:
                 print(f"[{curr_time:.1f}s] 🎯 TARGET HIT! Float: {r['float_pl']:.2f} >= Target: {r['target_tp']:.2f}")

            # 4. TRACKING: DRAWDOWN & POSITION
            if not in_position and abs(r['float_pl']) > 0.01:
                in_position = True
                trade_start_time = curr_time
                print(f"[{curr_time:.1f}s] 🟢 Position Opened. Initial Float: {r['float_pl']:.2f}")

            elif in_position and abs(r['float_pl']) < 0.001: # Closed
                in_position = False
                duration = curr_time - trade_start_time
                print(f"[{curr_time:.1f}s] 🔴 All Positions Closed. Duration: {duration:.1f}s.")
                max_drawdown = 0.0

            if in_position:
                if r['float_pl'] < max_drawdown:
                    max_drawdown = r['float_pl']
                    if max_drawdown < -5.0 and (int(max_drawdown*10) % 10 == 0):
                        print(f"[{curr_time:.1f}s] ⚠️ Drawdown Deepening: {r['float_pl']:.2f}")

        print(f"\n=== FINAL RESULT ===")
        print(f"Session Realized P/L: {self.data[-1]['session_pl']:.2f}")

    def analyze_microstructure_context(self, index):
        # Look back 5 seconds
        start_idx = max(0, index - 50) # Approx 50 ticks?

        # Calculate recent average pressure
        recent_data = self.data[start_idx:index+1]
        if not recent_data: return

        avg_press = statistics.mean([x['micro_press'] for x in recent_data])
        avg_vel = statistics.mean([x['vel'] for x in recent_data])

        press_str = ""
        if avg_press > 20: press_str = "Strong BUY Pressure (Green)"
        elif avg_press < -20: press_str = "Strong SELL Pressure (Red)"
        else: press_str = "Neutral/Mixed Pressure"

        print(f"    🔎 HURON INSIGHT: Before Trigger...")
        print(f"       Microstructure: {press_str} (Avg: {avg_press:.1f})")

        # Stall Detection
        if avg_vel > self.baseline_vel * 2.0 and abs(avg_press) < 10:
             print(f"       ⚠️ ANOMALY: High Velocity but Low Pressure! (Absorption/Churning Detected)")

    def analyze_reaction(self, index, event_type):
        if index + 10 >= len(self.data): return
        future = self.data[index:index+10]
        start_p = self.data[index]['mid']
        end_p = future[-1]['mid']
        drift = (end_p - start_p) * 100000

        print(f"    -> Immediate Market Response (Next ~10 ticks): Drift {drift:.1f} pts")

if __name__ == "__main__":
    # Find latest csv
    list_of_files = glob.glob('Mimic_Research_*.csv')
    # Also check analysis_input if locally
    if not list_of_files:
        list_of_files = glob.glob('analysis_input/Mimic_Research_*.csv')

    if list_of_files:
        latest_file = max(list_of_files, key=os.path.getctime)
        story = MimicStoryTellerV2()
        story.load_data(latest_file)
        story.analyze_narrative()
    else:
        print("No log files found. (Mimic_Research_*.csv)")
