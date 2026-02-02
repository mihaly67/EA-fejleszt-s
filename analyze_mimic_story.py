import pandas as pd
import numpy as np

CSV_FILE = "Mimic_Research_GOLD_20260202_054225.csv"

def analyze_mimic_story():
    print(f"🕵️‍♂️ Starting Colombo Story Engine on {CSV_FILE}...")

    try:
        df = pd.read_csv(CSV_FILE)
        df['Time'] = pd.to_datetime(df['Time'])

        # --- 1. Event Stream Construction ---
        events = []

        # A. Trade Events (ActionDetails)
        # Parse: "T#...:OPEN:..."
        trade_rows = df[df['ActionDetails'].str.contains(':', na=False)]
        for idx, row in trade_rows.iterrows():
            actions = row['ActionDetails'].split('|')
            for action in actions:
                if 'OPEN' in action:
                    events.append({
                        'Time': row['Time'],
                        'Actor': 'Jules',
                        'Type': 'ATTACK',
                        'Description': f"Opened Fire (Trade). Velocity: {row['Velocity']:.1f}",
                        'Data': action
                    })
                elif 'CLOSE' in action:
                    pl = action.split('PL=')[1] if 'PL=' in action else '0'
                    events.append({
                        'Time': row['Time'],
                        'Actor': 'Jules',
                        'Type': 'RETREAT' if float(pl) < 0 else 'BANK',
                        'Description': f"Closed Position. Profit: {pl} EUR",
                        'Data': action
                    })

        # B. Broker Defense Events (Spread/Volume)
        # We need to detect "Spikes"
        # Rolling average for baseline
        df['Spread_MA'] = df['Spread'].rolling(window=50).mean()
        df['Spread_Spike'] = df['Spread'] > (df['Spread_MA'] * 1.2) # 20% spike

        # Find start of spikes
        spike_starts = df[df['Spread_Spike'] & ~df['Spread_Spike'].shift(1).fillna(False)]
        for idx, row in spike_starts.iterrows():
            events.append({
                'Time': row['Time'],
                'Actor': 'Broker',
                'Type': 'SHIELD',
                'Description': f"Raised Shields! Spread widened to {row['Spread']:.1f} (Avg: {row['Spread_MA']:.1f})",
                'Data': f"Spread {row['Spread']}"
            })

        # C. Market Context (Phase Shifts)
        # Velocity shifts
        df['Vel_Abs'] = df['Velocity'].abs()
        df['Vel_MA'] = df['Vel_Abs'].rolling(window=50).mean()
        high_volatility = df[df['Vel_Abs'] > 60]
        # Just grab a few key volatility moments to avoid spam
        # Simplified: Every 5 minutes, report status

        # --- 2. Sort & Narrate ---
        events_df = pd.DataFrame(events)
        if not events_df.empty:
            events_df = events_df.sort_values(by='Time')

        print("\n📜 === THE COLOMBO CHRONICLES ===")
        print(f"DATE: {df['Time'].iloc[0].date()}")
        print("--------------------------------------------------")

        current_balance = df['Balance'].iloc[0]

        for idx, event in events_df.iterrows():
            time_str = event['Time'].strftime("%H:%M:%S")
            actor = event['Actor']
            desc = event['Description']

            icon = "👤" if actor == "Jules" else "🏦"
            if event['Type'] == 'ATTACK': icon = "🔫"
            if event['Type'] == 'BANK': icon = "💰"
            if event['Type'] == 'SHIELD': icon = "🛡️"

            print(f"[{time_str}] {icon} {actor}: {desc}")

        print("--------------------------------------------------")
        print(f"FINAL RESULT: {df['Session_PL'].iloc[-1]:.2f} EUR")

    except Exception as e:
        print(f"❌ Story Engine Failed: {e}")

if __name__ == "__main__":
    analyze_mimic_story()
