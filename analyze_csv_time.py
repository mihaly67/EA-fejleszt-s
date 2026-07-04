import pandas as pd
import numpy as np

def analyze_time_deltas(csv_path):
    print(f"--- CSV Időbélyeg (TimeMsc) Elemzés: {csv_path} ---")
    df = pd.read_csv(csv_path)

    # Kivonjuk a TimeMsc oszlopból az előző sor TimeMsc értékét, hogy megkapjuk a tickek közötti időt milliszekundumban
    df['DeltaMsc'] = df['TimeMsc'].diff()

    # 1. Alapstatisztikák
    total_ticks = len(df)
    zeros = len(df[df['DeltaMsc'] == 0])
    print(f"\nÖsszes Tick: {total_ticks}")
    print(f"Ebből 0 ms delta (ugyanabban a milliszekundumban jött): {zeros} db ({zeros/total_ticks*100:.2f}%)")

    # 2. Megnézzük a valós időközöket (>0 ms)
    valid_deltas = df[df['DeltaMsc'] > 0]['DeltaMsc']
    print("\nPozitív idő-delták statisztikája (ms):")
    print(valid_deltas.describe())

    # 3. Anomáliák (Ugrások) vizsgálata
    jumps = df[df['DeltaMsc'] > 5000] # 5 másodpercnél nagyobb ugrások
    print(f"\nÓriási ugrások (> 5 másodperc szünet): {len(jumps)} db")
    if len(jumps) > 0:
        print(jumps[['TimeMsc', 'DeltaMsc']].head(10))

    # 4. Rövid minták különböző helyekről
    print("\n--- Minta az ELSŐ 15 tickből ---")
    print(df[['TimeMsc', 'DeltaMsc']].head(15))

    print(f"\n--- Minta KÖZÉPRŐL (Index: {total_ticks//2}) ---")
    print(df[['TimeMsc', 'DeltaMsc']].iloc[total_ticks//2 : total_ticks//2 + 15])

    print("\n--- Minta a VÉGÉRŐL ---")
    print(df[['TimeMsc', 'DeltaMsc']].tail(15))

if __name__ == "__main__":
    analyze_time_deltas("/home/misi/Merkava_ML_Ops/data/raw/DOM_Data.csv")
