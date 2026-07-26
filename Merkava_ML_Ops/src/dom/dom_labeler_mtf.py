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

    close_prices = df['Close'].values
    open_prices = df['Open'].values
    timestamps = df['Start_Timestamp'].values

    if dynamic_atr and 'ATR_Proxy' in df.columns:
        atr_values = df['ATR_Proxy'].values
    else:
        atr_values = np.ones(len(df))

    max_time_ns = max_time_minutes * 60 * 1e9

    success_long = 0
    success_short = 0
    timeout_noise = 0

    for i in range(len(df) - 1): # Az utolsó gyertyánál nincs jövő
        # A belépés szigorúan a JÖVŐBELI (i+1) gyertya Nyitóárán történik
        start_time = timestamps[i+1]
        entry_price = open_prices[i+1]

        current_tp = tp_barrier * atr_values[i] if dynamic_atr else tp_barrier
        current_sl = sl_barrier * atr_values[i] if dynamic_atr else sl_barrier

        long_upper_barrier = entry_price + current_tp
        long_lower_barrier = entry_price - current_sl

        short_lower_barrier = entry_price - current_tp
        short_upper_barrier = entry_price + current_sl

        long_status = 0
        short_status = 0

        for j in range(i + 1, len(df)):
            future_time = timestamps[j]
            future_close = close_prices[j]

            if (future_time - start_time).astype('timedelta64[ns]').astype(float) > max_time_ns:
                # 92-es timeout hiba javítása: Ha lejárt az idő és eddig nem lett státusz, az 0 marad
                break

            # LONG forgatókönyv értékelése
            if long_status == 0:
                if future_close >= long_upper_barrier:
                    long_status = 1
                elif future_close <= long_lower_barrier:
                    long_status = -1

            # SHORT forgatókönyv értékelése
            if short_status == 0:
                if future_close <= short_lower_barrier:
                    short_status = 1
                elif future_close >= short_upper_barrier:
                    short_status = -1

            # KRITIKUS JAVÍTÁS:
            # Ha legalább az EGYIK forgatókönyv SIKERESEN (TP) lezárult, azonnal megállunk!
            # Nem várjuk meg, hogy a jövőben a másik stop is kiütődjön és felülírja a jó jelet.
            if long_status == 1 or short_status == 1:
                break

            # Ha mindkettő forgatókönyv ELBUKOTT (SL), akkor is megállunk.
            if long_status == -1 and short_status == -1:
                break

        # A végső címke megállapítása
        if long_status == 1 and short_status != 1:
            labels[i] = 1
            success_long += 1
        elif short_status == 1 and long_status != 1:
            labels[i] = -1
            success_short += 1
        else:
            labels[i] = 0
            timeout_noise += 1

    df['Target_Label'] = labels

    print("\n✅ Címkézés Kész!")
    print(f"📈 Tiszta Long (+1): {success_long} db")
    print(f"📉 Tiszta Short (-1): {success_short} db")
    print(f"⚪ Zaj/Holttér (0): {timeout_noise} db")

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
