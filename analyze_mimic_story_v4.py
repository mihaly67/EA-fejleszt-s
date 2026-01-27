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

    def load_data(self, filepath):
        print(f"Reading Log: {os.path.basename(filepath)}")
        try:
            with open(filepath, 'r') as f:
                reader = csv.reader(f)
                header = next(reader, None)
                if not header: return

                vels = []

                has_last_event = "LastEvent" in header
                print(f"Schema Detection: LastEvent field {'FOUND' if has_last_event else 'MISSING (Legacy Mode)'}")

                for row in reader:
                    if not row: continue

                    try:
                        # 1. Locate Anchor (Action)
                        action_idx = -1
                        for i in range(len(row)):
                            if "Mimic" in row[i]:
                                action_idx = i
                                break
                        if action_idx == -1 and len(row) >= 19: action_idx = 18
                        if action_idx == -1: continue

                        # 2. Extract Standard Data
                        dt_str = row[0].strip()
                        ms_str = row[1].strip()
                        ms = int(float(ms_str)) if ms_str.replace('.','',1).isdigit() else 0
                        dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S") + timedelta(milliseconds=ms)

                        bid = float(row[3])
                        ask = float(row[4])
                        mid = (bid + ask) / 2.0
                        vel = abs(float(row[6]))

                        realized_tick = float(row[action_idx-1])
                        float_pl = float(row[action_idx-2])

                        pos_count = 0
                        if action_idx + 1 < len(row):
                            try:
                                pos_count = int(float(row[action_idx+1]))
                            except: pass

                        # 3. Extract DOM Snapshot
                        dom_data = None
                        if len(row) >= 34:
                             dom_slice = row[-12:]
                             try:
                                 dom_data = {
                                     'best_bid': float(dom_slice[0]),
                                     'best_ask': float(dom_slice[1]),
                                     'bid_vols': [int(float(x)) for x in dom_slice[2:7]],
                                     'ask_vols': [int(float(x)) for x in dom_slice[7:12]]
                                 }
                             except ValueError: pass

                        # 4. Pressure Proxy (Ext_VA_Vel)
                        # In the sample, index 14 is Ext_VA_Vel which seems to hold the 99.xx values
                        pressure = 0.0
                        if len(row) > 14:
                            try: pressure = float(row[14])
                            except: pass

                        r = {
                            'dt': dt,
                            'time_sec': 0.0,
                            'mid': mid,
                            'vel': vel,
                            'float_pl': float_pl,
                            'realized_tick': realized_tick,
                            'pos_count': pos_count,
                            'dom': dom_data,
                            'pressure': pressure
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
        for s in reversed(valid_swings):
            if s['type'] == 'HIGH':
                last_high = s['price']
                break
        for s in reversed(valid_swings):
            if s['type'] == 'LOW':
                last_low = s['price']
                break
        return last_high, last_low

    def check_dom_spoofing(self):
        print("\n=== 🕵️ FORENSIC MODULE: DOM GHOST HUNT ===\n")
        if not self.data: return

        ghost_events = []
        spoof_ratios = []
        LARGE_VOL = 1000000

        for i in range(1, len(self.data)):
            curr = self.data[i]
            prev = self.data[i-1]

            if not curr['dom'] or not prev['dom']: continue

            # 1. GHOST WALL DETECTION (Disappearing Liquidity)
            # Check BID side ghosting
            prev_bid_vol = prev['dom']['bid_vols'][0]
            curr_bid_vol = curr['dom']['bid_vols'][0]

            if prev_bid_vol > LARGE_VOL and curr_bid_vol < (prev_bid_vol * 0.2):
                # Only if price did NOT crash down to consume it
                if curr['mid'] >= prev['dom']['best_bid']:
                     msg = f"[{curr['time_sec']:.1f}s] 👻 GHOST BID: {prev_bid_vol} -> {curr_bid_vol} @ {prev['dom']['best_bid']:.5f} (Price: {curr['mid']:.5f})"
                     ghost_events.append(msg)

            # Check ASK side ghosting
            prev_ask_vol = prev['dom']['ask_vols'][0]
            curr_ask_vol = curr['dom']['ask_vols'][0]

            if prev_ask_vol > LARGE_VOL and curr_ask_vol < (prev_ask_vol * 0.2):
                # Only if price did NOT spike up to consume it
                if curr['mid'] <= prev['dom']['best_ask']:
                     msg = f"[{curr['time_sec']:.1f}s] 👻 GHOST ASK: {prev_ask_vol} -> {curr_ask_vol} @ {prev['dom']['best_ask']:.5f} (Price: {curr['mid']:.5f})"
                     ghost_events.append(msg)

            # 2. SPOOF RATIO
            trend = 0
            lookback = max(0, i-5)
            if curr['mid'] > self.data[lookback]['mid']: trend = 1
            elif curr['mid'] < self.data[lookback]['mid']: trend = -1

            total_bid = sum(curr['dom']['bid_vols'])
            total_ask = sum(curr['dom']['ask_vols'])

            ratio = 0.0
            type_str = ""

            if trend == 1: # UpTrend -> Check Ask Resistance
                if total_bid > 0:
                    ratio = total_ask / total_bid
                    type_str = "Bearish Wall"
            elif trend == -1: # DownTrend -> Check Bid Support
                if total_ask > 0:
                    ratio = total_bid / total_ask
                    type_str = "Bullish Wall"

            if ratio > 3.0: # Significant Imbalance
                 spoof_ratios.append((curr['time_sec'], ratio, type_str, curr['pressure']))

        print(f"👻 Ghost Events Detected: {len(ghost_events)}")
        # Print first 5 ghosts
        for g in ghost_events[:5]: print(g)

        print(f"🛡️  Spoof Walls Detected: {len(spoof_ratios)}")
        # Filter high pressure spoofs
        high_pressure_spoofs = [x for x in spoof_ratios if x[3] > 90.0]
        print(f"🔥 High Pressure Spoofs (>90): {len(high_pressure_spoofs)}")

        if high_pressure_spoofs:
             print("   Sample High-Pressure Spoofs:")
             for s in high_pressure_spoofs[:5]:
                 print(f"   [{s[0]:.1f}s] Ratio {s[1]:.1f} ({s[2]}) | Pressure: {s[3]:.1f}")

        return len(ghost_events)

    def analyze_narrative(self):
        print("\n=== COLOMBO V4: DYNAMIC CONTEXT REPORT ===")
        if not self.data: return

        self.calculate_tick_zigzag(deviation_points=30)
        self.check_dom_spoofing()

        last_pos_count = 0
        decoy_profit_sum = 0.0

        print(f"\n--- TRADE TIMELINE ---")
        for i, r in enumerate(self.data):
            if r['pos_count'] < last_pos_count:
                diff = last_pos_count - r['pos_count']
                pl = r['realized_tick']
                if pl != 0.0:
                    tag = "💰 PROFIT" if pl > 0 else "💀 LOSS"
                    print(f"[{r['time_sec']:.1f}s] {tag} EXIT: {pl:.2f} EUR")

                    r1, s1 = self.get_context_levels(i)
                    upper = max(r1, s1)
                    lower = min(r1, s1)
                    in_channel = (r['mid'] <= upper and r['mid'] >= lower) if (upper>0 and lower>0) else False

                    print(f"       Context: {r['mid']:.5f} inside [{lower:.5f} - {upper:.5f}]? {'YES' if in_channel else 'NO'}")
                    if r['dom']:
                         b = sum(r['dom']['bid_vols'])
                         a = sum(r['dom']['ask_vols'])
                         print(f"       DOM: Bid {b} / Ask {a}")

                    self.check_momentum_stall(i)

                    if pl > 0 and pl < 30: decoy_profit_sum += pl

            last_pos_count = r['pos_count']

        print(f"\n--- SUMMARY ---")
        print(f"Total Decoy Profit (Est): {decoy_profit_sum:.2f} EUR")

    def check_momentum_stall(self, index):
        if index + 20 >= len(self.data): return
        start = max(0, index-10)
        vel_before = statistics.mean([x['vel'] for x in self.data[start:index+1]])
        vel_after = statistics.mean([x['vel'] for x in self.data[index:index+20]])

        ratio = vel_after / max(0.0001, vel_before)
        print(f"    🔎 VELOCITY: {vel_before:.4f} -> {vel_after:.4f} (Ratio: {ratio:.2f})")

        if ratio < 0.6: print("    🛑 STALL CONFIRMED (Broker lost interest)")
        elif ratio > 1.5: print("    🚀 ACCELERATION DETECTED")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
        story = MimicStoryTellerV4()
        story.load_data(target)
        story.analyze_narrative()
    else:
        print("Usage: python3 analyze_mimic_story_v4.py <csv_file>")
