import csv
import math
import os
import glob
from datetime import datetime, timedelta

# --- UNIFIED SCHEMA ---
# 0:Time, 1:MS, 2:Action, 3:Ticket, 4:TradePrice, 5:TradeVol, 6:Profit, 7:Comment
# 8:BestBid, 9:BestAsk, 10:Velocity, 11:Acceleration, 12:Spread
# 13-17: BidV1-5, 18-22: AskV1-5

def parse_row(row):
    try:
        data = {}
        if len(row) < 23: return None

        # Basic Parsing
        data['Time'] = row[0]
        data['MS'] = int(row[1])
        data['Action'] = row[2]

        try: data['Ticket'] = int(row[3])
        except: data['Ticket'] = 0

        try: data['TradePrice'] = float(row[4])
        except: data['TradePrice'] = 0.0

        try: data['TradeVol'] = float(row[5])
        except: data['TradeVol'] = 0.0

        try: data['Profit'] = float(row[6])
        except: data['Profit'] = 0.0

        try: data['BestBid'] = float(row[8])
        except: data['BestBid'] = 0.0

        try: data['BestAsk'] = float(row[9])
        except: data['BestAsk'] = 0.0

        try: data['Velocity'] = float(row[10])
        except: data['Velocity'] = 0.0

        try: data['Acceleration'] = float(row[11])
        except: data['Acceleration'] = 0.0

        try: data['Spread'] = float(row[12])
        except: data['Spread'] = 0.0

        # DOM Depths
        try:
            data['BidDepth'] = sum([int(row[i]) for i in range(13, 18)])
            data['AskDepth'] = sum([int(row[i]) for i in range(18, 23)])
            data['BidL1'] = int(row[13])
            data['AskL1'] = int(row[18])
        except:
            data['BidDepth'] = 0
            data['AskDepth'] = 0
            data['BidL1'] = 0
            data['AskL1'] = 0

        # Timestamp Construction
        dt_str = f"{data['Time']}"
        dt = None
        for fmt in ["%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"]:
            try:
                dt = datetime.strptime(dt_str, fmt)
                break
            except: pass

        if dt is None: return None

        data['Timestamp'] = dt + timedelta(milliseconds=data['MS'])
        return data
    except Exception as e:
        return None

def analyze_mimic_session(mimic_file, dom_file):
    print(f"\n==========================================")
    print(f"ANALYZING SESSION: {os.path.basename(mimic_file)}")
    print(f"==========================================")

    # 1. Load Data
    mimic_data = []
    dom_data = []

    # Load Mimic (Trades)
    with open(mimic_file, 'r') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if not row: continue
            d = parse_row(row)
            if d: mimic_data.append(d)

    # Load DOM (Background)
    with open(dom_file, 'r') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if not row: continue
            d = parse_row(row)
            if d: dom_data.append(d)

    print(f"Loaded {len(mimic_data)} Mimic Events and {len(dom_data)} DOM snapshots.")

    # 2. Identify Trap Sequences
    # A Trap Sequence is defined by DECOY_OPEN events followed by a TROJAN_OPEN event.
    # Group them by time proximity (e.g., within 1 second).

    events = sorted(mimic_data, key=lambda x: x['Timestamp'])

    sequences = []
    current_seq = []

    for evt in events:
        if "OPEN" in evt['Action']:
            if not current_seq:
                current_seq.append(evt)
            else:
                # Check time diff
                dt = (evt['Timestamp'] - current_seq[-1]['Timestamp']).total_seconds()
                if dt < 2.0: # 2 second window for a sequence
                    current_seq.append(evt)
                else:
                    sequences.append(current_seq)
                    current_seq = [evt]
    if current_seq: sequences.append(current_seq)

    print(f"Identified {len(sequences)} Trap Execution Sequences.")

    # 3. Analyze Each Sequence
    for i, seq in enumerate(sequences):
        start_time = seq[0]['Timestamp']
        end_time = seq[-1]['Timestamp']

        decoys = [s for s in seq if "DECOY" in s['Action']]
        trojans = [s for s in seq if "TROJAN" in s['Action']]

        if not trojans: continue # Skip partials

        trojan = trojans[0]
        direction = "BUY" if trojan['Action'] == "TROJAN_OPEN" and trojan['TradePrice'] > 0 else "SELL"
        # Actually Action is just TROJAN_OPEN, need to infer direction from Price vs Bid/Ask or Decoy logic
        # Decoys are opposite.

        # Let's verify direction from comment or price match (heuristic)
        # Better: Look at Decoys. If Decoy is BUY, Trojan is SELL.
        trojan_dir = "UNKNOWN"
        if decoys:
             # Heuristic: Decoys are fake direction.
             # But 'Action' is just DECOY_OPEN.
             # We rely on price.
             pass

        print(f"\n--- Sequence #{i+1} ({start_time.strftime('%H:%M:%S')}) ---")
        print(f"   Decoys: {len(decoys)} | Trojan Vol: {trojan['TradeVol']:.2f}")

        # Find Context in DOM Data (closest to start_time)
        # Naive search
        context = None
        min_dt = 999.0
        for row in dom_data:
            diff = abs((row['Timestamp'] - start_time).total_seconds())
            if diff < min_dt:
                min_dt = diff
                context = row
            if diff > 5.0 and row['Timestamp'] > start_time: break # Optimization

        if context:
            print(f"   Context (dt={min_dt:.3f}s):")
            print(f"     Spread: {context['Spread']:.1f}")
            print(f"     Velocity: {context['Velocity']:.5f}")
            print(f"     Accel: {context['Acceleration']:.5f}")
            print(f"     DOM Imbalance (Bid/Ask Depth): {context['BidDepth']} / {context['AskDepth']} (Ratio: {context['BidDepth']/(context['AskDepth']+1):.2f})")
            print(f"     L1 Liquidity: {context['BidL1']} / {context['AskL1']}")
        else:
            print("   Context: No DOM data found near event.")

        # Find Outcome (Close)
        # Search for CLOSE_ALL events after this sequence
        # This is tricky if multiple traps are active, but Mimic usually runs one at a time.
        pass

def main():
    input_dir = "analysis_input"

    # Pair files
    mimic_files = glob.glob(os.path.join(input_dir, "Mimic_*.csv"))
    dom_files = glob.glob(os.path.join(input_dir, "Hybrid_DOM_*.csv"))

    if not mimic_files:
        print("No Mimic logs found.")
        return

    # Assume pairs by date (simplification for this specific task)
    for m_file in mimic_files:
        # Find matching DOM file (by date mostly)
        # Filename format: Mimic_Trap_Log_GBPUSD_20260123_224130.csv
        base = os.path.basename(m_file)
        parts = base.split('_')
        if len(parts) >= 6:
            date_part = parts[4] # 20260123

            # Find dom file with same date
            d_file = None
            for d in dom_files:
                if date_part in d:
                    d_file = d
                    break

            if d_file:
                analyze_mimic_session(m_file, d_file)
            else:
                print(f"Warning: No matching DOM log for {base}")

if __name__ == "__main__":
    main()
