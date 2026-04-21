import csv
import math
import os
import glob
from datetime import datetime, timedelta

# Unified Schema
# 0:Time, 1:MS, 2:Action, 3:Ticket, 4:TradePrice, 5:TradeVol, 6:Profit, 7:Comment
# 8:BestBid, 9:BestAsk, 10:Velocity, 11:Acceleration, 12:Spread
# 13-17: BidV1-5, 18-22: AskV1-5

def parse_row(row):
    try:
        data = {}
        if len(row) < 23: return None

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

        try: data['Spread'] = float(row[12])
        except: data['Spread'] = 0.0

        # Depths
        try:
            data['BidDepth'] = sum([int(row[i]) for i in range(13, 18)])
            data['AskDepth'] = sum([int(row[i]) for i in range(18, 23)])
        except:
            data['BidDepth'] = 0
            data['AskDepth'] = 0

        # Timestamp
        dt_str = f"{data['Time']}"
        try:
             # Handle formats: "2026.01.16 22:33:35" or similar
             dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S")
        except:
             try:
                 dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
             except:
                 return None # Invalid date

        data['Timestamp'] = dt + timedelta(milliseconds=data['MS'])
        return data
    except Exception as e:
        return None

def analyze_phase(phase_name, trades):
    print(f"\n--- Analysis: {phase_name} ---")
    if not trades:
        print("No trades in this phase.")
        return

    count = len(trades)
    total_vol = sum(t['TradeVol'] for t in trades)
    avg_vol = total_vol / count

    # Slippage Estimate (Price vs Expected? We only have execution price.
    # We can assume spread is a proxy for cost/slippage risk).
    avg_spread = sum(t['Spread'] for t in trades) / count

    # Velocity at entry
    avg_vel = sum(abs(t['Velocity']) for t in trades) / count

    # Profit (Realized)
    closed_trades = [t for t in trades if "CLOSE" in t['Action']]
    total_profit = sum(t['Profit'] for t in closed_trades) if closed_trades else 0.0

    print(f"Trades: {count} (Execs: {len([t for t in trades if t['Action']=='OPEN'])})")
    print(f"Avg Vol: {avg_vol:.2f} | Total Vol: {total_vol:.2f}")
    print(f"Avg Spread at Event: {avg_spread:.1f} pts")
    print(f"Avg Velocity at Event: {avg_vel:.5f}")
    print(f"Total Realized Profit: {total_profit:.2f}")

    # Impact Analysis?
    # If high volume trades have higher spread or velocity, that's impact.


def main():
    log_dir = "test_logs"
    if not os.path.exists(log_dir):
        print(f"Directory {log_dir} not found. Running on current dir.")
        log_dir = "."

    # Files identified by user timestamps
    # 1. 0.01 Lot (22:33:35)
    # 2. Slippage/TP Config (22:39:38)
    # 3. 100 Lot Stress (22:47:02)
    # DOM Logger (22:34:58)

    files = glob.glob(os.path.join(log_dir, "*.csv"))

    phases = {
        "Phase 1 (0.01 Lot)": [],
        "Phase 2 (Config Change)": [],
        "Phase 3 (100 Lot Stress)": [],
        "DOM Logger Background": []
    }

    for f in files:
        fname = os.path.basename(f)
        data = []
        try:
            with open(f, 'r') as csvfile:
                reader = csv.reader(csvfile)
                next(reader, None) # Skip Header
                for row in reader:
                    if not row: continue
                    d = parse_row(row)
                    if d: data.append(d)
        except Exception as e:
            print(f"Error reading {f}: {e}")
            continue

        if "Hybrid_DOM_Log" in fname:
            phases["DOM Logger Background"].extend(data)
        elif "Trojan_Horse_Log" in fname:
            # Sort by timestamp to be sure, but filename hints are strong
            if "223335" in fname:
                phases["Phase 1 (0.01 Lot)"] = data
            elif "223938" in fname:
                phases["Phase 2 (Config Change)"] = data
            elif "224702" in fname:
                phases["Phase 3 (100 Lot Stress)"] = data

    # Analyze Each Phase
    for name, data in phases.items():
        analyze_phase(name, data)

if __name__ == "__main__":
    main()
