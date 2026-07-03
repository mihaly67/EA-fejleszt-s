import pandas as pd
import numpy as np

def test_dom_mapping(csv_path, rows=10):
    print(f"--- DOM Mapping Teszt: {csv_path} ---")
    df = pd.read_csv(csv_path).head(rows)

    for idx, row in df.iterrows():
        mid_price = (float(row['Bid']) + float(row['Ask'])) / 2.0

        # 1. Tick size becslése
        tick_size = 0.05
        if float(row['Bid_Price_1']) > 0 and float(row['Ask_Price_1']) > 0:
            tick_size = float(row['Ask_Price_1']) - float(row['Bid_Price_1'])
            if tick_size <= 0: tick_size = 0.05
            if tick_size > 1.0: tick_size = 0.1

        print(f"\n[{idx}] Mid: {mid_price:.5f} | Számított Tick Size: {tick_size:.5f}")

        # 2. Rács (Grid) generálás
        mid_rounded = np.round(mid_price / tick_size) * tick_size
        prices = np.arange(mid_rounded + (5 * tick_size), mid_rounded - (5 * tick_size) - tick_size, -tick_size)
        prices = np.round(prices, 5)
        print(f"Létra Grid: {prices}")

        # 3. Párosítás ellenőrzése
        matches = 0
        for p in prices:
            match = []
            # Laza (0.1) tűréshatár a lebegőpontos egyenlőség helyett
            if abs(p - float(row['Ask_Price_2'])) < (tick_size / 2.0) and float(row['Ask_Vol_2']) > 0: match.append(f"A2({row['Ask_Vol_2']})")
            if abs(p - float(row['Ask_Price_1'])) < (tick_size / 2.0) and float(row['Ask_Vol_1']) > 0: match.append(f"A1({row['Ask_Vol_1']})")
            if abs(p - float(row['Bid_Price_1'])) < (tick_size / 2.0) and float(row['Bid_Vol_1']) > 0: match.append(f"B1({row['Bid_Vol_1']})")
            if abs(p - float(row['Bid_Price_2'])) < (tick_size / 2.0) and float(row['Bid_Vol_2']) > 0: match.append(f"B2({row['Bid_Vol_2']})")

            if match:
                print(f"   -> Rács Ár {p:.5f} KAPOTT VOLUMENT: {match}")
                matches += 1

        if matches == 0:
            print(f"   !!! HIBA: Ezen a ticken EGYETLEN volumen sem tudott ráilleszkedni a rácsra!")
            print(f"       Nyers árak a CSV-ből: A1={row['Ask_Price_1']}, B1={row['Bid_Price_1']}")

if __name__ == "__main__":
    test_dom_mapping("/home/misi/Merkava_ML_Ops/data/raw/DOM_Data.csv", 50)
