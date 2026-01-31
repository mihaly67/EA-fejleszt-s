import pandas as pd
import numpy as np
import sys
import os

# --- CONFIGURATION ---
SPREAD_POINTS_RAW = 66.0
SPREAD_PRICE_VALUE = 0.66 # SP500 2-digit: 66 points = 0.66 price change
POINT_VALUE_HUF = 73900.0 # Approx 1 Lot SP500 value in HUF (User provided)

def analyze_chess_match(file_path):
    print(f"🕵️‍♂️ --- COLOMBO CHESS MATCH FORENSIC ANALYSIS ---")
    print(f"File: {file_path}")

    try:
        # Load Data
        df = pd.read_csv(file_path)

        # Clean timestamps
        df['Time'] = pd.to_datetime(df['Time'])

        # Calculate Delta Time in Seconds
        df['DeltaTime'] = df['Time'].diff().dt.total_seconds().fillna(0)

    except Exception as e:
        print(f"❌ CRITICAL ERROR: Could not read CSV. {e}")
        return

    # --- 1. ENTRY LOGIC VERIFICATION (The "Machine Gun" Check) ---
    print("\n🔍 1. VIZSGÁLAT: BELÉPÉSI LOGIKA (Géppuska vs Lépcső)")

    # Filter rows where Position Count changed (Entry/Exit)
    # Since PosCount is reliable in v1.00
    df['PosChange'] = df['PosCount'].diff()
    entries = df[df['PosChange'] > 0].copy()

    entry_report = []

    print(f"Összes észlelt belépés: {len(entries)}")

    if len(entries) > 0:
        prev_entry_price = entries.iloc[0]['Bid'] # Approximate

        for idx, row in entries.iterrows():
            curr_price = row['Bid']
            time_diff = 0
            price_diff = 0

            if idx > entries.index[0]:
                 # Find previous entry in the filtered list
                 prev_row = entries.loc[:idx-1].iloc[-1]
                 time_diff = (row['Time'] - prev_row['Time']).total_seconds()
                 price_diff = abs(curr_price - prev_row['Bid'])

            # Distance in "Spreads"
            # Bugfix: Use Price Value of Spread (0.66) not Raw Points (66.0)
            dist_in_spreads = price_diff / SPREAD_PRICE_VALUE

            # Verdict
            verdict = "OK"
            if time_diff < 0.1 and idx > entries.index[0]: verdict = "MACHINE_GUN (Instant)"
            elif dist_in_spreads < 0.8 and idx > entries.index[0]: verdict = "PREMATURE (Too Close)"
            elif dist_in_spreads > 1.2 and idx > entries.index[0]: verdict = "GAP (Skipped Level)"

            entry_report.append({
                "Time": row['Time'],
                "Price": curr_price,
                "Diff_Pts": price_diff,
                "Diff_Spread": dist_in_spreads,
                "Time_Gap": time_diff,
                "Verdict": verdict,
                "Action": row['LastEvent'] if pd.notna(row['LastEvent']) else "TickEntry"
            })

    entry_df = pd.DataFrame(entry_report)
    print(entry_df[['Time', 'Diff_Spread', 'Time_Gap', 'Verdict']].to_string())

    # --- 2. BROKER BEHAVIOR (The "Steamroll" Check) ---
    print("\n🔍 2. VIZSGÁLAT: BRÓKER VISELKEDÉS (Gőzhenger)")

    # Check Velocity during entries
    avg_entry_vel = entries['Velocity'].abs().mean()
    avg_session_vel = df['Velocity'].abs().mean()

    print(f"Átlagos Sebesség Belépéskor: {avg_entry_vel:.4f}")
    print(f"Átlagos Sebesség Szekcióban: {avg_session_vel:.4f}")

    if avg_entry_vel > avg_session_vel * 1.5:
        print("⚠️  DIAGNÓZIS: MOMENTUM ENTRY. A bróker belehúzza az árat a megbízásokba.")
    else:
         print("ℹ️  DIAGNÓZIS: PASSZÍV FOLYAM. A megbízások 'sima' piaci mozgásban teljesültek.")

    # --- 3. MARGIN & RISK RECONSTRUCTION ---
    print("\n🔍 3. VIZSGÁLAT: TŐKE MENEDZSMENT (Rekonstrukció)")

    max_pos = df['PosCount'].max()
    max_dd_eur = df['Floating_PL'].min()

    # Estimate Margin Load (Hypothetical)
    # Assuming standard SP500 contract specs if not provided, but we assume 1 Lot = User Value
    # This is a rough heuristic for the Python module

    print(f"Max Pozíció Szám: {max_pos}")
    print(f"Max Lebegő Veszteség: {max_dd_eur:.2f} EUR")

    # --- OUTPUT REPORT ---
    report_file = "Colombo_Huron_Research_Archive/Chess_Match_Report_SP500.md"
    with open(report_file, "w", encoding="utf-8") as f:
        f.write(f"# Colombo Jelentés: A Sakkjátszma (SP500 Forensic)\n")
        f.write(f"**Dátum:** {df['Time'].iloc[0].strftime('%Y-%m-%d')}\n")
        f.write(f"**Eszköz:** SP500 (V1.00 Elemzés)\n\n")

        f.write(f"## 1. A Belépések Ritmusának Elemzése\n")
        f.write(f"A vizsgálat célja annak eldöntése volt, hogy a rendszer tartotta-e a lépcsőzetes (Spread-alapú) belépést, vagy a bróker 'szétlőtte' a pozíciókat.\n\n")
        f.write(entry_df[['Time', 'Price', 'Diff_Spread', 'Time_Gap', 'Verdict']].to_markdown())

        f.write(f"\n\n## 2. A Bróker Reakciója\n")
        f.write(f"*   **Átlagos Sebesség (Belépéskor):** {avg_entry_vel:.4f}\n")
        f.write(f"*   **Átlagos Sebesség (Nyugalom):** {avg_session_vel:.4f}\n")
        if avg_entry_vel > avg_session_vel * 1.5:
             f.write(f"**Konklúzió:** A bróker agresszíven, lendületből (Momentum) ütötte ki a szinteket. Nem volt 'megtorpanás'.\n")
        else:
             f.write(f"**Konklúzió:** A bróker passzív volt, a piac egyszerűen 'átcsorgott' a szinteken.\n")

        f.write(f"\n## 3. Pénzügyi Rekonstrukció (Python Engine Számára)\n")
        f.write(f"*   **Max Open Positions:** {max_pos}\n")
        f.write(f"*   **Max Drawdown:** {max_dd_eur:.2f} EUR\n")

    print(f"\n✅ Jelentés generálva: {report_file}")

if __name__ == "__main__":
    analyze_chess_match("Colombo_Huron_Research_Archive/Mimic_Probe_WIRE_SP500_CLEANED.csv")
