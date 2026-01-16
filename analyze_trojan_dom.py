import csv
import math
import os
import glob
from datetime import datetime, timedelta

# Unified Schema for both Trojan Horse EA and Hybrid DOM Logger
# 0:Time, 1:MS, 2:Action, 3:Ticket, 4:TradePrice, 5:TradeVol, 6:Profit, 7:Comment
# 8:BestBid, 9:BestAsk, 10:Velocity, 11:Acceleration, 12:Spread
# 13-17: BidV1-5, 18-22: AskV1-5

def find_latest_log(directory="MQL5/Files", prefix="Trojan_Horse_Log_"):
    search_pattern = os.path.join(directory, prefix + "*.csv")
    files = glob.glob(search_pattern)
    if not files:
        # Try local directory
        search_pattern = os.path.join(".", prefix + "*.csv")
        files = glob.glob(search_pattern)

    if not files: return None
    return max(files, key=os.path.getctime)

def parse_row(row):
    try:
        data = {}
        # Basic Safety Check
        if len(row) < 23: return None

        data['Time'] = row[0]
        data['MS'] = int(row[1])
        data['Action'] = row[2]

        # Trade Data (Might be 0/NA for Logger)
        try: data['Ticket'] = int(row[3])
        except: data['Ticket'] = 0

        try: data['TradePrice'] = float(row[4])
        except: data['TradePrice'] = 0.0

        # Market Data
        data['BestBid'] = float(row[8])
        data['BestAsk'] = float(row[9])
        data['Velocity'] = float(row[10])
        data['Spread'] = float(row[12])

        # Depths
        data['BidDepth'] = sum([int(row[i]) for i in range(13, 18)])
        data['AskDepth'] = sum([int(row[i]) for i in range(18, 23)])

        # Timestamp Construction
        dt_str = f"{data['Time']}"
        try:
             dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S")
        except:
             dt = datetime.now()

        data['Timestamp'] = dt + timedelta(milliseconds=data['MS'])
        return data
    except Exception as e:
        return None

def analyze_stealth(trades):
    print("\n--- Stealth Mode Analysis (Trades Only) ---")
    if len(trades) < 2:
        print("Not enough trades for interval analysis.")
        return

    intervals = []
    for i in range(1, len(trades)):
        t1 = trades[i-1]['Timestamp']
        t2 = trades[i]['Timestamp']
        diff = (t2 - t1).total_seconds()
        intervals.append(diff)

    avg = sum(intervals) / len(intervals)
    variance = sum([((x - avg) ** 2) for x in intervals]) / len(intervals)
    std_dev = math.sqrt(variance)

    print(f"Total Trades: {len(trades)}")
    print(f"Avg Interval: {avg:.4f} sec")
    print(f"StdDev Interval: {std_dev:.4f} sec")

def analyze_market(rows, label="Rows"):
    print(f"\n--- Market Context ({label}) ---")
    if not rows: return

    avg_vel = sum(r['Velocity'] for r in rows) / len(rows)
    avg_spread = sum(r['Spread'] for r in rows) / len(rows)
    avg_bid_d = sum(r['BidDepth'] for r in rows) / len(rows)
    avg_ask_d = sum(r['AskDepth'] for r in rows) / len(rows)

    print(f"Count: {len(rows)}")
    print(f"Avg Velocity: {avg_vel:.5f}")
    print(f"Avg Spread: {avg_spread:.2f}")
    print(f"Avg Bid Depth: {avg_bid_d:.0f}")
    print(f"Avg Ask Depth: {avg_ask_d:.0f}")

def main():
    # Detect both types of logs
    trojan_file = find_latest_log(prefix="Trojan_Horse_Log_")
    dom_file = find_latest_log(prefix="Hybrid_DOM_Log_")

    files_to_analyze = []
    if trojan_file: files_to_analyze.append(("Trojan EA", trojan_file))
    if dom_file: files_to_analyze.append(("DOM Logger", dom_file))

    if not files_to_analyze:
        print("No logs found. Generating dummy test file...")
        dummy_name = "Trojan_Horse_Log_TEST_Unified.csv"
        with open(dummy_name, "w") as f:
            f.write("Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,BestBid,BestAsk,Velocity,Acceleration,Spread,B1,B2,B3,B4,B5,A1,A2,A3,A4,A5\n")
            f.write("2024.01.01 12:00:00,100,OPEN,1,1.05,0.1,0,Test,1.049,1.051,0.0001,0,10,100,100,100,100,100,200,200,200,200,200\n")
            f.write("2024.01.01 12:00:01,200,OPEN,2,1.05,0.1,0,Test,1.049,1.051,0.0002,0,10,100,100,100,100,100,200,200,200,200,200\n")
        files_to_analyze.append(("Dummy Test", dummy_name))

    for label, filepath in files_to_analyze:
        print(f"\n==========================================")
        print(f"Analyzing {label}: {filepath}")
        print(f"==========================================")

        trades = []
        market_rows = []

        try:
            with open(filepath, 'r') as f:
                reader = csv.reader(f)
                header = next(reader, None)
                for row in reader:
                    if not row: continue
                    data = parse_row(row)
                    if data:
                        market_rows.append(data) # All rows have market data
                        if data['Action'] == 'OPEN':
                            trades.append(data)
        except Exception as e:
            print(f"Error reading {filepath}: {e}")
            continue

        analyze_market(market_rows, "All Ticks/Events")
        if trades:
            analyze_stealth(trades)
        else:
            print("No trades found in this log.")

    if "TEST_Unified" in files_to_analyze[0][1]:
        os.remove(files_to_analyze[0][1])

if __name__ == "__main__":
    main()
