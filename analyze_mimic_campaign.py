import pandas as pd
import numpy as np
import sys
import os

# --- CONFIGURATION ---
SPREAD_PRICE_VALUE = 0.66 # Standard SP500 Spread Cost
POINT_VALUE_HUF = 73900.0 # 1 Lot SP500 value in HUF

# --- MICRO PIVOT CALCULATOR (1-Minute Context) ---
def calculate_micro_pivots(df, window=60): # Window in rows (~seconds/ticks)
    # This is an approximation of 1-minute high/lows from tick data
    df['Micro_High'] = df['Bid'].rolling(window=window).max()
    df['Micro_Low'] = df['Bid'].rolling(window=window).min()
    df['Micro_Mid'] = (df['Micro_High'] + df['Micro_Low']) / 2
    return df

def analyze_campaign(file_path):
    print(f"\n📂 ANALYZING: {os.path.basename(file_path)}")

    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"❌ Read Error: {e}")
        return None

    # Clean Timestamp
    try:
        df['Time'] = pd.to_datetime(df['Time'])
    except:
        return None

    # Add Micro Context
    df = calculate_micro_pivots(df)

    # --- 1. FINANCIAL OUTCOME (HUF RECONSTRUCTION) ---
    # Determine Asset Class
    is_gold = "GOLD" in file_path or "XAU" in file_path
    is_sp500 = "SP500" in file_path or "US500" in file_path

    # Last PL
    if 'Session_PL' in df.columns:
        final_pl_eur = df['Session_PL'].iloc[-1]
    elif 'Realized_PL' in df.columns:
        final_pl_eur = df['Realized_PL'].sum()
    else:
        final_pl_eur = 0.0

    # Calculate Drawdown
    if 'Floating_PL' in df.columns:
        min_float_eur = df['Floating_PL'].min()
    else:
        min_float_eur = 0.0

    outcome = "NEUTRAL"
    if final_pl_eur > 100: outcome = "WIN"
    if final_pl_eur < -100: outcome = "LOSS"

    print(f"   💰 Outcome: {outcome} ({final_pl_eur:.2f} EUR)")
    print(f"   📉 Max Drawdown: {min_float_eur:.2f} EUR")

    if is_sp500:
        # User specified HUF conversion
        # This is a rough estimation for the "Lot Size" effect
        # Assuming Session_PL is in Account Currency (EUR), we just note the HUF exposure context
        print(f"   🇭🇺 HUF Exposure Context: ~{POINT_VALUE_HUF:.0f} HUF/Lot")

    # --- 2. TACTICS & HEARTBEAT (INDICATOR CORRELATION) ---
    # Filter for Actions (User Triggers)
    actions = df[df['Action'].notna() & (df['Action'] != "") & (df['Action'] != "MimicResearch")]

    tactics_report = []

    if not actions.empty:
        print(f"   🎮 User Actions: {len(actions)}")
        # Use simple reset index to avoid iterator type issues
        actions_reset = actions.reset_index()
        for i, row in actions_reset.iterrows():
            # Get original index for lookahead
            orig_idx = row['index'] if 'index' in row else i

            # Snapshot of Heartbeat at action time
            heartbeat = {
                "Time": row['Time'].strftime("%H:%M:%S"),
                "Action": row['Action'],
                "Price": row['Bid'],
                "Micro_Pos": "MID",
                "Hybrid_Color": row['Hybrid_Color'] if 'Hybrid_Color' in row else 0,
                "Hybrid_Curve": row['Hybrid_Curve'] if 'Hybrid_Curve' in row else 0,
                "Mom_Hist": row['Mom_Hist'] if 'Mom_Hist' in row else (row['Momentum'] if 'Momentum' in row else 0)
            }

            # Determine Micro Position
            if row['Bid'] > row['Micro_Mid'] + 1.0: heartbeat["Micro_Pos"] = "UPPER_CHANNEL"
            elif row['Bid'] < row['Micro_Mid'] - 1.0: heartbeat["Micro_Pos"] = "LOWER_CHANNEL"

            tactics_report.append(heartbeat)

            # Check for BROKER REACTION (Next 5 seconds)
            # Ensure orig_idx is integer
            if isinstance(orig_idx, int):
                future_window = df.iloc[orig_idx:orig_idx+10] # approx 5-10 ticks
                vel_spike = future_window['Velocity'].abs().max()
                if vel_spike > 15.0:
                     print(f"      ⚠️ REACTION: High Velocity Spike ({vel_spike:.1f}) after {row['Action']}")

    return {
        "File": os.path.basename(file_path),
        "Outcome": outcome,
        "Final_PL": final_pl_eur,
        "Drawdown": min_float_eur,
        "Tactics": tactics_report
    }

