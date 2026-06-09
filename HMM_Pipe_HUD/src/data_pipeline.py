import pandas as pd
import numpy as np

def load_and_resample(csv_path):
    print(f'Betöltés: {csv_path}')
    df = pd.read_csv(csv_path, parse_dates=['Time'])
    df.set_index('Time', inplace=True)

    print('5 másodperces (S5), 1 perces (M1) és 5 perces (M5) gyertyák (OHLC) generálása...')

    # Készítünk tiszta S5 OHLCV adatot:
    df_s5 = df['Bid'].resample('5s').ohlc()
    df_s5['Volume'] = df['BidVol'].resample('5s').sum()
    df_s5.dropna(inplace=True)

    # Készítünk tiszta M1 OHLCV adatot:
    df_m1 = df['Bid'].resample('1min').ohlc()
    df_m1['Volume'] = df['BidVol'].resample('1min').sum()
    df_m1.dropna(inplace=True)

    # Készítünk tiszta M5 OHLCV adatot:
    df_m5 = df['Bid'].resample('5min').ohlc()
    df_m5['Volume'] = df['BidVol'].resample('5min').sum()
    df_m5.dropna(inplace=True)

    print('Feature engineering: Log Return és ATR (High-Low)')

    # Feature-ök S5-re
    df_s5['LogReturn'] = np.log(df_s5['close'] / df_s5['close'].shift(1))
    df_s5['ATR_Proxy'] = df_s5['high'] - df_s5['low']
    df_s5.dropna(inplace=True)

    # Feature-ök M1-re
    df_m1['LogReturn'] = np.log(df_m1['close'] / df_m1['close'].shift(1))
    df_m1['ATR_Proxy'] = df_m1['high'] - df_m1['low']
    df_m1.dropna(inplace=True)

    # Feature-ök M5-re
    df_m5['LogReturn'] = np.log(df_m5['close'] / df_m5['close'].shift(1))
    df_m5['ATR_Proxy'] = df_m5['high'] - df_m5['low']
    df_m5.dropna(inplace=True)

    return df_s5, df_m1, df_m5

if __name__ == '__main__':
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'
    s5, m1, m5 = load_and_resample(csv_file)
    print(s5.head())
    print('S5 gyertyák száma:', len(s5))
    print('M1 gyertyák száma:', len(m1))
    print('M5 gyertyák száma:', len(m5))
