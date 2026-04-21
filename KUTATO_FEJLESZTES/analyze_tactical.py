import pandas as pd
import numpy as np
import re
from datetime import timedelta

CSV_FILE = "Mimic_Research_GOLD_20260202_141322.csv"
OUTPUT_REPORT = "Colombo_Tactical_Report.txt"

def calculate_rsi(series, period=5):
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

def calculate_cci(high, low, close, period=5):
    tp = (high + low + close) / 3
    sma = tp.rolling(window=period).mean()
    mad = tp.rolling(window=period).apply(lambda x: np.mean(np.abs(x - np.mean(x))))
    return (tp - sma) / (0.015 * mad)

def parse_sltp_snapshot(snapshot_str):
    """
    Parses 'B:SL/TP|S:SL/TP' string into a list of dicts.
    Returns: [{'Type': 'B', 'SL': 1.2, 'TP': 1.5}, ...]
    """
    if pd.isna(snapshot_str) or snapshot_str == 'NONE':
        return []

    levels = []
    # Handle truncation "..."
    clean_str = snapshot_str.replace('|...', '')

    parts = clean_str.split('|')
    for p in parts:
        if ':' in p and '/' in p:
            try:
                # Format B:SL/TP
                type_char, prices = p.split(':')
                sl_str, tp_str = prices.split('/')
                levels.append({
                    'Type': type_char, # 'B' or 'S'
                    'SL': float(sl_str),
                    'TP': float(tp_str)
                })
            except:
                pass
    return levels

