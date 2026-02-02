import pandas as pd
import numpy as np

CSV_FILE = "Mimic_Research_GOLD_20260202_054225.csv"

def analyze_coach():
    print(f"🎓 Starting Grandmaster Coaching Session on {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)
        df['Time'] = pd.to_datetime(df['Time'])

        # --- 1. Parse Trades & Timing ---
        closes = df[df['ActionDetails'].str.contains(':CLOSE:', na=False)].copy()

        # Extract Ticket IDs to link Open/Close (Approximate by matching sequence if needed, but here simplified)
        # We need to find the "Ride" for each trade to calculate MAE/MFE.
        # Format: "T#12345:CLOSE:..."
        closes['Ticket'] = closes['ActionDetails'].str.extract(r'T#(\d+):').astype(str)
        closes['PL'] = closes['ActionDetails'].str.extract(r'PL=([-+]?\d*\.\d+|\d+)').astype(float)

        # Since we don't have per-ticket tick history in CSV easily without complex parsing,
        # we will use global "Floating_PL" behavior around the trade time as a proxy for the session "Luck".

        # --- 2. Calculate "Luck" (Adverse Excursion) ---
        # For the whole session, what was the Max Drawdown relative to the Balance?
        # A high drawdown that ends in profit implies "Lucky Recovery".
        min_floating = df['Floating_PL'].min()
        max_floating = df['Floating_PL'].max()
        final_profit = df['Session_PL'].iloc[-1]

        # Luck Ratio: How much pain did we endure to get this gain?
        # Ideal: Low Pain (High Min Floating), High Gain.
        pain_to_gain = abs(min_floating) / final_profit if final_profit > 0 else 999

        # --- 3. Hesitation (Entry Velocity) ---
        # Did we enter when velocity was already dying down?
        # Filter for OPEN actions
        opens = df[df['ActionDetails'].str.contains(':OPEN:', na=False)]
        avg_entry_velocity = opens['Velocity'].abs().mean()
        avg_session_velocity = df['Velocity'].abs().mean()

        hesitation_ratio = avg_entry_velocity / avg_session_velocity if avg_session_velocity > 0 else 0
        # If Ratio > 1.5 -> We enter on strong moves (Good).
        # If Ratio < 1.0 -> We enter on noise (Bad/Hesitant).

        # --- 4. Generate Coaching Report ---
        print("\n🎓 === COACHING REPORT: THE TRADER'S PSYCHOLOGY ===")

        print(f"\n1. LUCK FACTOR (Pain vs Gain):")
        print(f"   - Max Pain (Floating DD): {min_floating:.2f} EUR")
        print(f"   - Final Gain: {final_profit:.2f} EUR")
        print(f"   - Ratio: {pain_to_gain:.2f}")
        if pain_to_gain > 1.5:
            print("   ⚠️ DIAGNOSIS: 'Rollercoaster'. You endured too much drawdown for this profit. You were lucky the market turned back.")
        elif pain_to_gain < 0.5:
             print("   ✅ DIAGNOSIS: 'Sniper'. Minimal pain, surgical profit. Excellent entry timing.")
        else:
             print("   ℹ️ DIAGNOSIS: 'Grinder'. Standard risk/reward profile.")

        print(f"\n2. HESITATION (Entry Timing):")
        print(f"   - Avg Entry Velocity: {avg_entry_velocity:.4f}")
        print(f"   - Avg Market Velocity: {avg_session_velocity:.4f}")
        print(f"   - Aggression Ratio: {hesitation_ratio:.2f}")
        if hesitation_ratio < 1.0:
            print("   ⚠️ DIAGNOSIS: 'Hesitant'. You enter when the move is weak or fading. Be more aggressive!")
        else:
            print("   ✅ DIAGNOSIS: 'Decisive'. You hit the market when it's moving fast.")

        # --- 5. "Table Money" (Greed/Fear) ---
        # Did the trend continue after we closed?
        # We look at 'Session_PL' vs 'Floating_PL' peaks.
        # If Floating PL reached X but we closed at 0.5*X, we left money on the table.
        max_seen_floating = df['Floating_PL'].max()
        # Note: Session PL is realized. Floating is unrealized.
        # This is hard to exact without per-trade MFE, but globally:
        # Did we close near the "High Water Mark" of floating PL?
        # No, Floating PL resets.
        # Let's check Close events PL vs Max Floating of that timeframe.
        # Simplified: We closed 95k. Max Floating was 80k (positive).
        # Wait, if Max Floating was 80k and we realized 95k, we captured it well.
        # If Max Floating was 200k and we realized 95k, we panicked.

        print(f"\n3. GREED/FEAR (Exit Efficiency):")
        print(f"   - Max Floating Profit Seen: {max_runup_proxy(df):.2f} EUR")
        print(f"   - Actual Realized Profit: {final_profit:.2f} EUR")

    except Exception as e:
        print(f"❌ Analysis Failed: {e}")

def max_runup_proxy(df):
    # Simple proxy: Max value of Floating PL during the session
    return df['Floating_PL'].max()

if __name__ == "__main__":
    analyze_coach()
