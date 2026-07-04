import pandas as pd
import numpy as np

def run_tests():
    file = "/home/misi/Merkava_ML_Ops/data/raw/DOM_Data_20260704_140100.csv"
    print(f"Reading {file}...")
    df = pd.read_csv(file)

    # 1. Alap infók
    print(f"Total rows: {len(df)}")
    if len(df) == 0:
        return

    # 2. Tick size és grid szimuláció 5 mintán a fájlból
    print("\n--- TICK SIZE ÉS GRID SZIMULÁCIÓ ---")
    for idx in range(0, min(1000, len(df)), 100):
        row = df.iloc[idx]
        mid_price = (float(row['Bid']) + float(row['Ask'])) / 2.0

        ap1 = float(row['Ask_Price_1'])
        ap2 = float(row['Ask_Price_2'])
        bp1 = float(row['Bid_Price_1'])
        bp2 = float(row['Bid_Price_2'])

        # Jelenlegi kód logikája
        inferred_tick = 0.0
        if ap2 > 0 and ap1 > 0:
            inferred_tick = round(abs(ap2 - ap1), 5)
        elif bp1 > 0 and bp2 > 0:
            inferred_tick = round(abs(bp1 - bp2), 5)

        if inferred_tick > 0:
            tick_size = inferred_tick
        else:
            if mid_price > 10000: tick_size = 1.0 # BTC
            elif mid_price > 1000: tick_size = 0.1 # Gold
            elif mid_price > 100: tick_size = 0.01 # JPY
            else: tick_size = 0.00001 # EURUSD

        if tick_size < 0.00001: tick_size = 0.00001

        # Dinamikus Viewport szimuláció, hogy szinkronban legyen a fő kóddal
        best_bid = bp1 if bp1 > 0 else mid_price - tick_size
        best_ask = ap1 if ap1 > 0 else mid_price + tick_size

        top_price = best_ask + (10 * tick_size)
        if ap2 > 0: top_price = max(top_price, ap2 + (10 * tick_size))

        bottom_price = best_bid - (10 * tick_size)
        if bp2 > 0: bottom_price = min(bottom_price, bp2 - (10 * tick_size))

        if (top_price - bottom_price) / tick_size > 100:
            tick_size = (top_price - bottom_price) / 50.0

        top_price = np.round(top_price / tick_size) * tick_size
        bottom_price = np.round(bottom_price / tick_size) * tick_size

        prices = np.arange(top_price, bottom_price - tick_size, -tick_size)
        prices = np.round(prices, 5)

        print(f"\nRow {idx} | Mid: {mid_price} | Tick Size: {tick_size} | A1: {ap1}, A2: {ap2}, B1: {bp1}, B2: {bp2}")
        print(f"Generated Grid (Len {len(prices)}): {prices[:5]} ... {prices[-5:]}")

        # Matching teszt (Az új nagyon laza toleranciával, 0.9 * tick_size)
        tolerance = tick_size * 0.9
        matches = 0
        for p in prices:
            match_str = ""
            if abs(p - ap2) < tolerance and float(row['Ask_Vol_2']) > 0: match_str += f"A2({row['Ask_Vol_2']}) "
            if abs(p - ap1) < tolerance and float(row['Ask_Vol_1']) > 0: match_str += f"A1({row['Ask_Vol_1']}) "
            if abs(p - bp1) < tolerance and float(row['Bid_Vol_1']) > 0: match_str += f"B1({row['Bid_Vol_1']}) "
            if abs(p - bp2) < tolerance and float(row['Bid_Vol_2']) > 0: match_str += f"B2({row['Bid_Vol_2']}) "

            if match_str:
                print(f" -> Price {p:.5f} HIT: {match_str}")
                matches += 1

        input_count = sum([1 for v in [float(row['Ask_Vol_1']), float(row['Ask_Vol_2']), float(row['Bid_Vol_1']), float(row['Bid_Vol_2'])] if v > 0])
        if matches == 0 and input_count > 0:
            print(f" [!!!] ELDOBOTT TICK [!!!] Input count volt: {input_count}, Match: 0")

if __name__ == "__main__":
    run_tests()
