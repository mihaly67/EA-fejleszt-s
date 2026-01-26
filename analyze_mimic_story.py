import csv
import sys
import os
import glob
import statistics
from datetime import datetime, timedelta

# --- MIMIC STORYTELLER ANALYZER v2 (Colombo Edition) ---
# Purpose: Accurate narrative reconstruction focusing on Price Action vs Velocity Context.

class MimicStoryTeller:
    def __init__(self):
        self.data = []
        self.events = []
        self.baseline_vel = 0.0
        self.baseline_spread = 0.0

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        with open(filepath, 'r') as f:
            reader = csv.reader(f)
            header = next(reader, None)

            vels = []
            spreads = []

            for row in reader:
                if not row or len(row) < 19: continue
                try:
                    dt_str = row[0]
                    ms = int(row[1])
                    dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                    spread = float(row[5])
                    vel = abs(float(row[6]))
                    acc = float(row[7])
                    float_pl = float(row[16])
                    realized_pl_tick = float(row[17])

                    r = {
                        'dt': dt,
                        'spread': spread,
                        'vel': vel,
                        'acc': acc,
                        'float_pl': float_pl,
                        'realized': realized_pl_tick,
                        'bid': float(row[3]),
                        'ask': float(row[4]),
                        'mid': (float(row[3]) + float(row[4]))/2.0
                    }
                    self.data.append(r)

                    vels.append(vel)
                    spreads.append(spread)

                except: continue

            if vels:
                self.baseline_vel = statistics.mean(vels)
                self.baseline_spread = statistics.mean(spreads)
                print(f"Baselines -> Velocity: {self.baseline_vel:.4f}, Spread: {self.baseline_spread:.2f}")

    def analyze_narrative(self):
        print("\n=== THE TRADING SESSION NARRATIVE ===\n")

        cumulative_profit = 0.0
        in_position = False
        last_float = 0.0
        start_time = self.data[0]['dt']

        trade_start_time = None
        max_drawdown = 0.0

        # Debounce for reporting market states
        last_market_report_time = -999.0

        for i, r in enumerate(self.data):
            curr_time = (r['dt'] - start_time).total_seconds()

            # 1. EVENT: REALIZED PROFIT
            if r['realized'] != 0:
                cumulative_profit += r['realized']
                print(f"[{curr_time:.1f}s] ACTION: Profit Taking! Amount: {r['realized']:.2f}. Total Banked: {cumulative_profit:.2f}")
                self.analyze_reaction(i, "Profit Take")

            # 2. EVENT: MARKET STATE ANALYSIS (Every 10s or upon Spike)
            is_spike = r['vel'] > (self.baseline_vel * 3.0)
            time_since_last = curr_time - last_market_report_time

            if is_spike or (time_since_last > 30.0): # Report periodically or on spikes
                last_market_report_time = curr_time
                self.analyze_market_context(i, curr_time, is_spike)

            # 3. TRACKING: DRAWDOWN
            if r['float_pl'] < max_drawdown:
                max_drawdown = r['float_pl']
                if max_drawdown < -1.0 and (int(max_drawdown*10) % 5 == 0):
                     print(f"[{curr_time:.1f}s] STATUS: New Depth Reached. Floating P/L: {r['float_pl']:.2f}")

            # 4. STATE CHANGE: ENTER/EXIT
            if not in_position and abs(r['float_pl']) > 0.01:
                in_position = True
                trade_start_time = curr_time
                print(f"[{curr_time:.1f}s] ACTION: Positions Opened (Entry). Initial Float: {r['float_pl']:.2f}")

            elif in_position and r['float_pl'] == 0.0 and abs(last_float) > 0.01:
                in_position = False
                duration = curr_time - trade_start_time
                print(f"[{curr_time:.1f}s] ACTION: All Positions Closed. Duration: {duration:.1f}s.")
                max_drawdown = 0.0

            last_float = r['float_pl']

        print(f"\n=== FINAL RESULT ===")
        print(f"Total Banked Profit: {cumulative_profit:.2f}")

    def analyze_market_context(self, index, time, is_spike):
        # Look ahead 10-20 ticks for drift
        if index + 20 >= len(self.data): return

        future_data = self.data[index:index+20]
        avg_vel = statistics.mean([x['vel'] for x in future_data])

        start_price = self.data[index]['mid']
        end_price = future_data[-1]['mid']
        drift = (end_price - start_price) * 100000
        abs_drift = abs(drift)

        # Classification Logic
        state = "Normal"

        if avg_vel > self.baseline_vel * 2.5:
            # High Velocity
            if abs_drift > 5.0:
                state = "Aggressive Breakout / Move"
            else:
                state = "Market Stalled / Churning (High Noise, No Move)"
        elif avg_vel < self.baseline_vel * 0.5:
            state = "Calm / Inactive"
        else:
            if abs_drift > 5.0:
                state = "Steady Trend (Low Vol, High Move)"
            else:
                state = "Ranging / Vánszorgás"

        # Only print if it's interesting or requested
        prefix = "MARKET"
        if is_spike: prefix = "SPIKE"

        print(f"[{time:.1f}s] {prefix}: {state}. (Vel: {avg_vel:.2f}, Drift: {drift:.1f} pts)")

    def analyze_reaction(self, index, event_type):
        # Immediate reaction to user action
        if index + 10 >= len(self.data): return
        future = self.data[index:index+10]
        start_p = self.data[index]['mid']
        end_p = future[-1]['mid']
        drift = (end_p - start_p) * 100000

        print(f"    -> Immediate Market Response (Next ~2s): Drift {drift:.1f} pts")

if __name__ == "__main__":
    files = glob.glob("analysis_input/new_session/Mimic_Research_*.csv")
    if files:
        story = MimicStoryTeller()
        story.load_data(files[0])
        story.analyze_narrative()
    else:
        print("No log files found.")
