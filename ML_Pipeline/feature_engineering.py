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

    # Rename MT5 columns to standard
    rename_map = {
        'Time': 'timestamp',
        'Bar_Open': 'open',
        'Bar_High': 'high',
        'Bar_Low': 'low',
        'Bar_Close': 'close',
        'Bid': 'bid',
        'Ask': 'ask'
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

    if 'Ctx_EMA_25' in df.columns and 'Ctx_EMA_50' in df.columns:
        df_feat['dist_ema25'] = (df_feat['close'] - df_feat['Ctx_EMA_25']) / df_feat['Ctx_EMA_25'] * 100
        df_feat['dist_ema50'] = (df_feat['close'] - df_feat['Ctx_EMA_50']) / df_feat['Ctx_EMA_50'] * 100
        df_feat['dist_ema150'] = (df_feat['close'] - df_feat['Ctx_EMA_150']) / df_feat['Ctx_EMA_150'] * 100
        df_feat['dist_ema300'] = (df_feat['close'] - df_feat['Ctx_EMA_300']) / df_feat['Ctx_EMA_300'] * 100

        df_feat['ema25_50_cross'] = np.sign(df_feat['Ctx_EMA_25'] - df_feat['Ctx_EMA_50'])
        df_feat['ema50_150_cross'] = np.sign(df_feat['Ctx_EMA_50'] - df_feat['Ctx_EMA_150'])

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

def create_triple_barrier_labels(df, lookahead_bars=10, pt_atr_mult=3.5, sl_atr_mult=1.5):
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

        upper_barrier = current_close + (atr * pt_atr_mult)
        lower_barrier = current_close - (atr * sl_atr_mult)

        path_highs = highs[i+1 : i+1+lookahead_bars]
        path_lows = lows[i+1 : i+1+lookahead_bars]

        hit_upper_first = False
        hit_lower_first = False

        for j in range(lookahead_bars):
            if path_lows[j] <= lower_barrier:
                hit_lower_first = True
                break
            if path_highs[j] >= upper_barrier:
                hit_upper_first = True
                break

        if hit_upper_first:
            labels[i] = 1 # Valid Buy
        elif hit_lower_first:
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
    df = create_triple_barrier_labels(df, lookahead_bars=10, pt_atr_mult=3.5, sl_atr_mult=1.5)

    df.dropna(subset=['close'], inplace=True)
    # Keeping ALL labels (including 0) so the script doesn't artificially balance it.
    # The actual filtering should happen during the AI training phase if needed.
    df.fillna(0, inplace=True)

    # Drop RAW Price and absolute EMA values to prevent Data Leakage!
    # The ML model must only see relative/normalized indicators (distances, ratios, oscillators)
    leakage_cols = ['open', 'high', 'low', 'close', 'bid', 'ask', 'Bar_Open', 'Bar_High', 'Bar_Low', 'Bar_Close',
                    'Ctx_EMA_25', 'Ctx_EMA_50', 'Ctx_EMA_150', 'Ctx_EMA_300',
                    'Mic_P', 'Mic_R', 'Mic_S', 'Sec_P', 'Sec_R', 'Sec_S', 'Ter_P', 'Ter_R', 'Ter_S',
                    'Spread', 'BidVol', 'AskVol', 'Balance', 'Margin', 'MarginPercent', 'Floating_PL', 'Realized_PL', 'Session_PL', 'PosCount', 'TotalLots',
                    'Velocity', 'Acceleration', 'dist_ema25', 'dist_ema150', 'Hybrid_MACD']

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
