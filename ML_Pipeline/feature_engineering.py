import pandas as pd
import numpy as np
import os
import glob
from datetime import datetime

def load_and_clean_data(data_path):
    print(f'Loading data from {data_path}...')
    try:
        df = pd.read_csv(data_path)
    except Exception as e:
        print(f'Error loading CSV: {e}')
        return None

    print(f'Loaded {len(df)} rows. Columns: {df.columns.tolist()}')

    # Convert all columns to lowercase to avoid case issues
    df.columns = [col.lower() for col in df.columns]

    # Rename MT5 columns to standard
    rename_map = {
        'time': 'timestamp',
        'bar_open': 'open',
        'bar_high': 'high',
        'bar_low': 'low',
        'bar_close': 'close',
        'bid': 'bid',
        'ask': 'ask'
    }

    df.rename(columns=rename_map, inplace=True)

    if 'timestamp' in df.columns:
        # MT5 format: 2026.03.09 00:00:00.000
        try:
            df['timestamp'] = pd.to_datetime(df['timestamp'], format='%Y.%m.%d %H:%M:%S.%f', errors='coerce')
        except:
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')

        df.set_index('timestamp', inplace=True)
        df.sort_index(inplace=True)

    df.dropna(subset=['close'], inplace=True)
    return df

def create_features(df):
    print('Engineering features...')
    df_feat = df.copy()

    if 'ctx_ema_25' in df.columns and 'ctx_ema_50' in df.columns:
        df_feat['dist_ema25'] = (df_feat['close'] - df_feat['ctx_ema_25']) / df_feat['ctx_ema_25'] * 100
        df_feat['dist_ema50'] = (df_feat['close'] - df_feat['ctx_ema_50']) / df_feat['ctx_ema_50'] * 100
        df_feat['dist_ema150'] = (df_feat['close'] - df_feat['ctx_ema_150']) / df_feat['ctx_ema_150'] * 100
        df_feat['dist_ema300'] = (df_feat['close'] - df_feat['ctx_ema_300']) / df_feat['ctx_ema_300'] * 100

        df_feat['ema25_50_cross'] = np.sign(df_feat['ctx_ema_25'] - df_feat['ctx_ema_50'])
        df_feat['ema50_150_cross'] = np.sign(df_feat['ctx_ema_50'] - df_feat['ctx_ema_150'])

    df_feat['return_1'] = df_feat['close'].pct_change(1) * 100
    df_feat['return_3'] = df_feat['close'].pct_change(3) * 100
    df_feat['return_5'] = df_feat['close'].pct_change(5) * 100
    df_feat['return_15'] = df_feat['close'].pct_change(15) * 100

    df_feat['momentum_accel'] = df_feat['return_1'] - df_feat['return_1'].shift(1)

    df_feat['vol_5'] = df_feat['return_1'].rolling(5).std() * 100
    df_feat['vol_15'] = df_feat['return_1'].rolling(15).std() * 100

    df_feat['candle_body'] = abs(df_feat['close'] - df_feat['open'])
    df_feat['candle_range'] = df_feat['high'] - df_feat['low']
    df_feat['body_ratio'] = df_feat['candle_body'] / (df_feat['candle_range'] + 1e-10)

    df_feat['hour_sin'] = np.sin(2 * np.pi * df_feat.index.hour / 24)
    df_feat['hour_cos'] = np.cos(2 * np.pi * df_feat.index.hour / 24)
    df_feat['dow_sin'] = np.sin(2 * np.pi * df_feat.index.dayofweek / 5)
    df_feat['dow_cos'] = np.cos(2 * np.pi * df_feat.index.dayofweek / 5)

    return df_feat