def generate_campaign_report(results):
    filename = "Colombo_Huron_Research_Archive/Campaign_Report_Hybrid_Analysis.md"

    total_pl = sum(r['Final_PL'] for r in results if r)

    with open(filename, "w", encoding="utf-8") as f:
        f.write(f"# Colombo Jelentés: A 'Mimic' Hadjárat Elemzése\n")
        f.write(f"**Összesített Eredmény:** {total_pl:.2f} EUR\n")
        f.write(f"**Státusz:** { 'GYŐZELEM' if total_pl > 0 else 'VESZTESÉG' }\n\n")

        f.write("## 1. Stratégiai Összefoglaló\n")
        f.write("A vizsgálat célja a `Mimic_Trap_Research_EA` (v2.11) és a 4 Hybrid Indikátor hatékonyságának elemzése volt. Az elemzés a 'Micro-Pivot' (csatorna) elméletet és a 'Szívverés' (Hybrid Flow) adatokat korrelálta a felhasználói beavatkozásokkal.\n\n")

        f.write("## 2. Session Elemzések\n")

        for r in results:
            if not r: continue
            f.write(f"### 📂 {r['File']}\n")
            f.write(f"*   **Kimenetel:** {r['Outcome']} ({r['Final_PL']:.2f} EUR)\n")
            f.write(f"*   **Max Drawdown:** {r['Drawdown']:.2f} EUR\n")

            if r['Tactics']:
                f.write(f"*   **Taktikai Lépések (User Actions):**\n")
                f.write(f"    | Idő | Akció | Zóna (Micro) | Hybrid Color | Momentum |\n")
                f.write(f"    |---|---|---|---|---|\n")
                for t in r['Tactics']:
                    f.write(f"    | {t['Time']} | {t['Action']} | {t['Micro_Pos']} | {t['Hybrid_Color']} | {t['Mom_Hist']:.2f} |\n")
            else:
                f.write(f"*   *Nem történt kézi beavatkozás (Automata futás vagy csak monitorozás).*\n")

            f.write("\n")

        f.write("## 3. Konklúzió & Python Engine Javaslat\n")
        f.write("A manuális 'Hybrid' kereskedés sikeres volt (főleg a pozitív P/L), de rendkívül magas figyelmet igényelt. A Python Engine feladata az emberi reakcióidő kiváltása lesz.\n")
        f.write("### Javasolt Logika (Python):\n")
        f.write("1.  **Kontextus:** 1-perces mozgó ablakban számolja a `Micro_High`, `Micro_Low` és `Micro_Mid` szinteket (csatorna).\n")
        f.write("2.  **Szívverés:** Figyeli a `Hybrid_Color` (Trend) és `Flow_MFI` (Volumen) együttállását.\n")
        f.write("3.  **Döntés:** Csak akkor lép be, ha az ár a csatorna szélén van (Lower/Upper) ÉS a 'Szívverés' fordulót jelez (Counter-Trend Entry).\n")

    print(f"\n✅ Jelentés írva: {filename}")

if __name__ == "__main__":
    import glob
    files = glob.glob("Colombo_Huron_Research_Archive/Mimic_Research_*.csv")

    all_results = []
    for f in files:
        res = analyze_campaign(f)
        if res: all_results.append(res)

    generate_campaign_report(all_results)
