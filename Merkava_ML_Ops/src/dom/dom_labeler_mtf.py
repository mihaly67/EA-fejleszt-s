import pandas as pd
import numpy as np
import sys
import os
import plotly.graph_objects as go

def print_stats(labels, dataset_name="Dataset"):
    total = len(labels)
    if total == 0:
        print(f"[{dataset_name}] Üres adathalmaz!")
        return

    success_long = np.sum(labels == 1)
    success_short = np.sum(labels == -1)
    timeout_noise = np.sum(labels == 0)

    print(f"\n📊 --- {dataset_name} Címkézési Statisztika ---")
    print(f"Összes minta: {total}")
    print(f"📈 Tiszta Long (+1): {success_long} db ({success_long/total*100:.2f}%)")
    print(f"📉 Tiszta Short (-1): {success_short} db ({success_short/total*100:.2f}%)")
    print(f"⚪ Kipattintás/Zaj (0): {timeout_noise} db ({timeout_noise/total*100:.2f}%)")
    print(f"----------------------------------------\n")

def apply_copilot_triple_barrier(df, tp_barrier=1.5, sl_barrier=1.0, max_time_minutes=15):
    """
    Path Dependency (High/Low) alapú címkéző.
    """
    labels = np.zeros(len(df))
    close_prices = df['Close'].values
    high_prices = df['High'].values
    low_prices = df['Low'].values

    # Próbálunk Start_Timestamp vagy Time oszlopot keresni
    time_col = 'Timestamp' if 'Timestamp' in df.columns else ('Start_Timestamp' if 'Start_Timestamp' in df.columns else 'Time')
    if time_col not in df.columns:
        print(f"Hiba: Nincs idő oszlop ({time_col}) a DataFrame-ben!")
        return df

    # Konvertálás datetime-ra ha még nem az
    if not pd.api.types.is_datetime64_any_dtype(df[time_col]):
        df[time_col] = pd.to_datetime(df[time_col])

    timestamps = df[time_col].values
    max_time_ns = max_time_minutes * 60 * 1e9

    for i in range(len(df)):
        start_time = timestamps[i]
        start_price = close_prices[i]

        long_upper_barrier = start_price + tp_barrier
        long_lower_barrier = start_price - sl_barrier

        short_lower_barrier = start_price - tp_barrier
        short_upper_barrier = start_price + sl_barrier

        label = 0

        long_active = True
        short_active = True

        for j in range(i + 1, len(df)):
            future_time = timestamps[j]
            future_high = high_prices[j]
            future_low = low_prices[j]

            # Időkorlát ellenőrzés
            if (future_time - start_time).astype('timedelta64[ns]').astype(float) > max_time_ns:
                break # Mindkettő lejárt, marad a 0

            # LONG VIZSGÁLAT
            if long_active:
                if future_low <= long_lower_barrier and future_high >= long_upper_barrier:
                    long_active = False # Kipattint (0)
                elif future_low <= long_lower_barrier:
                    long_active = False # Stop Loss kiütve
                elif future_high >= long_upper_barrier:
                    label = 1 # Take Profit elérve
                    break

            # SHORT VIZSGÁLAT
            if short_active:
                if future_high >= short_upper_barrier and future_low <= short_lower_barrier:
                    short_active = False # Kipattint (0)
                elif future_high >= short_upper_barrier:
                    short_active = False # Stop Loss kiütve
                elif future_low <= short_lower_barrier:
                    label = -1 # Take Profit elérve
                    break

            # Ha már egyik irány sem aktív (mindkettő kiütötte a saját SL-jét)
            if not long_active and not short_active:
                break

        labels[i] = label

    df['Target_Label'] = labels
    return df

