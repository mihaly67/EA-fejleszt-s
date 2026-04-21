import pandas as pd
import numpy as np

CSV_FILE = "Mimic_Research_GOLD_20260202_054225.csv"

def analyze_chess_match():
    print(f"♟️ Starting Chess Engine Analysis on {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)

        # --- 1. Preprocessing (The Board) ---
        # Convert Time
        df['Time'] = pd.to_datetime(df['Time'])

        # Calculate Returns (for Sharpe/Sortino)
        # We use Floating_PL delta as a proxy for "Equity Curve" changes per tick
        df['Equity'] = df['Balance'] + df['Session_PL'] # realized so far
        # But wait, Floating PL is the unrealized.
        # Total Equity = Balance + Floating_PL (if we want to see the ride)
        # Actually, let's look at "Realized PL" curve for closed trades.

        # Parsing Trades (The Moves)
        closes = df[df['ActionDetails'].str.contains(':CLOSE:', na=False)].copy()

        # Extract Trade PL
        # Format: "...:PL=12.50"
        closes['Trade_PL'] = closes['ActionDetails'].str.extract(r'PL=([-+]?\d*\.\d+|\d+)').astype(float)

        # --- 2. Blunder Detection (Our Mistakes) ---
        # A blunder is a big loss or a missed win.
        # Since we have 95% WR, blunders are rare. Let's look at the Losers.
        blunders = closes[closes['Trade_PL'] <= 0]

        # --- 3. Opponent Analysis (Broker Defense) ---
        # Did the spread widen during our trades?
        # Filter rows where we had open positions
        active_rows = df[df['PosCount'] > 0]
        avg_spread_active = active_rows['Spread'].mean()
        avg_spread_idle = df[df['PosCount'] == 0]['Spread'].mean()

        defense_ratio = avg_spread_active / avg_spread_idle if avg_spread_idle > 0 else 0

        # --- 4. Game Score (Metrics) ---
        total_profit = closes['Trade_PL'].sum()
        win_rate = len(closes[closes['Trade_PL'] > 0]) / len(closes) * 100 if len(closes) > 0 else 0

        # Sharpe (Approximate based on trade returns)
        # mean_return / std_dev
        returns = closes['Trade_PL']
        sharpe = (returns.mean() / returns.std()) if len(returns) > 1 and returns.std() > 0 else 0

        # Sortino (Downside risk only)
        downside = returns[returns < 0]
        sortino = (returns.mean() / downside.std()) if len(downside) > 0 and downside.std() > 0 else 0
        if len(downside) == 0: sortino = 999.0 # Infinite/Perfect

        # --- 5. Generate Report ---
        print("\n🏆 === CHESS MATCH REPORT: JULES vs BROKER ===")
        print(f"📈 Total Score (Profit): {total_profit:.2f} EUR")
        print(f"🎯 Accuracy (Win Rate): {win_rate:.1f}%")

        print(f"\n🧠 Tactical Analysis (Metrics):")
        print(f"   - Sharpe Ratio: {sharpe:.2f} (Consistency)")
        print(f"   - Sortino Ratio: {sortino:.2f} (Downside Safety)")
        print(f"   - Blunders (Losses): {len(blunders)}")

        print(f"\n🛡️ Opponent Defense (Broker):")
        print(f"   - Spread (Idle): {avg_spread_idle:.2f} pts")
        print(f"   - Spread (Active): {avg_spread_active:.2f} pts")
        if defense_ratio > 1.1:
            print(f"   ⚠️ DEFENSE DETECTED: Broker widened spread by {(defense_ratio-1)*100:.1f}% during active trades!")
        else:
            print(f"   ✅ PASSIVE: Broker did not react significantly (Ratio: {defense_ratio:.2f})")

        print("\n🔮 Conclusion:")
        if win_rate > 90 and defense_ratio < 1.1:
            print("   The opponent was asleep. We checkmated them in the opening.")
        elif win_rate > 50:
            print("   A hard-fought game. We won on material.")
        else:
            print("   The opponent anticipated our moves.")

    except Exception as e:
        print(f"❌ Analysis Failed: {e}")

if __name__ == "__main__":
    analyze_chess_match()