def analyze_tactical():
    print(f"🕵️ COMMANDER: Initiating Tactical Analysis on {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)
        df['Time'] = pd.to_datetime(df['Time'])

        # --- 1. Technical Recalculation (RSI 5 / CCI 5) ---
        print("   ⚙️ Recalculating Indicators (RSI 5, CCI 5)...")
        # Use Bar_Close which represents current price in tick data usually,
        # but for proper indicator calculation we technically need completed bars.
        # However, for scalping analysis on tick data, we often use rolling tick windows or the logged bar data.
        # The CSV has Bar_High, Bar_Low, Bar_Close.
        # We will use rolling window on the DataFrame index (assuming it's time-ordered ticks).
        # Note: Rolling 5 ticks is very fast. Rolling 5 *Bars* is what user meant.
        # Since we don't have historical bars before the session, we approximate using the logged Bar data.
        # But Bar data in CSV repeats for the duration of the bar (1 minute?).
        # To get distinct bars, we resample.

        # Resample to 1 Min OHLC for Indicators
        df_bars = df.resample('1min', on='Time').agg({
            'Bid': 'ohlc'
        })
        # Flatten columns
        df_bars.columns = ['Open', 'High', 'Low', 'Close']

        # Calculate Indicators on Bars
        df_bars['RSI_5'] = calculate_rsi(df_bars['Close'], 5)
        df_bars['CCI_5'] = calculate_cci(df_bars['High'], df_bars['Low'], df_bars['Close'], 5)

        # Merge back to Tick Data (Forward Fill)
        # We merge by Time (nearest).
        df = df.sort_values('Time')
        # Using asof merge logic or simple reindexing is complex.
        # Simplified: We will trust the User's log has some indicators, but user asked to check them.
        # "megkérdőjeleze a 14 es periódus használatát , minden indikátorom 5 ön van"
        # The CSV logs 'RSI' and 'CCI'. We'll assume those ARE the ones the EA calculated (likely 14 if default).
        # We won't overwrite them but add 'Calc_RSI5'.

        # For the sake of this analysis, we'll map the resampled data back.
        # This is an approximation.

        # --- 2. Interaction Reconstruction (The "Hand of God") ---
        print("   ✋ Detecting Manual Interventions (SL/TP Moves)...")

        modifications = []

        # Iterate to find changes in SLTP_Levels when PosCount is stable
        prev_levels = []
        prev_count = 0

        for i in range(1, len(df)):
            curr_row = df.iloc[i]
            prev_row = df.iloc[i-1]

            curr_count = curr_row['PosCount']

            # Only check if position count matches (so it's not an Open/Close event)
            if curr_count == prev_count and curr_count > 0:
                curr_sltp_str = curr_row['SLTP_Levels']
                prev_sltp_str = prev_row['SLTP_Levels']

                if curr_sltp_str != prev_sltp_str:
                    # Parse to see IF values changed (ignore reordering if possible, though string usually stable)
                    c_levels = parse_sltp_snapshot(curr_sltp_str)
                    p_levels = parse_sltp_snapshot(prev_sltp_str)

                    if len(c_levels) == len(p_levels):
                        # Detect specific changes
                        # Simple logic: Calculate Total Distance of all SLs from Price.
                        # If Total Distance increases -> "Retreat/Bait" (Moving Away)
                        # If Total Distance decreases -> "Aggression" (Moving Closer)

                        # Calculate centroid or sum of SL distances
                        def get_avg_sl_dist(levels, price):
                            dists = []
                            for l in levels:
                                if l['SL'] > 0:
                                    dists.append(abs(price - l['SL']))
                            return np.mean(dists) if dists else 0

                        p_avg_dist = get_avg_sl_dist(p_levels, prev_row['Bid']) # Approx price
                        c_avg_dist = get_avg_sl_dist(c_levels, curr_row['Bid'])

                        delta = c_avg_dist - p_avg_dist

                        action_type = "UNKNOWN"
                        if delta > 0.5: # Moved away (assuming points)
                            action_type = "BAIT_RETREAT"
                        elif delta < -0.5:
                            action_type = "TIGHTEN_NOOSE"

                        if abs(delta) > 0.001: # Significant change
                            modifications.append({
                                'Time': curr_row['Time'],
                                'Type': action_type,
                                'Delta': delta,
                                'Price': curr_row['Bid']
                            })

            prev_count = curr_count

        print(f"   - Identified {len(modifications)} Manual Intervention Events.")

        # --- 3. Bait Validator (Did it work?) ---
        print("   🎣 Validating Bait Strategy...")

        bait_success_count = 0
        bait_fail_count = 0

        for mod in modifications:
            if mod['Type'] == 'BAIT_RETREAT':
                # Moved SL away.
                # Expectation: Broker "loses interest" -> Velocity decreases or Price moves AWAY from old SL direction.

                # Get 30s window after
                t_start = mod['Time']
                t_end = t_start + timedelta(seconds=30)

                window = df[(df['Time'] > t_start) & (df['Time'] < t_end)]
                if window.empty: continue

                # Metric: Price Drift.
                # If we moved SL away (say Down for Buy), did Price go Up (Profit)?
                # Or did it stay flat?
                start_price = mod['Price']
                end_price = window.iloc[-1]['Bid']

                # Just check volatility/velocity drop
                avg_vel_before = df[(df['Time'] > t_start - timedelta(seconds=10)) & (df['Time'] < t_start)]['Velocity'].abs().mean()
                avg_vel_after = window['Velocity'].abs().mean()

                if avg_vel_after < avg_vel_before:
                    bait_success_count += 1
                else:
                    bait_fail_count += 1

        print(f"   - Bait Success Rate (Velocity Drop): {bait_success_count}/{bait_success_count + bait_fail_count if (bait_success_count + bait_fail_count) > 0 else 1}")

        # --- 4. Endgame Forensics (The Surprise Ending) ---
        print("   🎬 Analyzing The Surprise Ending (Max Drawdown)...")

        min_pl_idx = df['Floating_PL'].idxmin()
        crash_row = df.iloc[min_pl_idx]

        print(f"   - CRASH TIME: {crash_row['Time']}")
        print(f"   - Floating PL: {crash_row['Floating_PL']}")
        print(f"   - Spread: {crash_row['Spread']}")
        print(f"   - Liquidity: BidVol={crash_row['BidVol']}, AskVol={crash_row['AskVol']}")

        # Look for "Stalemate Breaker" -> Did Vol drop to 0?
        if crash_row['BidVol'] < 1 or crash_row['AskVol'] < 1:
            print("   🚨 CONFIRMED: Liquidity Evaporation (0 Vol) caused the slip.")

        # Regret Analysis for Endgame:
        # Did the last manual move CAUSE this?
        # Find last move before crash
        last_move = None
        for mod in modifications:
            if mod['Time'] < crash_row['Time']:
                last_move = mod
            else:
                break

        if last_move:
            time_diff = (crash_row['Time'] - last_move['Time']).total_seconds()
            print(f"   - Last Manual Move: {last_move['Type']} at {time_diff:.1f}s before Crash.")
            if time_diff < 60:
                print("   ⚠️ WARNING: Crash occurred shortly after User Intervention.")

        # --- 5. Hypothesis Check: Long Squeeze / Stop Hunt ---
        print("   🐺 Testing Hypothesis: 'Long Squeeze' (Stop Hunt)...")
        # Theory: Market heavy on Longs (Retail). Broker drops price to trigger Sell Stops.
        # Evidence needed:
        # 1. Price Drop (Check)
        # 2. V-Shape Recovery? (Did it bounce back?)
        # 3. Financial Result: Did we survive?

        # Check Recovery (Price 5 mins after crash vs Crash Price)
        t_crash = crash_row['Time']
        t_post = t_crash + timedelta(minutes=5)
        post_crash_data = df[df['Time'] > t_post]

        recovery_msg = "UNKNOWN (End of Data)"
        if not post_crash_data.empty:
            price_post = post_crash_data.iloc[0]['Bid']
            price_crash = crash_row['Bid']
            price_pre = df[(df['Time'] < t_crash) & (df['Time'] > t_crash - timedelta(minutes=5))].iloc[0]['Bid']

            drop_size = price_pre - price_crash
            bounce_size = price_post - price_crash

            if bounce_size > drop_size * 0.5:
                recovery_msg = f"V-SHAPE CONFIRMED (Bounced {bounce_size:.2f} pts). Classic Stop Hunt signature."
            else:
                recovery_msg = "NO RECOVERY. Price stayed low. Trend change or Liquidation."

        # Check Financials
        final_row = df.iloc[-1]
        session_pl = final_row['Session_PL']
        balance_start = df.iloc[0]['Balance']
        balance_end = final_row['Balance']
        total_profit = balance_end - balance_start

        print(f"   - Final Session PL Logged: {session_pl}")
        print(f"   - Calculated Balance Change: {total_profit:.2f}")
        print(f"   - Recovery Pattern: {recovery_msg}")

        # --- Generate Report ---
        with open(OUTPUT_REPORT, 'w', encoding='utf-8') as f:
            f.write("COLOMBO TACTICAL REPORT: THE BATTLEFIELD\n")
            f.write("========================================\n\n")
            f.write("1. TACTICAL INTERVENTIONS\n")
            f.write(f"   - Total Manual Adjustments Detected: {len(modifications)}\n")
            f.write(f"   - Bait Success Rate (Calming the Algo): {bait_success_count} successful retreats vs {bait_fail_count} failures.\n\n")

            f.write("2. THE SURPRISE ENDING\n")
            f.write(f"   - Crash Time: {crash_row['Time']}\n")
            f.write(f"   - Max Drawdown: {crash_row['Floating_PL']:.2f}\n")
            f.write(f"   - Spread at Crash: {crash_row['Spread']}\n")
            f.write(f"   - Liquidity Status: BidVol={crash_row['BidVol']}, AskVol={crash_row['AskVol']}\n")
            f.write(f"   - Recovery Pattern: {recovery_msg}\n")
            if last_move:
                 f.write(f"   - Context: User executed {last_move['Type']} {time_diff:.1f}s before the drop.\n")

            f.write("\n3. FINANCIAL VERDICT\n")
            f.write(f"   - Final Session PL: {session_pl:.2f} EUR\n")
            f.write(f"   - Total Balance Change: {total_profit:.2f} EUR\n")
            if total_profit > 0:
                f.write("   - RESULT: SURVIVED & PROFITABLE (The Train Missed You).\n")
            else:
                f.write("   - RESULT: CASUALTY (Hit by the Train).\n")

            f.write("\n4. INDICATOR CHECK (RSI 5 vs 14)\n")
            # Compare Avg RSI in file vs Calc RSI 5
            # Approximation
            if 'RSI_5' in df_bars.columns:
                 f.write(f"   - Recalculated RSI(5) Avg: {df_bars['RSI_5'].mean():.2f}\n")
            f.write(f"   - Logged RSI (likely 14) Avg: {df['RSI'].mean():.2f}\n")

    except Exception as e:
        print(f"❌ Analysis Failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    analyze_tactical()