def generate_html_visualization(df, output_html_path, title="Decision Visualization", sample_size=300):
    if len(df) > sample_size:
        start_idx = len(df) // 2
        df_plot = df.iloc[start_idx:start_idx+sample_size].copy()
    else:
        df_plot = df.copy()

    time_col = 'Timestamp' if 'Timestamp' in df_plot.columns else ('Start_Timestamp' if 'Start_Timestamp' in df_plot.columns else 'Time')

    fig = go.Figure()

    fig.add_trace(go.Candlestick(
        x=df_plot[time_col],
        open=df_plot['Open'],
        high=df_plot['High'],
        low=df_plot['Low'],
        close=df_plot['Close'],
        name='Árfolyam'
    ))

    longs = df_plot[df_plot['Target_Label'] == 1]
    if not longs.empty:
        fig.add_trace(go.Scatter(
            x=longs[time_col],
            y=longs['Low'] - 0.5,
            mode='markers',
            marker=dict(symbol='triangle-up', size=12, color='green'),
            name='Long (+1)'
        ))

    shorts = df_plot[df_plot['Target_Label'] == -1]
    if not shorts.empty:
        fig.add_trace(go.Scatter(
            x=shorts[time_col],
            y=shorts['High'] + 0.5,
            mode='markers',
            marker=dict(symbol='triangle-down', size=12, color='red'),
            name='Short (-1)'
        ))

    noise = df_plot[df_plot['Target_Label'] == 0]
    if not noise.empty:
        fig.add_trace(go.Scatter(
            x=noise[time_col],
            y=noise['Close'],
            mode='markers',
            marker=dict(symbol='circle', size=6, color='gray', opacity=0.5),
            name='Zaj (0)'
        ))

    fig.update_layout(
        title=title,
        xaxis_title='Idő',
        yaxis_title='Ár',
        template='plotly_dark'
    )

    fig.write_html(output_html_path)
    print(f"📉 Vizualizáció elmentve: {output_html_path}")

def prepare_dataframe(df):
    # A tick adatoknál (Bid, Ask) kiszámoljuk a Mid-price-t, ami a Close lesz
    if 'Close' not in df.columns and 'Bid' in df.columns and 'Ask' in df.columns:
        df['Close'] = (df['Bid'] + df['Ask']) / 2.0

    # Nyers Tick adatokhoz szintetizálunk Open, High, Low értékeket a Close-ból
    if 'High' not in df.columns: df['High'] = df['Close']
    if 'Low' not in df.columns: df['Low'] = df['Close']
    if 'Open' not in df.columns: df['Open'] = df['Close']

    return df

def run_pipeline():
    data_dir = "/home/misi/Merkava_ML_Ops/data"
    train_file = os.path.join(data_dir, "Merkava_MTF_MGCQ26_20260527_0717_Data.csv")
    exam_file = os.path.join(data_dir, "Merkava_MTF_MGCQ26_vizsga_0720_0724_Data.csv")

    tp = 1.5
    sl = 1.0
    time_limit = 15

    print(f"\n--- 1. Címkézés Indítása (TP: {tp}, SL: {sl}, Time: {time_limit}m) ---\n")

    if not os.path.exists(train_file):
        print(f"❌ Nem található a fő fájl: {train_file}")
        return

    # 1. FŐ FÁJL FELDOLGOZÁSA
    print(f"📂 Fő fájl betöltése: {train_file}")
    df_main = pd.read_csv(train_file)
    df_main = prepare_dataframe(df_main)
    df_main = apply_copilot_triple_barrier(df_main, tp, sl, time_limit)

    total_len = len(df_main)
    train_end_idx = int(total_len * 0.70)
    test_start_idx = int(total_len * 0.75)

    df_train = df_main.iloc[:train_end_idx].copy()
    df_test = df_main.iloc[test_start_idx:].copy()

    print_stats(df_train['Target_Label'].values, "TRAIN HALMAZ (70%)")
    print_stats(df_test['Target_Label'].values, "TEST HALMAZ (25%, Embargo után)")

    df_train.to_csv(os.path.join(data_dir, "labeled_train.csv"), index=False)
    df_test.to_csv(os.path.join(data_dir, "labeled_test.csv"), index=False)
    generate_html_visualization(df_train, os.path.join(data_dir, "decision_visualization_train.html"), "TRAIN - Copilot Signals")

    # 2. VIZSGA FÁJL FELDOLGOZÁSA
    if os.path.exists(exam_file):
        print(f"\n📂 Vizsga fájl betöltése: {exam_file}")
        df_exam = pd.read_csv(exam_file)
        df_exam = prepare_dataframe(df_exam)

        df_exam = apply_copilot_triple_barrier(df_exam, tp, sl, time_limit)
        print_stats(df_exam['Target_Label'].values, "OOS VIZSGA HALMAZ (5 Nap)")

        df_exam.to_csv(os.path.join(data_dir, "labeled_exam.csv"), index=False)
        generate_html_visualization(df_exam, os.path.join(data_dir, "decision_visualization_exam.html"), "OOS EXAM - Copilot Signals")
    else:
        print(f"⚠️ Vizsga fájl nem található: {exam_file}")

if __name__ == '__main__':
    run_pipeline()
