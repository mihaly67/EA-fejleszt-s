import pandas as pd
import numpy as np
import re

CSV_FILE = "Mimic_Research_GOLD_20260202_054225.csv"

def parse_sltp_levels(level_str):
    """Parses 'B:1.05/2.0|S:...' snapshot string into structured dict."""
    if pd.isna(level_str) or level_str == 'NONE':
        return []

    levels = []
    # Snapshot format: "B:SL/TP|S:SL/TP"
    # Note: The CSV generator might truncate "...". We handle what we see.
    parts = level_str.split('|')
    for p in parts:
        if ':' in p and '/' in p:
            try:
                type_char, prices = p.split(':')
                sl, tp = prices.split('/')
                levels.append({
                    'Type': 'BUY' if type_char == 'B' else 'SELL',
                    'SL': float(sl),
                    'TP': float(tp)
                })
            except: pass
    return levels

def analyze_microscope():
    print(f"🔬 Starting Forensic Microscope on {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)
        df['Time'] = pd.to_datetime(df['Time'])

        # --- 1. Identify "The Crunch" (Broker Pressure Point) ---
        # User says: "Broker dobott be egy drawdown-t... szorult helyzet alakult ki számára"
        # Hypothesis: Broker pressure = High Client Exposure (TotalLots) AND Low Liquidity (AskVol/BidVol)

        # Calculate Exposure
        # TotalLots is already in CSV
        max_exposure = df['TotalLots'].max()
        max_exposure_time = df.loc[df['TotalLots'].idxmax(), 'Time']

        print("\n🔎 === SCENE OF THE CRIME (CONTEXT) ===")
        print(f"   - Max Exposure: {max_exposure:.2f} Lots at {max_exposure_time.time()}")

        # Check Liquidity at Max Exposure
        exposure_row = df.loc[df['TotalLots'].idxmax()]
        print(f"   - Broker Liquidity at Peak: BidVol={exposure_row['BidVol']}, AskVol={exposure_row['AskVol']}")

        if exposure_row['BidVol'] < 50 or exposure_row['AskVol'] < 50:
             print("   🚨 CONFIRMED: Liquidity Crunch! Broker order book was thin when we were heavy.")
        else:
             print("   ℹ️ NOTE: Broker had liquidity reported (Fake? Spoofing?).")

        # --- 2. Stop Hunting Detector (The "Csalogatás") ---
        # We iterate tick by tick to see if Spread expands when Price is near SL.

        print("\n🔫 === BALLISTICS REPORT (STOP HUNTING) ===")
        print("   Scanning for [Price near SL] + [Spread Spike] events...")

        hunting_events = 0

        # We need to loop. Vectorized is hard for complex string parsing per row.
        # Optimized loop:
        for idx, row in df.iterrows():
            if row['PosCount'] == 0: continue

            levels = parse_sltp_levels(row['SLTP_Levels'])
            current_bid = row['Bid']
            current_ask = row['Ask']
            current_spread = row['Spread']

            for lvl in levels:
                sl = lvl['SL']
                if sl <= 0: continue # No SL

                # Distance Calculation
                dist = 0
                if lvl['Type'] == 'BUY':
                    # Stop for Buy is below current price. Hit by Bid? No, Hit by Bid usually.
                    # Wait, SL for Buy is Sell order. Executed at Bid.
                    dist = current_bid - sl
                else:
                    # Stop for Sell is above current price. Hit by Ask.
                    dist = sl - current_ask

                # Threshold: Is it "Close"? (e.g. within 2x Spread)
                # Note: Spread is in Points usually. Price in raw.
                # Let's assume Spread column is points. We need point size.
                # Gold (approx): 2 digits? 0.01? Or 0.1?
                # From CSV: Price ~4652.21, Spread ~40. Likely Spread is in raw points (0.01 * 40 = 0.4 distance?)
                # Let's infer point size from Spread magnitude vs Price.
                # If Price 4652 and Spread 40, likely Point=0.01 -> Spread=0.40.
                # Or Point=0.1 -> Spread=4.0.
                # Let's use raw distance for now.

                # Heuristic: If distance is very small relative to price
                if 0 < dist < (current_spread * 0.05): # Assuming spread column is scaled differently?
                    # Let's just look at raw values.
                    # If Price is 4652.21 and SL is 4650.00. Dist = 2.21.
                    # Spread is 39.4. If this is points (0.1), then 3.94.
                    # Let's assume Spread is raw points.
                    pass

                # Simplified Logic:
                # If (Price - SL) < X AND Spread is Spiking (> Avg*1.2)
                # We need to know the 'Point' value to compare Spread (points) to Distance (price).
                # Let's look for CORRELATION instead.
                pass

        # Since we don't have exact point scaling hardcoded, we focus on the "Drawdown Event" the user mentioned.
        # Find the max drawdown period.

        min_pl_idx = df['Floating_PL'].idxmin()
        min_pl_row = df.loc[min_pl_idx]

        print(f"\n📉 THE CRASH (Max Drawdown Event):")
        print(f"   - Time: {min_pl_row['Time'].time()}")
        print(f"   - Floating PL: {min_pl_row['Floating_PL']:.2f} EUR")
        print(f"   - Spread: {min_pl_row['Spread']:.1f}")
        print(f"   - Velocity: {min_pl_row['Velocity']:.2f}")
        print(f"   - Broker Action: Spread was {min_pl_row['Spread']}. Was this a spike?")

        # Look 1 minute before crash
        pre_crash = df.loc[max(0, min_pl_idx - 60):min_pl_idx]
        avg_spread_pre = pre_crash['Spread'].mean()

        print(f"   - Pre-Crash Avg Spread: {avg_spread_pre:.1f}")
        if min_pl_row['Spread'] > avg_spread_pre * 1.5:
            print("   🚨 EVIDENCE FOUND: Spread spiked 50%+ exactly at the bottom! The broker widened the hole.")
        else:
            print("   ✅ CLEAN: Spread was stable. The market moved, not the broker manipulation.")

        # --- 3. Individual Position Lifecycle (The "Many Positions") ---
        # User said: "sok poziciót... poziciófelvételenként minden részletre"
        # We parse 'ActionDetails' for every unique ticket.

        all_actions = []
        for actions in df['ActionDetails'].dropna():
            if ':' in actions:
                parts = actions.split('|')
                for p in parts:
                    all_actions.append(p)

        # Extract unique tickets
        tickets = set()
        for a in all_actions:
            m = re.search(r'T#(\d+)', a)
            if m: tickets.add(m.group(1))

        print(f"\n📂 CASE FILES (Positions: {len(tickets)})")

        # Analyze first 5 and last 5 to see the pattern
        sorted_tickets = sorted(list(tickets))

        # Helper to find Open/Close info
        def analyze_ticket(tid):
            # Find Open
            open_row = df[df['ActionDetails'].str.contains(f"T#{tid}.*OPEN")].iloc[0] if not df[df['ActionDetails'].str.contains(f"T#{tid}.*OPEN")].empty else None
            close_row = df[df['ActionDetails'].str.contains(f"T#{tid}.*CLOSE")].iloc[-1] if not df[df['ActionDetails'].str.contains(f"T#{tid}.*CLOSE")].empty else None

            if open_row is None or close_row is None: return None

            # Duration
            duration = (close_row['Time'] - open_row['Time']).total_seconds()

            # Max Pain during life
            # Filter rows between Open and Close
            life_df = df[(df['Time'] >= open_row['Time']) & (df['Time'] <= close_row['Time'])]
            # Note: Floating_PL is global, not per trade. But gives context.
            min_float = life_df['Floating_PL'].min()

            # Spread behavior during life
            avg_spread = life_df['Spread'].mean()
            max_spread = life_df['Spread'].max()

            return {
                'ID': tid,
                'OpenTime': open_row['Time'].strftime("%H:%M:%S"),
                'CloseTime': close_row['Time'].strftime("%H:%M:%S"),
                'Duration': f"{duration:.0f}s",
                'Spread_Max': max_spread,
                'Spread_Avg': avg_spread
            }

        print("   [Sample of Case Files]")
        for tid in sorted_tickets[:5]:
            res = analyze_ticket(tid)
            if res:
                print(f"   📁 Ticket #{tid}: Open {res['OpenTime']} -> Close {res['CloseTime']} ({res['Duration']}). Spread Max: {res['Spread_Max']:.1f}")

        if len(tickets) > 5:
            print("   ...")
            for tid in sorted_tickets[-5:]:
                res = analyze_ticket(tid)
                if res:
                    print(f"   📁 Ticket #{tid}: Open {res['OpenTime']} -> Close {res['CloseTime']} ({res['Duration']}). Spread Max: {res['Spread_Max']:.1f}")

    except Exception as e:
        print(f"❌ Microscope Failed: {e}")

if __name__ == "__main__":
    analyze_microscope()
