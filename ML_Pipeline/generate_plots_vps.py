import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import mplfinance as mpf
import os

# Utvonalak
DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/scalp_features.parquet"
OUTPUT_DIR = "/home/misi/Merkava_ML_Ops/"

print("Betöltöm az adatokat...")
df = pd.read_parquet(DATA_PATH)

# ==========================================
# 1. Korrelációs Hőtérkép
# ==========================================
print("Generálom a korrelációs hőtérképet...")
# Kiszűrjük a non-numerikus és a célváltozót
features_to_corr = df.drop(columns=['time', 'Target', 'Open', 'High', 'Low', 'Close', 'Tick_Volume', 'Spread'], errors='ignore')

# Select only numeric columns for correlation
features_to_corr = features_to_corr.select_dtypes(include=[np.number])

corr_matrix = features_to_corr.corr()

plt.figure(figsize=(18, 14))
sns.heatmap(corr_matrix, annot=False, cmap='coolwarm', linewidths=0.5)
plt.title('XGBoost Scalping Feature Korrelációs Hőtérkép')
plt.tight_layout()
heatmap_path = os.path.join(OUTPUT_DIR, "correlation_heatmap.png")
plt.savefig(heatmap_path, dpi=300)
plt.clf()
plt.close()
print(f"Hőtérkép mentve: {heatmap_path}")

# ==========================================
# 2. OHLC Chart + Triple Barrier Cimkék
# ==========================================
print("Generálom az OHLC diagramot...")
# Kiválasztunk egy 200 gyertyás szeletet, ahol van volatilitás / esemény
# Mivel M1 adatról van szó, 200 gyertya kb. 3.5 óra
sample_df = df.iloc[-500:-300].copy()

# Mpfinance elvárja, hogy a datetime legyen az index és a formátum OHLC legyen
if 'time' in sample_df.columns:
    sample_df['time'] = pd.to_datetime(sample_df['time'])
    sample_df.set_index('time', inplace=True)

# Létrehozunk markereket a BUY (1) és SELL (2) szignálokhoz
# A Target: 0 = HOLD, 1 = BUY, 2 = SELL (ha a korábbi logikát követjük)
# Itt figyelünk a pontos labeling mappingre. Ha -1 a sell, akkor azt kezeljük.
buy_signals = np.where(sample_df['Target'] == 1, sample_df['Low'] - (sample_df['ATR_14'] * 0.5), np.nan)
sell_signals = np.where(sample_df['Target'] == 2, sample_df['High'] + (sample_df['ATR_14'] * 0.5), np.nan) # Vagy -1, attól függ hogy lett kódolva

# Create addplots
apds = []
if not np.isnan(buy_signals).all():
    apds.append(mpf.make_addplot(buy_signals, type='scatter', markersize=100, marker='^', color='green'))
if not np.isnan(sell_signals).all():
    apds.append(mpf.make_addplot(sell_signals, type='scatter', markersize=100, marker='v', color='red'))

chart_path = os.path.join(OUTPUT_DIR, "ohlc_chart.png")

# Oszlopok ellenőrzése mpf számára
required_cols = ['Open', 'High', 'Low', 'Close']
missing_cols = [col for col in required_cols if col not in sample_df.columns]

if not missing_cols:
    mpf.plot(sample_df, type='candle', style='charles', addplot=apds,
             title='XAUUSD M1 - Triple Barrier Címkék (Részlet)',
             ylabel='Price', volume=False,
             savefig=dict(fname=chart_path, dpi=300, bbox_inches='tight'))
    print(f"OHLC Chart mentve: {chart_path}")
else:
    print(f"Hiányzó OHLC oszlopok a diagramhoz: {missing_cols}. Biztosítva volt, hogy a feature_engineering során ki lettek dobva? Ha igen, visszatöltjük a nyers CSV-ből.")

    # Ha a feature pipeline kidobta az OHLC-t (ami helyes a leakage miatt), akkor a plotoláshoz vissza kell merge-elni
    print("Visszatöltöm az OHLC adatokat a nyers CSV-ből a plotoláshoz...")
    raw_csv = "/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_MINER_M1_SCRIPT_v1.04_20260618_022831.csv"
    raw_df = pd.read_csv(raw_csv)
    raw_df['time'] = pd.to_datetime(raw_df['Date'] + ' ' + raw_df['Time'])
    raw_df.set_index('time', inplace=True)
    raw_df.rename(columns={'<OPEN>': 'Open', '<HIGH>': 'High', '<LOW>': 'Low', '<CLOSE>': 'Close'}, inplace=True)

    # A processed df indexe is time kell legyen a joinhoz
    if 'time' in df.columns:
        df['time'] = pd.to_datetime(df['time'])
        df.set_index('time', inplace=True)

    # Keresünk egy olyan periódust a df-ben, ahol van egyértelmű jel
    # Szűkítjük a df-et, hogy ne terheljük túl a memóriát
    sample_targets = df.iloc[-1000:-500].copy()

    # Merge on index (time)
    plot_df = raw_df[['Open', 'High', 'Low', 'Close']].join(sample_targets[['Target', 'ATR_14']], how='inner')

    # Most már megvan az OHLC és a Target is
    buy_signals = np.where(plot_df['Target'] == 1, plot_df['Low'] - (plot_df['ATR_14'] * 0.5), np.nan)
    sell_signals = np.where((plot_df['Target'] == 2) | (plot_df['Target'] == -1), plot_df['High'] + (plot_df['ATR_14'] * 0.5), np.nan) # lekezelve mindkét kódolás

    apds = []
    if not np.isnan(buy_signals).all():
        apds.append(mpf.make_addplot(buy_signals, type='scatter', markersize=100, marker='^', color='green'))
    if not np.isnan(sell_signals).all():
        apds.append(mpf.make_addplot(sell_signals, type='scatter', markersize=100, marker='v', color='red'))

    mpf.plot(plot_df, type='candle', style='charles', addplot=apds,
             title='XAUUSD M1 - Triple Barrier Címkék (Részlet)',
             ylabel='Price', volume=False, figsize=(14,8),
             savefig=dict(fname=chart_path, dpi=300, bbox_inches='tight'))
    print(f"OHLC Chart mentve a visszamergelt adatokból: {chart_path}")

print("Kész.")
