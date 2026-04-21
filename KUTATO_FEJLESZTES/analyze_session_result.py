import pandas as pd
import numpy as np

CSV_FILE = "Mimic_Research_GOLD_20260202_054225.csv"

def analyze_session():
    print(f"🕵️ Analyzing {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)

        # 1. Overview
        start_time = df['Time'].iloc[0]
        end_time = df['Time'].iloc[-1]
        total_rows = len(df)

        # 2. P/L Analysis
        final_pl = df['Session_PL'].iloc[-1]
        max_dd = df['Floating_PL'].min()
        max_runup = df['Floating_PL'].max()

        # 3. Trade Count (Parsing ActionDetails)
        # Look for "OPEN" and "CLOSE" tags in ActionDetails
        opens = df[df['ActionDetails'].str.contains(':OPEN:', na=False)]
        closes = df[df['ActionDetails'].str.contains(':CLOSE:', na=False)]

        total_trades_opened = len(opens)
        total_trades_closed = len(closes)

        # 4. Data Quality Check (ML Readiness)
        null_rsi = df['RSI'].isnull().sum()
        null_bars = df['Bar_Close'].isnull().sum()
        unique_bidvol = df['BidVol'].nunique()

        # 5. Volatility / Whale Hunt
        avg_spread = df['Spread'].mean()
        max_spread = df['Spread'].max()

        print("\n📊 === COLOMBO REPORT: SESSION SUMMARY ===")
        print(f"⏱️ Timeframe: {start_time} -> {end_time} ({total_rows} ticks)")
        print(f"💰 Session Result (Realized): {final_pl:.2f} EUR")
        print(f"🌊 Floating Dynamics: Low: {max_dd:.2f} | High: {max_runup:.2f}")
        print(f"🔫 Activity: Opened {total_trades_opened} | Closed {total_trades_closed}")

        print("\n🤖 === ML DATA QUALITY ===")
        print(f"✅ RSI Present: {total_rows - null_rsi}/{total_rows}")
        print(f"✅ Bar Data Present: {total_rows - null_bars}/{total_rows}")
        print(f"✅ Liquidity Depth: {unique_bidvol} unique volume levels detected.")
        print(f"📉 Average Spread: {avg_spread:.2f} pts")

        # 6. Detailed Trade Analysis (Forensic)
        if total_trades_closed > 0:
            print("\n🔍 === CRIME SCENE (TRADES) ===")
            # Extract PL from close strings?
            # Format: ...:PL=12.50
            # Let's simple parse the ActionDetails column for PL=
            pl_strings = closes['ActionDetails'].str.extract(r'PL=([-+]?\d*\.\d+|\d+)').astype(float)
            winners = pl_strings[pl_strings[0] > 0].count().iloc[0]
            losers = pl_strings[pl_strings[0] <= 0].count().iloc[0]
            print(f"🏆 Winners: {winners}")
            print(f"💀 Losers: {losers}")
            if winners + losers > 0:
                print(f"🎯 Win Rate: {winners / (winners+losers) * 100:.1f}%")

    except Exception as e:
        print(f"❌ Analysis Failed: {e}")

if __name__ == "__main__":
    analyze_session()
