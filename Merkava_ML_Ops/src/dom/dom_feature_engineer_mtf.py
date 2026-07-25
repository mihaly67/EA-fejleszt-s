import pandas as pd
import numpy as np
import os
import ta

class MTFFeatureEngineer:
    def __init__(self, data_path, output_path):
        self.data_path = data_path
        self.output_path = output_path

    def calculate_atr(self, df, period=15):
        high_low = df["High"] - df["Low"]
        high_close = np.abs(df["High"] - df["Close"].shift())
        low_close = np.abs(df["Low"] - df["Close"].shift())
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = np.max(ranges, axis=1)
        return true_range.rolling(period).mean()

    def process(self):
        print(f"🔄 Reading Dollar Bars from: {self.data_path}")
        df = pd.read_csv(self.data_path)

        df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
        df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])

        # Ensure we don't divide by zero
        total_vol = df['Total_Volume'] + 1e-9

        print("🔨 Feature Engineering: Order Book Imbalance (OBI)")
        df['OBI_Raw'] = (df['Ask_Volume'] - df['Bid_Volume']) / total_vol
        rolling_obi_mean = df['OBI_Raw'].rolling(100).mean()
        rolling_obi_std = df['OBI_Raw'].rolling(100).std() + 1e-9
        df['OBI_ZScore'] = ((df['OBI_Raw'] - rolling_obi_mean) / rolling_obi_std).shift(1)

        print("🔨 Feature Engineering: Price Velocity & Tick Speed")
        df['Bar_Time_Seconds'] = (df['End_Timestamp'] - df['Start_Timestamp']).dt.total_seconds().replace(0, 1)

        velocity = df['Close'].diff(1) / df['Bar_Time_Seconds']
        df['Price_Velocity'] = velocity.replace([np.inf, -np.inf], 0).fillna(0).shift(1)
        df['Tick_Speed'] = (1.0 / df['Bar_Time_Seconds']).shift(1)

        print("🔨 Feature Engineering: Macro Confluence Distances")
        df['Dist_5m'] = ((df['Close'] - df['5m_Close']) / df['Close'] * 100).shift(1)
        df['Dist_15m'] = ((df['Close'] - df['15m_Close']) / df['Close'] * 100).shift(1)

        print("🔨 Feature Engineering: ATR Proxy")
        df['ATR_Proxy'] = self.calculate_atr(df, 15).shift(1)

        print("🔨 Feature Engineering: Micro (Dollar Bar) Oscillators")
        df['Micro_RSI_14'] = ta.momentum.RSIIndicator(df['Close'], window=14).rsi().shift(1)
        macd = ta.trend.MACD(df['Close'], window_slow=26, window_fast=12, window_sign=9)
        df['Micro_MACD_Hist'] = macd.macd_diff().shift(1)
        bb = ta.volatility.BollingerBands(df['Close'], window=20, window_dev=2)
        df['Micro_BB_ZScore'] = ((df['Close'] - bb.bollinger_mavg()) / (df['Close'].rolling(20).std() + 1e-9)).shift(1)
        df['Micro_ROC_5'] = ta.momentum.ROCIndicator(df['Close'], window=5).roc().shift(1)
        # MFI (Money Flow Index) Requires High, Low, Close, Volume
        df['Micro_MFI_5'] = ta.volume.MFIIndicator(high=df['High'], low=df['Low'], close=df['Close'], volume=df['Total_Volume'], window=5).money_flow_index().shift(1)

        # --- MAKRO M15 INDIKÁTOROK KISZÁMÍTÁSA HELYESEN ---
        print("🔨 Feature Engineering: Macro (M15) Oscillators (Resampled)")
        # Ahelyett, hogy a Dollar Barok felett rollolnánk, csinálunk egy valódi idősíkot
        df_temp = df.copy()
        df_temp.set_index('End_Timestamp', inplace=True)

        # M15 aggregáció (Igazi OHLC gyertyák a volume-mal)
        # Fontos: label='right', closed='right' garantálja, hogy a gyertya csak a 15. perc végén jön létre,
        # megakadályozva a jövőbe látást (Data Leakage) a merge során.
        # Itt hozzáadjuk az 'agg' funkciót, hogy az idősíkban a High, Low, és Volume is meglegyen az MFI számára.
        m15_ohlcv = df_temp.resample('15Min', label='right', closed='right').agg({
            'Open': 'first',
            'High': 'max',
            'Low': 'min',
            'Close': 'last',
            'Total_Volume': 'sum'
        })
        m15_ohlcv = m15_ohlcv.dropna()

        if len(m15_ohlcv) > 30:
            m15_ohlcv['M15_RSI_14_Raw'] = ta.momentum.RSIIndicator(m15_ohlcv['Close'], window=14).rsi()
            macd_m15 = ta.trend.MACD(m15_ohlcv['Close'], window_slow=26, window_fast=12, window_sign=9)
            m15_ohlcv['M15_MACD_Hist_Raw'] = macd_m15.macd_diff()
            bb_m15 = ta.volatility.BollingerBands(m15_ohlcv['Close'], window=20, window_dev=2)
            m15_ohlcv['M15_BB_ZScore_Raw'] = (m15_ohlcv['Close'] - bb_m15.bollinger_mavg()) / (m15_ohlcv['Close'].rolling(20).std() + 1e-9)
            m15_ohlcv['M15_ROC_5_Raw'] = ta.momentum.ROCIndicator(m15_ohlcv['Close'], window=5).roc()
            m15_ohlcv['M15_MFI_5_Raw'] = ta.volume.MFIIndicator(high=m15_ohlcv['High'], low=m15_ohlcv['Low'], close=m15_ohlcv['Close'], volume=m15_ohlcv['Total_Volume'], window=5).money_flow_index()

            # Forward Fill rá a Dollar Barokra
            # Indexet visszaállítjuk
            m15_ohlcv = m15_ohlcv.reset_index()
            # Csatlakozás "asof" (azaz a legutolsó lezárt M15 értéket kapja meg a Dollar Bar)
            df = pd.merge_asof(df.sort_values('End_Timestamp'), m15_ohlcv[['End_Timestamp', 'M15_RSI_14_Raw', 'M15_MACD_Hist_Raw', 'M15_BB_ZScore_Raw', 'M15_ROC_5_Raw', 'M15_MFI_5_Raw']], on='End_Timestamp', direction='backward')

            # Data Leakage védelem: A Macro értékeket is shifeljük, hogy biztosan csak a MÚLTAT lássa a modell
            df['M15_RSI_14'] = df['M15_RSI_14_Raw'].shift(1)
            df['M15_MACD_Hist'] = df['M15_MACD_Hist_Raw'].shift(1)
            df['M15_BB_ZScore'] = df['M15_BB_ZScore_Raw'].shift(1)
            df['M15_ROC_5'] = df['M15_ROC_5_Raw'].shift(1)
            df['M15_MFI_5'] = df['M15_MFI_5_Raw'].shift(1)

            df.drop(['M15_RSI_14_Raw', 'M15_MACD_Hist_Raw', 'M15_BB_ZScore_Raw', 'M15_ROC_5_Raw', 'M15_MFI_5_Raw'], axis=1, inplace=True)
        else:
            print("⚠️ Nincs elég adat az M15 resample-hez, kimarad.")
            df['M15_RSI_14'] = 0
            df['M15_MACD_Hist'] = 0
            df['M15_BB_ZScore'] = 0
            df['M15_ROC_5'] = 0
            df['M15_MFI_5'] = 0

        # --- MAKRO M30 INDIKÁTOROK KISZÁMÍTÁSA HELYESEN ---
        print("🔨 Feature Engineering: Macro (M30) Oscillators (Resampled)")
        m30_ohlcv = df_temp.resample('30Min', label='right', closed='right').agg({
            'Open': 'first',
            'High': 'max',
            'Low': 'min',
            'Close': 'last',
            'Total_Volume': 'sum'
        })
        m30_ohlcv = m30_ohlcv.dropna()

        if len(m30_ohlcv) > 30:
            m30_ohlcv['M30_RSI_14_Raw'] = ta.momentum.RSIIndicator(m30_ohlcv['Close'], window=14).rsi()
            macd_m30 = ta.trend.MACD(m30_ohlcv['Close'], window_slow=26, window_fast=12, window_sign=9)
            m30_ohlcv['M30_MACD_Hist_Raw'] = macd_m30.macd_diff()
            bb_m30 = ta.volatility.BollingerBands(m30_ohlcv['Close'], window=20, window_dev=2)
            m30_ohlcv['M30_BB_ZScore_Raw'] = (m30_ohlcv['Close'] - bb_m30.bollinger_mavg()) / (m30_ohlcv['Close'].rolling(20).std() + 1e-9)
            m30_ohlcv['M30_ROC_5_Raw'] = ta.momentum.ROCIndicator(m30_ohlcv['Close'], window=5).roc()
            m30_ohlcv['M30_MFI_5_Raw'] = ta.volume.MFIIndicator(high=m30_ohlcv['High'], low=m30_ohlcv['Low'], close=m30_ohlcv['Close'], volume=m30_ohlcv['Total_Volume'], window=5).money_flow_index()

            # M30 Távolság (mivel az EA még nem adja ki a nyers csv-be)
            m30_ohlcv['30m_Close_Resampled'] = m30_ohlcv['Close']

            m30_ohlcv = m30_ohlcv.reset_index()
            df = pd.merge_asof(df.sort_values('End_Timestamp'), m30_ohlcv[['End_Timestamp', '30m_Close_Resampled', 'M30_RSI_14_Raw', 'M30_MACD_Hist_Raw', 'M30_BB_ZScore_Raw', 'M30_ROC_5_Raw', 'M30_MFI_5_Raw']], on='End_Timestamp', direction='backward')

            # Most már van 30m_Close a CSV-ből (prado_dollar_bars továbbítja), de ha valamiért nincs, használjuk a resample-ből
            df['30m_Close_Proxy'] = df.get('30m_Close', df['30m_Close_Resampled'])
            df['Dist_30m'] = ((df['Close'] - df['30m_Close_Proxy']) / df['Close'] * 100).shift(1)

            df['M30_RSI_14'] = df['M30_RSI_14_Raw'].shift(1)
            df['M30_MACD_Hist'] = df['M30_MACD_Hist_Raw'].shift(1)
            df['M30_BB_ZScore'] = df['M30_BB_ZScore_Raw'].shift(1)
            df['M30_ROC_5'] = df['M30_ROC_5_Raw'].shift(1)
            df['M30_MFI_5'] = df['M30_MFI_5_Raw'].shift(1)

            # Remove proxy cols but KEEP original '30m_Close' if it was there (so we don't drop something we might need later)
            df.drop(['30m_Close_Proxy', '30m_Close_Resampled', 'M30_RSI_14_Raw', 'M30_MACD_Hist_Raw', 'M30_BB_ZScore_Raw', 'M30_ROC_5_Raw', 'M30_MFI_5_Raw'], axis=1, inplace=True)
        else:
            print("⚠️ Nincs elég adat az M30 resample-hez, kimarad.")
            df['Dist_30m'] = 0
            df['M30_RSI_14'] = 0
            df['M30_MACD_Hist'] = 0
            df['M30_BB_ZScore'] = 0
            df['M30_ROC_5'] = 0
            df['M30_MFI_5'] = 0

        # Drop NaN-s caused by rolling windows and shifts
        df = df.dropna().copy()

        # --- IDŐSZAK SZŰRÉS (Kikapcsolva: 0-24 nonstop megy) ---
        print("🔨 Trading Hours: 00:00 - 24:00 (Nonstop)")
        # Korábban szűrtük a távolkeleti piacot, most minden adat bent marad

        print(f"💾 Saving processed features: {self.output_path} ({len(df)} rows)")
        df.to_csv(self.output_path, index=False)
        return df

if __name__ == '__main__':
    import sys

    input_csv = '/home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv'
    if len(sys.argv) > 1:
        input_csv = sys.argv[1]

    out_dir = os.path.dirname(input_csv)
    out_csv = os.path.join(out_dir, 'features_dollar_bars.csv')

    engineer = MTFFeatureEngineer(input_csv, out_csv)
    engineer.process()
