import pandas as pd
import numpy as np

def apply_copilot_triple_barrier(filepath, output_path, target_pts=1.0, cost_pts=0.5, max_time_minutes=15):
    print(f"⏳ Címkézés indul: {filepath}")
    print(f"Célpont: {target_pts} pont, Költség/Slip: {cost_pts} pont. Időkorlát: {max_time_minutes} perc.")

    df = pd.read_csv(filepath)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])

    total_barrier = target_pts + cost_pts
    print(f"Teljes gát mérete (Cél + Költség): {total_barrier} pont")

    labels = np.zeros(len(df))
    close_prices = df['Close'].values
    timestamps = df['Start_Timestamp'].values

    # 15 perces időkorlát milliszekundumban
    max_time_ns = max_time_minutes * 60 * 1e9

    success_long = 0
    success_short = 0
    timeout_noise = 0

    for i in range(len(df)):
        start_time = timestamps[i]
        start_price = close_prices[i]

        upper_barrier = start_price + total_barrier
        lower_barrier = start_price - total_barrier

        label = 0 # Default: Time out (Noise)

        # Look ahead
        for j in range(i + 1, len(df)):
            future_time = timestamps[j]
            future_price = close_prices[j]

            # Időkorlát ellenőrzés
            if (future_time - start_time).astype('timedelta64[ns]').astype(float) > max_time_ns:
                break # Kifutottunk az időből

            if future_price >= upper_barrier:
                label = 1
                break
            elif future_price <= lower_barrier:
                label = -1
                break

        labels[i] = label

        if label == 1: success_long += 1
        elif label == -1: success_short += 1
        else: timeout_noise += 1

    df['Target_Label'] = labels

    # Adatok elmentése (levágjuk a legvégét, ahol az időkorlát miatt már garantáltan 0 lenne minden)
    # df = df.iloc[:-50] # Finomhangolás később

    print("\n✅ Címkézés Kész!")
    print(f"📈 Long (+1): {success_long} db")
    print(f"📉 Short (-1): {success_short} db")
    print(f"⚪ Semleges/Zaj (0): {timeout_noise} db")

    df.to_csv(output_path, index=False)
    print(f"💾 Címkézett adatok elmentve: {output_path}")
    return df

if __name__ == '__main__':
    input_file = '/home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv'
    output_file = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    apply_copilot_triple_barrier(input_file, output_file)
