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
        self.is_v209 = False

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        try:
            with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
                reader = csv.reader(f)
                header = next(reader, None)
                if not header: return

                # Detect Version
                self.is_v209 = "Session_PL" in header
                print(f"Version Detection: {'v2.09 (Modern)' if self.is_v209 else 'Legacy'}")

                # Dynamic Column Mapping
                try:
                    idx_bid = header.index("Bid")
                    idx_ask = header.index("Ask")
                    idx_vel = header.index("Velocity")
                except ValueError:
                    idx_bid = 3
                    idx_ask = 4
                    idx_vel = 6

                # Pressure Proxy
                idx_press = -1
                if "Ext_VA_Vel" in header: idx_press = header.index("Ext_VA_Vel")
                elif "Micro_Press" in header: idx_press = header.index("Micro_Press")

                vels = []

                for row in reader:
                    if not row: continue

                    try:
                        # 1. Locate Anchor (Action)
                        action_idx = -1
                        for i in range(len(row)):
                            if "Mimic" in row[i]:
                                action_idx = i
                                break

                        # Fallback
                        if action_idx == -1:
                            if self.is_v209 and len(row) > 26: action_idx = 26
                            elif not self.is_v209 and len(row) >= 19: action_idx = 18

                        if action_idx == -1: continue

                        # 2. Extract Standard Data
                        dt_str = row[0].strip()
                        ms_str = row[1].strip()
                        if not ms_str: ms = 0
                        else: ms = int(float(ms_str)) if ms_str.replace('.','',1).isdigit() else 0

                        dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                        bid = float(row[idx_bid])
                        ask = float(row[idx_ask])
                        mid = (bid + ask) / 2.0
                        vel = abs(float(row[idx_vel]))

                        # 3. Extract P/L based on Version
                        float_pl = 0.0
                        realized_tick = 0.0
                        session_pl = 0.0 # NEW
                        last_event = ""

                        if self.is_v209:
                            if action_idx >= 3:
                                try:
                                    float_pl = float(row[action_idx-3])
                                    realized_tick = float(row[action_idx-2])
                                    session_pl = float(row[action_idx-1]) # Session PL
                                except: pass

                            if action_idx + 4 < len(row):
                                last_event = row[action_idx+4]

                        else:
                            if action_idx >= 2:
                                try:
                                    float_pl = float(row[action_idx-2])
                                    realized_tick = float(row[action_idx-1])
                                except: pass

                        pos_count = 0
                        if action_idx + 1 < len(row):
                            try:
                                pos_count = int(float(row[action_idx+1]))
                            except: pass

                        # 4. Extract DOM Snapshot
                        dom_data = None
                        dom_start_idx = -1
                        if self.is_v209:
                            dom_start_idx = 31 # Fixed for v2.09
                        else:
                             dom_start_idx = len(row) - 12

                        if dom_start_idx > 0 and dom_start_idx < len(row):
                             dom_slice = row[dom_start_idx:]
                             if len(dom_slice) >= 12:
                                 try:
                                     dom_data = {
                                         'best_bid': float(dom_slice[0]),
                                         'best_ask': float(dom_slice[1]),
                                         'bid_vols': [int(float(x)) for x in dom_slice[2:7]],
                                         'ask_vols': [int(float(x)) for x in dom_slice[7:12]]
                                     }
                                 except ValueError: pass

                        # 5. Pressure Proxy
                        pressure = 0.0
                        if idx_press != -1 and idx_press < len(row):
                            try: pressure = float(row[idx_press])
                            except: pass

                        r = {
                            'dt': dt,
                            'time_sec': 0.0,
                            'mid': mid,
                            'vel': vel,
                            'float_pl': float_pl,
                            'realized_tick': realized_tick,
                            'session_pl': session_pl,
                            'pos_count': pos_count,
                            'dom': dom_data,
                            'pressure': pressure,
                            'last_event': last_event
                        }
                        self.data.append(r)
                        vels.append(vel)

                    except Exception as e:
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
        if not self.data: return
        start_price = self.data[0]['mid']
        if start_price > 500: point = 0.01
        else: point = 0.00001
        dev = deviation_points * point
        current_swing = {'high': start_price, 'low': start_price, 'dir': 0, 'start_idx': 0, 'high_idx': 0, 'low_idx': 0}

        for i, r in enumerate(self.data):
            price = r['mid']
            if current_swing['dir'] == 0:
                if price > start_price + dev:
                    current_swing['dir'] = 1
                    current_swing['high'] = price
                    current_swing['high_idx'] = i
                    current_swing['low_idx'] = 0
                elif price < start_price - dev:
                    current_swing['dir'] = -1
                    current_swing['low'] = price
                    current_swing['low_idx'] = i
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
        for s in reversed(valid_swings):
            if s['type'] == 'HIGH':
                last_high = s['price']
                break
        for s in reversed(valid_swings):
            if s['type'] == 'LOW':
                last_low = s['price']
                break
        return last_high, last_low

    def microscope_endgame_analysis(self, exit_idx):
        print(f"\n   ☠️  MICROSCOPE: THE ENDGAME (5 Lot Check) @ {self.data[exit_idx]['time_sec']:.1f}s")
        end_time = self.data[exit_idx]['time_sec']
        pre_exit_data = [x for x in self.data if x['time_sec'] >= end_time - 30 and x['time_sec'] < end_time]

        if not pre_exit_data: return

        # 1. THE PAUSE
        last_10s = [x for x in pre_exit_data if x['time_sec'] >= end_time - 10]
        if last_10s:
            min_vel = min([x['vel'] for x in last_10s])
            min_vel_idx = next(i for i, x in enumerate(last_10s) if x['vel'] == min_vel)
            pause_time = last_10s[min_vel_idx]['time_sec']
            time_to_death = end_time - pause_time

            print(f"       ⏸️  THE PAUSE (Megtorpanás):")
            print(f"           Detected at: {pause_time:.1f}s (T-{time_to_death:.1f}s before exit)")
            print(f"           Velocity Drop: to {min_vel:.2f} (Baseline {self.baseline_vel:.2f})")

            # 2. THE CRASH
            price_at_pause = last_10s[min_vel_idx]['mid']
            price_at_exit = self.data[exit_idx]['mid']
            drop = price_at_exit - price_at_pause

            drop_pts = drop / 0.01
            speed = drop_pts / max(0.01, time_to_death)

            print(f"       📉 THE CRASH (Drawdown):")
            print(f"           Price: {price_at_pause:.2f} -> {price_at_exit:.2f}")
            print(f"           Drop: {drop_pts:.1f} points in {time_to_death:.1f}s")
            print(f"           Crash Speed: {abs(speed):.1f} pts/sec")

            if abs(speed) > 10.0:
                 print("           ⚠️  VERDICT: 'FLASH CRASH' -> Algo pulled the rug immediately.")
            elif time_to_death < 2.0:
                 print("           ⚠️  VERDICT: 'INSTANT KILL' -> Pause was a bait.")

    def microscope_analysis(self, entry_idx, entry_price):
        print(f"\n   🔬 MICROSCOPE: Deep Dive on Entry @ {entry_price:.5f}")
        entry_time = self.data[entry_idx]['time_sec']
        post_data = [x for x in self.data if x['time_sec'] >= entry_time and x['time_sec'] <= entry_time + 5]

        if not post_data:
            print("       (No data for immediate reaction)")
        else:
            v_start = post_data[0]['vel']
            v_peak = max([x['vel'] for x in post_data])
            spread_start = (post_data[0]['dom']['best_ask'] - post_data[0]['dom']['best_bid']) if post_data[0]['dom'] else 0
            spread_peak = max([(x['dom']['best_ask'] - x['dom']['best_bid']) for x in post_data if x['dom']])

            print(f"       ⚡ THE CONTACT (0-5s):")
            print(f"           Velocity: {v_start:.2f} -> Peak {v_peak:.2f}")
            print(f"           Spread: {spread_start:.5f} -> Peak {spread_peak:.5f}")

            if len(post_data) < 5:
                print("           ⚠️  DATA GAP: Log stopped? (Freeze detected)")

        crossings = []
        hover_ticks = 0
        total_ticks = 0
        point = 0.01 if entry_price > 500 else 0.00001
        zone = 10 * point

        for i in range(entry_idx, len(self.data)):
            r = self.data[i]
            if r['pos_count'] == 0: break

            total_ticks += 1
            dist = abs(r['mid'] - entry_price)
            if dist <= zone: hover_ticks += 1

            drift = r['mid'] - entry_price
            prev_drift = self.data[i-1]['mid'] - entry_price if i > 0 else drift
            if (drift > 0 and prev_drift < 0) or (drift < 0 and prev_drift > 0):
                crossings.append((r['time_sec'], r['vel']))

        print(f"       🧪 THE TEST (Zero Gravity):")
        print(f"           Crossings of Entry Price: {len(crossings)}")
        if crossings:
             print(f"           First Crossing: +{crossings[0][0]-entry_time:.1f}s")

        hover_pct = (hover_ticks / max(1, total_ticks)) * 100
        print(f"           Hover Time (within 10 pts): {hover_ticks} ticks ({hover_pct:.1f}%)")

        if hover_pct > 60:
            print("           ⚠️  VERDICT: 'TOPORGÁS' (Shuffling) -> Algo is confused/calculating.")
        elif len(crossings) > 3:
            print("           ⚠️  VERDICT: 'WHIPSAW' (Rángatás) -> Algo is fighting for the level.")
        else:
            print("           ℹ️  VERDICT: Clean Breakout/Breakdown.")

    def check_dom_spoofing(self):
        pass

    def analyze_narrative(self):
        print("\n=== COLOMBO V4: DYNAMIC CONTEXT REPORT ===\n")
        if not self.data: return

        self.calculate_tick_zigzag(deviation_points=30)

        last_pos_count = 0
        trade_start_session_pl = 0.0

        print(f"\n--- 🕵️ COLOMBO'S TIMELINE ---")

        for i, r in enumerate(self.data):

            # ENTER TRADE
            if r['pos_count'] > last_pos_count and last_pos_count == 0:
                print(f"[{r['time_sec']:.1f}s] 🚪 ENTRY DETECTED (Positions: {r['pos_count']})")
                trade_start_session_pl = r['session_pl'] # Capture start PL
                self.analyze_bait(i)
                self.microscope_analysis(i, r['mid'])

            # EXIT TRADE
            if r['pos_count'] < last_pos_count:

                # Check Profit using Lookahead for v2.09
                if self.is_v209:
                    # Look ahead up to 20 ticks to see if Session_PL jumps
                    current_pl = r['session_pl']
                    final_pl = current_pl

                    for k in range(1, 21):
                        if i + k < len(self.data):
                            next_pl = self.data[i+k]['session_pl']
                            if abs(next_pl - current_pl) > 0.01:
                                final_pl = next_pl
                                # If we found a jump, use it as the realized result
                                break

                    pl_delta = final_pl - trade_start_session_pl
                    pl = pl_delta
                else:
                    pl = r['realized_tick']

                event_tag = r.get('last_event', '')

                type_label = "UNKNOWN"
                if "DECOY" in event_tag: type_label = "🦆 DECOY"
                elif "TROJAN" in event_tag: type_label = "🐴 TROJAN"
                elif pl > 0: type_label = "💰 PROFIT"
                else: type_label = "💀 LOSS"

                print(f"[{r['time_sec']:.1f}s] {type_label} EXIT: {pl:.2f} EUR (Tag: {event_tag})")

                self.microscope_endgame_analysis(i)

                r1, s1 = self.get_context_levels(i)
                print(f"       Context: Price {r['mid']:.5f} | Pivot Range: [{s1:.5f} - {r1:.5f}]")
                self.check_silence(i)

            last_pos_count = r['pos_count']

    def analyze_bait(self, entry_idx):
        entry_time = self.data[entry_idx]['time_sec']
        pre_data = [x for x in self.data if x['time_sec'] >= entry_time - 60 and x['time_sec'] < entry_time]

        if not pre_data: return
        avg_vel = statistics.mean([x['vel'] for x in pre_data])
        highs = [x['mid'] for x in pre_data]
        displacement = max(highs) - min(highs)
        pt = 0.00001 if pre_data[0]['mid'] < 500 else 0.01
        disp_pts = displacement / pt

        print(f"   🎣 THE BAIT ANALYSIS (Pre-Entry 60s):")
        print(f"       Avg Velocity: {avg_vel:.4f} (Baseline: {self.baseline_vel:.4f})")
        print(f"       Displacement: {disp_pts:.1f} points")

        if avg_vel > self.baseline_vel * 1.5 and disp_pts < 100:
            print("       ⚠️  VERDICT: 'CHURNING' (Toporgás) -> The Trap is Set!")
        elif avg_vel > self.baseline_vel * 2.0:
            print("       ⚠️  VERDICT: 'HYPER-ACTIVITY' -> Aggressive Luring")
        else:
            print("       ℹ️  VERDICT: Normal Market Conditions")

    def check_silence(self, exit_idx):
        exit_time = self.data[exit_idx]['time_sec']
        post_data = [x for x in self.data if x['time_sec'] > exit_time and x['time_sec'] <= exit_time + 30]
        if not post_data: return
        avg_vel = statistics.mean([x['vel'] for x in post_data])
        during_data = [x for x in self.data if x['time_sec'] >= exit_time - 30 and x['time_sec'] < exit_time]
        if not during_data: return
        prev_vel = statistics.mean([x['vel'] for x in during_data])
        ratio = avg_vel / max(0.0001, prev_vel)
        print(f"   🤫 THE SILENCE CHECK (Post-Exit 30s):")
        print(f"       Velocity Drop: {prev_vel:.4f} -> {avg_vel:.4f} (Ratio: {ratio:.2f})")
        if ratio < 0.5:
             print("       🛑 VERDICT: 'DEAD SILENCE' -> Broker Algo turned off.")
        elif ratio > 1.5:
             print("       🚀 VERDICT: 'REVENGE' -> Volatility spiked after we left.")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
        story = MimicStoryTellerV4()
        story.load_data(target)
        story.analyze_narrative()
    else:
        print("Usage: python3 analyze_mimic_story_v4.py <csv_file>")
