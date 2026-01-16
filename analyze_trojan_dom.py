import csv
import math
import os
import glob
from datetime import datetime, timedelta

# Columns mapping based on EA v1.01 definition
# 0:Time, 1:MS, 2:Action, 3:Ticket, 4:TradePrice, 5:TradeVol, 6:Profit, 7:Comment,
# 8:BestBid, 9:BestAsk, 10:Velocity, 11:Acceleration, 12:Spread,
# 13-17: BidV1-5, 18-22: AskV1-5

def find_latest_log(directory="MQL5/Files"):
    search_pattern = os.path.join(directory, "Trojan_Horse_Log_*.csv")
    files = glob.glob(search_pattern)
    if not files:
        return None
    return max(files, key=os.path.getctime)

def parse_row(row):
    try:
        data = {}
        data['Time'] = row[0]
        data['MS'] = int(row[1])
        data['Action'] = row[2]
        data['Ticket'] = int(row[3])
        data['TradePrice'] = float(row[4])
        data['TradeVol'] = float(row[5])
        data['Profit'] = float(row[6])
        data['Comment'] = row[7]

        # DOM Parts
        if len(row) > 8:
            data['BestBid'] = float(row[8])
            data['BestAsk'] = float(row[9])
            data['Velocity'] = float(row[10])
            data['Spread'] = float(row[12])

            # Depths
            data['BidDepth'] = sum([int(row[i]) for i in range(13, 18)])
            data['AskDepth'] = sum([int(row[i]) for i in range(18, 23)])
        else:
             # Fallback if DOM data missing
            data['BestBid'] = 0
            data['BestAsk'] = 0
            data['Velocity'] = 0
            data['Spread'] = 0
            data['BidDepth'] = 0
            data['AskDepth'] = 0

        # Timestamp
        dt_str = f"{data['Time']}"
        try:
             dt = datetime.strptime(dt_str, "%Y.%m.%d %H:%M:%S")
        except:
             dt = datetime.now() # Fallback

        data['Timestamp'] = dt + timedelta(milliseconds=data['MS'])
        return data
    except Exception as e:
        # print(f"Parse error: {e} in row {row}")
        return None

def analyze_stealth(trades):
    print("\n--- Stealth Mode Analysis ---")
    if not trades:
        print("No trades found.")
        return

    intervals = []
    for i in range(1, len(trades)):
        t1 = trades[i-1]['Timestamp']
        t2 = trades[i]['Timestamp']
        diff = (t2 - t1).total_seconds()
        intervals.append(diff)

    if not intervals:
        print("Not enough trades for interval analysis.")
        return

    avg = sum(intervals) / len(intervals)
    variance = sum([((x - avg) ** 2) for x in intervals]) / len(intervals)
    std_dev = math.sqrt(variance)

    print(f"Total Trades: {len(trades)}")
    print(f"Avg Interval: {avg:.4f} sec")
    print(f"StdDev Interval: {std_dev:.4f} sec (Higher = More Random)")
    print(f"Min Interval: {min(intervals):.4f} sec")
    print(f"Max Interval: {max(intervals):.4f} sec")

def analyze_market(trades):
    print("\n--- Market Context at Entry ---")
    if not trades: return

    avg_vel = sum(t['Velocity'] for t in trades) / len(trades)
    avg_spread = sum(t['Spread'] for t in trades) / len(trades)
    avg_bid_d = sum(t['BidDepth'] for t in trades) / len(trades)
    avg_ask_d = sum(t['AskDepth'] for t in trades) / len(trades)

    print(f"Avg Velocity: {avg_vel:.5f}")
    print(f"Avg Spread: {avg_spread:.2f}")
    print(f"Avg Bid Depth: {avg_bid_d:.0f}")
    print(f"Avg Ask Depth: {avg_ask_d:.0f}")

def main():
    log_file = find_latest_log(".") or find_latest_log("MQL5/Files") or find_latest_log("Factory_System")

    if not log_file:
        print("No logs found. Creating dummy test...")
        log_file = "Trojan_Horse_Log_TEST_12345.csv"
        with open(log_file, "w") as f:
            # Header
            f.write("Time,MS,Action,Ticket,TradePrice,TradeVol,Profit,Comment,BestBid,BestAsk,Velocity,Acceleration,Spread,B1,B2,B3,B4,B5,A1,A2,A3,A4,A5\n")
            # Dummy Row 1
            f.write("2024.01.01 12:00:00,100,OPEN,1,1.05,0.1,0,Test,1.049,1.051,0.0001,0,10,100,100,100,100,100,200,200,200,200,200\n")
            # Dummy Row 2
            f.write("2024.01.01 12:00:01,200,OPEN,2,1.05,0.1,0,Test,1.049,1.051,0.0002,0,10,100,100,100,100,100,200,200,200,200,200\n")

    print(f"Analyzing: {log_file}")

    trades = []
    closes = []

    try:
        with open(log_file, 'r') as f:
            reader = csv.reader(f)
            header = next(reader, None) # Skip header
            for row in reader:
                if not row: continue
                data = parse_row(row)
                if data:
                    if data['Action'] == 'OPEN':
                        trades.append(data)
                    elif 'CLOSE' in data['Action']:
                        closes.append(data)
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    analyze_stealth(trades)
    analyze_market(trades)

    if "TEST_12345" in log_file:
        os.remove(log_file)

if __name__ == "__main__":
    main()