def create_triple_barrier_labels(df, lookahead_bars=10, pt_atr_mult=1.75, sl_atr_mult=1.5):
    print(f'Creating Triple Barrier labels (Lookahead: {lookahead_bars} bars, TP: {pt_atr_mult}*ATR, SL: {sl_atr_mult}*ATR)...')

    df = df.copy()

    if 'candle_range' in df.columns:
        df['atr_proxy'] = df['candle_range'].rolling(14).mean()
    else:
        df['atr_proxy'] = (df['high'] - df['low']).rolling(14).mean()

    df['atr_proxy'] = df['atr_proxy'].bfill()

    labels = np.zeros(len(df))

    closes = df['close'].values
    highs = df['high'].values
    lows = df['low'].values
    atrs = df['atr_proxy'].values

    for i in range(len(df) - lookahead_bars):
        current_close = closes[i]
        atr = atrs[i]

        # Szimmetrikus szintek kiszámítása mindkét irányhoz!
        buy_tp_level = current_close + (atr * pt_atr_mult)
        buy_sl_level = current_close - (atr * sl_atr_mult)

        sell_tp_level = current_close - (atr * pt_atr_mult)
        sell_sl_level = current_close + (atr * sl_atr_mult)

        path_highs = highs[i+1 : i+1+lookahead_bars]
        path_lows = lows[i+1 : i+1+lookahead_bars]

        hit_buy_tp = False
        hit_buy_sl = False
        hit_sell_tp = False
        hit_sell_sl = False

        # Végigmegyünk a jövőbeli gyertyákon sorrendben
        for j in range(lookahead_bars):
            # Mindig először a Low-t (esést) vagy a High-t (emelkedést) érte el abban a konkrét gyertyában?
            # A biztonság kedvéért a pesszimista esetet nézzük:
            # ha egy gyertyán belül megvan mindkettő, feltételezzük, hogy az SL-t ütötte ki először.

            # --- BUY SCENARIO VIZSGÁLATA ---
            if not hit_buy_tp and not hit_buy_sl:
                if path_lows[j] <= buy_sl_level:
                    hit_buy_sl = True
                elif path_highs[j] >= buy_tp_level:
                    hit_buy_tp = True

            # --- SELL SCENARIO VIZSGÁLATA ---
            if not hit_sell_tp and not hit_sell_sl:
                if path_highs[j] >= sell_sl_level:
                    hit_sell_sl = True
                elif path_lows[j] <= sell_tp_level:
                    hit_sell_tp = True

            # Ha mindkét szcenárió eldőlt (vagy TP vagy SL), kiléphetünk a ciklusból
            if (hit_buy_tp or hit_buy_sl) and (hit_sell_tp or hit_sell_sl):
                break

        # Címke kiosztása:
        if hit_buy_tp and not hit_buy_sl:
            labels[i] = 1 # Valid Buy
        elif hit_sell_tp and not hit_sell_sl:
            labels[i] = -1 # Valid Sell
        else:
            labels[i] = 0 # Hold / Noise

    df['target'] = labels
    df.drop(columns=['atr_proxy'], inplace=True)
    return df

def run_feature_pipeline(input_file, output_file):
    df = load_and_clean_data(input_file)
    if df is None or df.empty:
        return False

    df = create_features(df)
    df = create_triple_barrier_labels(df, lookahead_bars=10, pt_atr_mult=1.75, sl_atr_mult=1.5)

    df.dropna(subset=['close'], inplace=True)
    # Keeping ALL labels (including 0) so the script doesn't artificially balance it.
    # The actual filtering should happen during the AI training phase if needed.
    df.fillna(0, inplace=True)

    # Drop RAW Price and absolute EMA values to prevent Data Leakage!
    # The ML model must only see relative/normalized indicators (distances, ratios, oscillators)
    leakage_cols = ['open', 'high', 'low', 'close', 'bid', 'ask', 'bar_open', 'bar_high', 'bar_low', 'bar_close',
                    'ctx_ema_25', 'ctx_ema_50', 'ctx_ema_150', 'ctx_ema_300',
                    'mic_p', 'mic_r', 'mic_s', 'sec_p', 'sec_r', 'sec_s', 'ter_p', 'ter_r', 'ter_s',
                    'spread', 'bidvol', 'askvol', 'balance', 'margin', 'marginpercent', 'floating_pl', 'realized_pl', 'session_pl', 'poscount', 'totallots',
                    'velocity', 'acceleration', 'dist_ema25', 'dist_ema150', 'hybrid_macd']

    # Keresünk az összes oszlopban, és eldobjuk, ami szivárgás
    cols_to_drop = [c for c in leakage_cols if c in df.columns]
    df.drop(columns=cols_to_drop, inplace=True)


    df.to_parquet(output_file)
    print(f'Feature engineering complete. Saved {len(df)} rows to {output_file}')
    return True

if __name__ == '__main__':
    csv_files = glob.glob('../data/raw/*.csv')
    if not csv_files:
        print('No CSV files found in ../data/raw/')
    else:
        latest_csv = max(csv_files, key=os.path.getctime)
        output_parquet = '../data/processed/scalp_features.parquet'
        run_feature_pipeline(latest_csv, output_parquet)
