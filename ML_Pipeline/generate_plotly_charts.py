import pandas as pd
import numpy as np
import plotly.graph_objects as go
import os

# Utvonalak
DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/scalp_features.parquet"
RAW_CSV_PATH = "/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_MINER_M1_SCRIPT_v1.04_20260618_022831.csv"
OUTPUT_DIR = "/home/misi/Merkava_ML_Ops/"

print("Betöltöm az adatokat...")
df = pd.read_parquet(DATA_PATH)

# ==========================================
# 1. Korrelációs Hőtérkép
# ==========================================
print("Generálom a korrelációs hőtérképet Plotly-val...")
features_to_corr = df.drop(columns=['timestamp', 'target', 'open', 'high', 'low', 'close', 'tick_volume', 'spread'], errors='ignore')
features_to_corr = features_to_corr.select_dtypes(include=[np.number])
corr_matrix = features_to_corr.corr()

fig_corr = go.Figure(data=go.Heatmap(
                   z=corr_matrix.values,
                   x=corr_matrix.columns,
                   y=corr_matrix.columns,
                   colorscale='RdBu',
                   zmin=-1, zmax=1))

fig_corr.update_layout(
    title='XGBoost Scalping Feature Korrelációs Hőtérkép',
    width=1000, height=800
)

heatmap_path = os.path.join(OUTPUT_DIR, "correlation_heatmap.html")
fig_corr.write_html(heatmap_path)
print(f"Hőtérkép mentve (HTML): {heatmap_path}")


# ==========================================
# 2. OHLC Chart + Triple Barrier Cimkék
# ==========================================
print("Generálom az OHLC diagramot Plotly-val...")

raw_df = pd.read_csv(RAW_CSV_PATH)

# Oszlop átnevezések az OHLC plot-hoz
raw_df.rename(columns={
    'Time': 'time',
    'Bar_Open': 'Open',
    'Bar_High': 'High',
    'Bar_Low': 'Low',
    'Bar_Close': 'Close'
}, inplace=True)

# Idő konverzió
raw_df['time'] = pd.to_datetime(raw_df['time'], format='%Y.%m.%d %H:%M:%S.%f', errors='coerce')
raw_df.set_index('time', inplace=True)
raw_df.sort_index(inplace=True)

# A parquet fájl indexe jelenleg a timestamp-et tartalmazza a feature_engineering.py alapján
if 'timestamp' in df.columns:
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df.set_index('timestamp', inplace=True)

# ATR számítás lokálisan a plotoláshoz
raw_df['TR'] = np.maximum((raw_df['High'] - raw_df['Low']),
               np.maximum(abs(raw_df['High'] - raw_df['Close'].shift(1)),
                          abs(raw_df['Low'] - raw_df['Close'].shift(1))))
raw_df['ATR_14'] = raw_df['TR'].rolling(window=14).mean().bfill()

# Merge (az index a timestamp)
plot_df = raw_df[['Open', 'High', 'Low', 'Close', 'ATR_14']].join(df[['target']], how='inner')

if len(plot_df) > 0:
    print(f"Sikeres join! {len(plot_df)} gyertya plotolása.")
    # Válasszunk ki egy rövidebb, kb 300 gyertyás szakaszt a vizualizáláshoz, ami sűrűn tartalmaz jeleket.
    window_size = min(300, len(plot_df))
    max_signals = -1
    best_start = 0

    for i in range(len(plot_df) - window_size):
        signals = (plot_df.iloc[i:i+window_size]['target'] != 0).sum()
        if signals > max_signals:
            max_signals = signals
            best_start = i

    best_subset = plot_df.iloc[best_start:best_start+window_size]

    fig_ohlc = go.Figure(data=[go.Candlestick(x=best_subset.index,
                    open=best_subset['Open'],
                    high=best_subset['High'],
                    low=best_subset['Low'],
                    close=best_subset['Close'],
                    name='XAUUSD M1')])

    # Vételi és eladási jelzések
    buy_signals = best_subset[best_subset['target'] == 1]
    sell_signals = best_subset[best_subset['target'] == -1]

    # Hozzáadjuk a Buy markereket
    if not buy_signals.empty:
        fig_ohlc.add_trace(go.Scatter(
            x=buy_signals.index,
            y=buy_signals['Low'] - (buy_signals['ATR_14'] * 0.5),
            mode='markers',
            marker=dict(symbol='triangle-up', size=12, color='green', line=dict(width=1, color='DarkSlateGrey')),
            name='Buy Signal (Triple Barrier)'
        ))

    # Hozzáadjuk a Sell markereket
    if not sell_signals.empty:
        fig_ohlc.add_trace(go.Scatter(
            x=sell_signals.index,
            y=sell_signals['High'] + (sell_signals['ATR_14'] * 0.5),
            mode='markers',
            marker=dict(symbol='triangle-down', size=12, color='red', line=dict(width=1, color='DarkSlateGrey')),
            name='Sell Signal (Triple Barrier)'
        ))

    fig_ohlc.update_layout(
        title='XAUUSD M1 - Triple Barrier Címkék (Új Szimmetrikus Logika)',
        yaxis_title='Price',
        xaxis_title='Time',
        width=1400, height=800,
        xaxis_rangeslider_visible=False,
        template="plotly_dark"
    )

    chart_path = os.path.join(OUTPUT_DIR, "ohlc_chart.html")
    fig_ohlc.write_html(chart_path)
    print(f"OHLC Chart mentve (HTML): {chart_path}")

    png_chart_path = os.path.join(OUTPUT_DIR, "ohlc_chart.png")
    fig_ohlc.write_image(png_chart_path)
    print(f"OHLC Chart mentve (PNG): {png_chart_path}")
else:
    print("A join eredménye üres lett! Ellenőrizd az indexeket.")

print("Generálás befejeződött.")

# Konvertáljuk PNG-be is a kaleido segítségével
png_heatmap_path = os.path.join(OUTPUT_DIR, "correlation_heatmap.png")
fig_corr.write_image(png_heatmap_path)
print(f"Hőtérkép mentve (PNG): {png_heatmap_path}")
