import pandas as pd
import numpy as np
import sys
import os

def apply_copilot_triple_barrier(filepath, output_path, tp_barrier=1.5, sl_barrier=1.0, max_time_minutes=15, dynamic_atr=False):
    print(f"⏳ Aszimmetrikus Címkézés indul: {filepath}")
    if dynamic_atr:
        print(f"Célpont: Dinamikus ATR * {tp_barrier}. Stop: Dinamikus ATR * {sl_barrier}. Időkorlát: {max_time_minutes} perc.")
    else:
        print(f"Célpont (Fix): {tp_barrier} pont. Visszaesés (Stop): {sl_barrier} pont. Időkorlát: {max_time_minutes} perc.")

    df = pd.read_csv(filepath)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    if 'End_Timestamp' in df.columns:
        df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])

    labels = np.zeros(len(df))

    # Extract arrays for fast iteration
    close_prices = df['Close'].values
    high_prices = df['High'].values
    low_prices = df['Low'].values
    timestamps = df['Start_Timestamp'].values

    if dynamic_atr and 'ATR_Proxy' in df.columns:
        atr_values = df['ATR_Proxy'].values
    else:
        atr_values = np.ones(len(df)) # Fallback, no scaling

    # 15 perces időkorlát milliszekundumban
    max_time_ns = max_time_minutes * 60 * 1e9

    success_long = 0
    success_short = 0
    timeout_noise = 0

    for i in range(len(df)):
        start_time = timestamps[i]
        start_price = close_prices[i]

        current_tp = tp_barrier * atr_values[i] if dynamic_atr else tp_barrier
        current_sl = sl_barrier * atr_values[i] if dynamic_atr else sl_barrier

        # Aszimmetrikus határok (LONG esetre)
        long_upper_barrier = start_price + current_tp
        long_lower_barrier = start_price - current_sl

        # Aszimmetrikus határok (SHORT esetre)
        short_lower_barrier = start_price - current_tp
        short_upper_barrier = start_price + current_sl

        label = 0 # Default: Zaj / Holttér

        # Jövőbeli iteráció
        for j in range(i + 1, len(df)):
            future_time = timestamps[j]
            future_high = high_prices[j]
            future_low = low_prices[j]

            # Időkorlát ellenőrzés
            if (future_time - start_time).astype('timedelta64[ns]').astype(float) > max_time_ns:
                break # Kifutottunk az időből, marad a 0

            # LONG ESET VIZSGÁLATA (Path dependency javítva: High/Low vizsgálat)
            hit_long_tp = future_high >= long_upper_barrier
            hit_long_sl = future_low <= long_lower_barrier

            # SHORT ESET VIZSGÁLATA (Path dependency javítva: High/Low vizsgálat)
            hit_short_tp = future_low <= short_lower_barrier
            hit_short_sl = future_high >= short_upper_barrier

            # Logikai Döntés: Melyik ütődik ki előbb?
            # Ha egyetlen bar alatt (Whipsaw) mind a stop, mind a TP kiütődik, az túl kockázatos -> Zaj (0)
            if hit_long_tp and hit_long_sl:
                label = 0
                break
            elif hit_short_tp and hit_short_sl:
                label = 0
                break

            # Ha tiszta találat van:
            if hit_long_tp:
                label = 1
                break
            elif hit_short_tp:
                label = -1
                break

            # Ha tiszta Stop Loss találat van:
            if hit_long_sl or hit_short_sl:
                label = 0
                break

        labels[i] = label

        if label == 1: success_long += 1
        elif label == -1: success_short += 1
        else: timeout_noise += 1

    df['Target_Label'] = labels

    print("\n✅ Címkézés Kész!")
    print(f"📈 Tiszta Long (+1): {success_long} db")
    print(f"📉 Tiszta Short (-1): {success_short} db")
    print(f"⚪ Kipattintás/Zaj (0): {timeout_noise} db")

    df.to_csv(output_path, index=False)
    print(f"💾 Címkézett adatok elmentve: {output_path}")
    return df

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv')
    parser.add_argument('--tp', type=float, default=1.5, help='Take Profit Barrier')
    parser.add_argument('--sl', type=float, default=1.0, help='Stop Loss Barrier')
    parser.add_argument('--dynamic_atr', action='store_true', help='Use ATR proxy scaling for barriers')
    parser.add_argument('--output_file', default=None, help='Kimeneti file neve')

    args = parser.parse_args()

    output_file = args.output_file
    if not output_file:
        output_dir = os.path.dirname(args.input_file)
        output_file = os.path.join(output_dir, 'labeled_dollar_bars.csv')

    apply_copilot_triple_barrier(args.input_file, output_file, tp_barrier=args.tp, sl_barrier=args.sl, dynamic_atr=args.dynamic_atr)
