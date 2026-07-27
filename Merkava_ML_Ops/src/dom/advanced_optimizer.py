import pandas as pd
import numpy as np
import sys

def optimize_2d(filepath, tp=1.5, sl=1.0, max_time_min=15, dataset_days=5):
    print(f"🔍 2D Küszöbérték Optimalizáló Indul: {filepath}")
    df = pd.read_csv(filepath)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])

    close_prices = df['Close'].values
    open_prices = df['Open'].values
    timestamps = df['Start_Timestamp'].values

    p_long = df['P_Long'].values
    p_short = df['P_Short'].values
    p_noise = df['P_Noise'].values

    max_time_ns = max_time_min * 60 * 1e9

    signal_thresholds = np.arange(0.35, 0.61, 0.02)
    noise_thresholds = np.arange(0.20, 0.46, 0.02)

    results = []

    for sig_thresh in signal_thresholds:
        for noise_thresh in noise_thresholds:
            long_wins = 0
            short_wins = 0
            long_signals = 0
            short_signals = 0

            for i in range(len(df) - 1):
                # 2D feltétel: Jel > X ÉS Zaj < Y
                is_long = (p_long[i] >= sig_thresh) and (p_long[i] > p_short[i]) and (p_noise[i] <= noise_thresh)
                is_short = (p_short[i] >= sig_thresh) and (p_short[i] > p_long[i]) and (p_noise[i] <= noise_thresh)

                if not is_long and not is_short:
                    continue

                start_time = timestamps[i+1]
                entry_price = open_prices[i+1]

                long_tp = entry_price + tp
                long_sl = entry_price - sl
                short_tp = entry_price - tp
                short_sl = entry_price + sl

                long_status = 0
                short_status = 0

                for j in range(i + 1, len(df)):
                    future_time = timestamps[j]
                    future_close = close_prices[j]

                    if (future_time - start_time).astype('timedelta64[ns]').astype(float) > max_time_ns:
                        break

                    if long_status == 0:
                        if future_close >= long_tp: long_status = 1
                        elif future_close <= long_sl: long_status = -1

                    if short_status == 0:
                        if future_close <= short_tp: short_status = 1
                        elif future_close >= short_sl: short_status = -1

                    if long_status == 1 or short_status == 1: break
                    if long_status == -1 and short_status == -1: break

                if is_long:
                    long_signals += 1
                    if long_status == 1 and short_status != 1:
                        long_wins += 1
                elif is_short:
                    short_signals += 1
                    if short_status == 1 and long_status != 1:
                        short_wins += 1

            total_signals = long_signals + short_signals
            total_wins = long_wins + short_wins
            win_rate = (total_wins / total_signals * 100) if total_signals > 0 else 0
            trades_per_day = total_signals / dataset_days

            results.append((sig_thresh, noise_thresh, win_rate, total_signals, trades_per_day))

    # Rendezés: Minimum 10 kötés/nap elvárás, azután Win Rate szerint csökkenő
    df_results = pd.DataFrame(results, columns=['Signal_Thresh', 'Max_Noise_Thresh', 'Win_Rate', 'Total_Signals', 'Trades_Per_Day'])
    valid_results = df_results[df_results['Trades_Per_Day'] >= 10].sort_values(by='Win_Rate', ascending=False)

    print("\n🏆 LEGJOBB 5 KOMBINÁCIÓ (Minimum 10 kötés/nap feltétellel):")
    for _, r in valid_results.head(5).iterrows():
        print(f"Jel > {r['Signal_Thresh']:.2f} ÉS Zaj < {r['Max_Noise_Thresh']:.2f} | Win Rate: {r['Win_Rate']:.2f}% | Össz jel: {r['Total_Signals']:.0f} (Kb. {r['Trades_Per_Day']:.1f} / nap)")

    # Nézzük meg a "Nagyon Aktív" (Napi 30+ kötés) legjobb variációját is
    active_results = df_results[df_results['Trades_Per_Day'] >= 30].sort_values(by='Win_Rate', ascending=False)
    if not active_results.empty:
        r_act = active_results.iloc[0]
        print(f"\n🚀 LEGJOBB 'AKTÍV' KOMBINÁCIÓ (>30 kötés/nap):")
        print(f"Jel > {r_act['Signal_Thresh']:.2f} ÉS Zaj < {r_act['Max_Noise_Thresh']:.2f} | Win Rate: {r_act['Win_Rate']:.2f}% | Napi: {r_act['Trades_Per_Day']:.1f}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/blind_predictions.csv')
    parser.add_argument('--days', type=float, default=5.0)
    args = parser.parse_args()

    optimize_2d(args.input_file, dataset_days=args.days)
