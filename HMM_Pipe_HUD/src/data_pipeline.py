import pandas as pd
import numpy as np
import os

def load_and_resample(csv_path):
    print(f'Betöltés: {csv_path}')
    df = pd.read_csv(csv_path, parse_dates=['Time'])
    df.set_index('Time', inplace=True)

    print('1 perces (M1), 5 perces (M5) és 15 perces (M15) gyertyák (OHLC) generálása...')

    # Készítünk tiszta M1 OHLCV adatot:
    df_m1 = df['Bid'].resample('1min').ohlc()
    df_m1['Volume'] = df['BidVol'].resample('1min').sum()
    df_m1.dropna(inplace=True)

    # Készítünk tiszta M5 OHLCV adatot:
    df_m5 = df['Bid'].resample('5min').ohlc()
    df_m5['Volume'] = df['BidVol'].resample('5min').sum()
    df_m5.dropna(inplace=True)

    # Készítünk tiszta M15 OHLCV adatot:
    df_m15 = df['Bid'].resample('15min').ohlc()
    df_m15['Volume'] = df['BidVol'].resample('15min').sum()
    df_m15.dropna(inplace=True)

    print('Feature engineering: Log Return és ATR (High-Low)')

    # Feature-ök M1-re
    df_m1['LogReturn'] = np.log(df_m1['close'] / df_m1['close'].shift(1))
    df_m1['ATR_Proxy'] = df_m1['high'] - df_m1['low']
    df_m1.dropna(inplace=True)

    # Feature-ök M5-re
    df_m5['LogReturn'] = np.log(df_m5['close'] / df_m5['close'].shift(1))
    df_m5['ATR_Proxy'] = df_m5['high'] - df_m5['low']
    df_m5.dropna(inplace=True)

    # Feature-ök M15-re
    df_m15['LogReturn'] = np.log(df_m15['close'] / df_m15['close'].shift(1))
    df_m15['ATR_Proxy'] = df_m15['high'] - df_m15['low']
    df_m15.dropna(inplace=True)

    return df_m1, df_m5, df_m15

if __name__ == '__main__':
    csv_file = 'analysis_input/Mimic_Merkava_GOLD_v1.05_BW_DirectCalc_20260206_174251.csv'
    if not os.path.exists(csv_file):
        csv_file = 'analysis_input/Mimic_Merkava_GOLD_v1.05_BW_DirectCalc_20260206_174251.csv' # Fallback path
    m1, m5, m15 = load_and_resample(csv_file)
    print(m1.head())
    print('M1 gyertyák száma:', len(m1))
    print('M5 gyertyák száma:', len(m5))
    print('M15 gyertyák száma:', len(m15))
