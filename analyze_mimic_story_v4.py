import csv
import sys
import os
import glob
import statistics
from datetime import datetime, timedelta

class MimicStoryTellerV4:
    def __init__(self):
        self.data = []
        self.baseline_vel = 0.0
        self.micro_swings = []
        self.current_r1 = 0.0
        self.current_s1 = 0.0

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        try:
            with open(filepath, 'r') as f:
                # Use standard csv reader for robustness against field count mismatches
                reader = csv.reader(f)

                # First row might be header
                header = next(reader, None)
                if not header: return

                # Detect schema based on header contents roughly
                # v2.07: ..., Floating_PL, Realized_PL, Action, PosCount, ...

                vels = []

                for row in reader:
                    if not row: continue

                    try:
                        # 1. Anchor Point: Find "MimicResearch" (Action)
                        action_idx = -1
                        # Search from the end backwards to avoid noise in DOM
                        # Or search for the string "MimicResearch" or similar
                        for i in range(len(row)):
                            if "Mimic" in row[i]:
                                action_idx = i
                                break

                        # Fallback: if not found, use fixed index from v2.07 schema (18)
                        if action_idx == -1 and len(row) > 18:
                            action_idx = 18

                        if action_idx == -1: continue

                        # 2. Extract Data relative to Action
                        # Schema v2.07:
                        # 0:Time, 1:TickMS, 2:Phase, 3:Bid, 4:Ask, 5:Spread, 6:Vel, 7:Acc
                        # ...
                        # Action-2: Floating_PL
                        # Action-1: Realized_PL
                        # Action:   Action (MimicResearch)
                        # Action+1: PosCount

                        dt_str = row[0].strip()
                        ms_str = row[1].strip()
                        if not ms_str.isdigit(): ms = 0
                        else: ms = int(float(ms_str))

                        dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                        bid = float(row[3])
                        ask = float(row[4])
                        mid = (bid + ask) / 2.0
                        vel = abs(float(row[6]))

                        realized_tick = float(row[action_idx-1])
                        float_pl = float(row[action_idx-2])

                        # PosCount is tricky. In v2.07 it is Action+1.
                        # In v2.08 it is Action+1.
                        # In the problematic file, it seems PosCount might be missing or misplaced?
                        # Let's try to grab it.
                        pos_count = 0
                        if action_idx + 1 < len(row):
                            try:
                                pos_count = int(float(row[action_idx+1]))
                            except: pass

                        r = {
                            'dt': dt,
                            'time_sec': 0.0,
                            'mid': mid,
                            'vel': vel,
                            'float_pl': float_pl,
                            'realized_tick': realized_tick,
                            'pos_count': pos_count
                        }
                        self.data.append(r)
                        vels.append(vel)

                    except Exception as e:
                        # print(f"Row Error: {e}") # Debug only
                        continue

                if self.data:
                    start = self.data[0]['dt']
                    for r in self.data:
                        r['time_sec'] = (r['dt'] - start).total_seconds()

                if vels: self.baseline_vel = statistics.mean(vels)
                print(f"Loaded {len(self.data)} rows. Baseline Vel: {self.baseline_vel:.4f}")

        except Exception as e:
            print(f"File Error: {e}")

    def calculate_tick_zigzag(self, deviation_points=30):
        # 30 points = 3 pips
        point = 0.00001
        dev = deviation_points * point

        if not self.data: return

        start_price = self.data[0]['mid']
        current_swing = {'high': start_price, 'low': start_price, 'dir': 0, 'start_idx': 0}

        for i, r in enumerate(self.data):
            price = r['mid']

            if current_swing['dir'] == 0:
                if price > start_price + dev:
                    current_swing['dir'] = 1
                    current_swing['high'] = price
                    current_swing['low_idx'] = 0
                elif price < start_price - dev:
                    current_swing['dir'] = -1
                    current_swing['low'] = price
                    current_swing['high_idx'] = 0
                continue

            if current_swing['dir'] == 1:
                if price > current_swing['high']:
                    current_swing['high'] = price
                    current_swing['high_idx'] = i
                elif price < current_swing['high'] - dev:
                    self.micro_swings.append({'type': 'HIGH', 'price': current_swing['high'], 'idx': current_swing['high_idx']})
                    current_swing['dir'] = -1
                    current_swing['low'] = price
                    current_swing['low_idx'] = i

            elif current_swing['dir'] == -1:
                if price < current_swing['low']:
                    current_swing['low'] = price
                    current_swing['low_idx'] = i
                elif price > current_swing['low'] + dev:
                    self.micro_swings.append({'type': 'LOW', 'price': current_swing['low'], 'idx': current_swing['low_idx']})
                    current_swing['dir'] = 1
                    current_swing['high'] = price
                    current_swing['high_idx'] = i

    def get_context_levels(self, current_idx):
        last_high = 0.0
        last_low = 0.0
        valid_swings = [s for s in self.micro_swings if s['idx'] < current_idx]
        if not valid_swings: return 0, 0

        # Simple R1/S1: Last Peak/Valley
        # More complex: Nearest Peak > Price

        current_price = self.data[current_idx]['mid']

        # Find R1
        for s in reversed(valid_swings):
            if s['type'] == 'HIGH':
                # Valid R1 must be above current price? Or just the last structure?
                # Let's say R1 is the LAST high established.
                last_high = s['price']
                break

        # Find S1
        for s in reversed(valid_swings):
            if s['type'] == 'LOW':
                last_low = s['price']
                break

        return last_high, last_low

    def analyze_narrative(self):
        print("\n=== COLOMBO V4: DYNAMIC CONTEXT REPORT ===\n")
        if not self.data:
            print("No data.")
            return

        self.calculate_tick_zigzag(deviation_points=30)
        print(f"Generated {len(self.micro_swings)} Micro-Pivot points.")

        last_pos_count = 0
        decoy_profit_sum = 0.0
        decoy_count = 0
        in_channel_count = 0
        total_ticks = len(self.data)

        session_start_pl = 0.0 # Track manually

        for i, r in enumerate(self.data):
            r1, s1 = self.get_context_levels(i)
            mid = r['mid']

            # Check if price is within the last defined range
            # Note: R1 might be lower than S1 if we just follow "Last High / Last Low" in a downtrend
            upper = max(r1, s1)
            lower = min(r1, s1)

            is_in_channel = (mid <= upper and mid >= lower) if (upper > 0 and lower > 0) else False
            if is_in_channel: in_channel_count += 1

            # Profit Logic (Legacy)
            if r['pos_count'] < last_pos_count:
                diff = last_pos_count - r['pos_count']
                if r['realized_tick'] > 0.01:
                    print(f"[{r['time_sec']:.1f}s] 💰 EXIT: +{r['realized_tick']:.2f}. (Positions: {diff})")
                    print(f"       Context: Price {mid:.5f} vs Range [{lower:.5f} - {upper:.5f}]")
                    if is_in_channel: print("       ✅ Trade closed WITHIN Channel.")
                    else: print("       ⚠️ Trade closed OUTSIDE Channel (Breakout?)")

                    if r['realized_tick'] < 30.0: # Threshold for Decoy
                        decoy_profit_sum += r['realized_tick']
                        decoy_count += 1

                    self.check_momentum_stall(i)

            last_pos_count = r['pos_count']

        print(f"\n=== SUMMARY ===")
        print(f"Est. Decoy Profits: {decoy_profit_sum:.2f} (Count: {decoy_count})")
        valid_ticks = total_ticks if total_ticks > 0 else 1
        print(f"Channel Adherence: {in_channel_count/valid_ticks*100:.1f}%")

    def check_momentum_stall(self, index):
        if index + 20 >= len(self.data): return
        start = max(0, index-10)
        vel_before = statistics.mean([x['vel'] for x in self.data[start:index+1]])
        vel_after = statistics.mean([x['vel'] for x in self.data[index:index+20]])

        print(f"    🔎 MOMENTUM: {vel_before:.2f} -> {vel_after:.2f}")
        if vel_after < vel_before * 0.6:
            print("    🛑 CONFIRMED: Momentum collapsed after exit! (Broker lost interest)")
        elif vel_after > vel_before * 1.5:
            print("    🚀 WARNING: Price accelerated! (Others jumped in?)")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        target = sys.argv[1]
        story = MimicStoryTellerV4()
        story.load_data(target)
        story.analyze_narrative()
    else:
        print("Usage: python3 analyze_mimic_story_v4.py <csv_file>")
