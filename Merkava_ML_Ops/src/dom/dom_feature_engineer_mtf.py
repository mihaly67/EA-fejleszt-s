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
        df['Dist_1m'] = ((df['Close'] - df['1m_Close']) / df['Close'] * 100).shift(1)
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

        # --- MAKRO M15 INDIKÁTOROK KISZÁMÍTÁSA HELYESEN ---
        print("🔨 Feature Engineering: Macro (M15) Oscillators (Resampled)")
        # Ahelyett, hogy a Dollar Barok felett rollolnánk, csinálunk egy valódi idősíkot
        df_temp = df.copy()
        df_temp.set_index('End_Timestamp', inplace=True)

        # M15 aggregáció (Igazi OHLC gyertyák)
        # Fontos: label='right', closed='right' garantálja, hogy a gyertya csak a 15. perc végén jön létre,
        # megakadályozva a jövőbe látást (Data Leakage) a merge során.
        m15_ohlc = df_temp['Close'].resample('15Min', label='right', closed='right').ohlc()
        m15_ohlc = m15_ohlc.dropna()

        if len(m15_ohlc) > 30:
            m15_ohlc['M15_RSI_14_Raw'] = ta.momentum.RSIIndicator(m15_ohlc['close'], window=14).rsi()
            macd_m15 = ta.trend.MACD(m15_ohlc['close'], window_slow=26, window_fast=12, window_sign=9)
            m15_ohlc['M15_MACD_Hist_Raw'] = macd_m15.macd_diff()
            bb_m15 = ta.volatility.BollingerBands(m15_ohlc['close'], window=20, window_dev=2)
            m15_ohlc['M15_BB_ZScore_Raw'] = (m15_ohlc['close'] - bb_m15.bollinger_mavg()) / (m15_ohlc['close'].rolling(20).std() + 1e-9)

            # Forward Fill rá a Dollar Barokra
            # Indexet visszaállítjuk
            m15_ohlc = m15_ohlc.reset_index()
            # Csatlakozás "asof" (azaz a legutolsó lezárt M15 értéket kapja meg a Dollar Bar)
            df = pd.merge_asof(df.sort_values('End_Timestamp'), m15_ohlc[['End_Timestamp', 'M15_RSI_14_Raw', 'M15_MACD_Hist_Raw', 'M15_BB_ZScore_Raw']], on='End_Timestamp', direction='backward')

            # Data Leakage védelem: A Macro értékeket is shifeljük, hogy biztosan csak a MÚLTAT lássa a modell
            df['M15_RSI_14'] = df['M15_RSI_14_Raw'].shift(1)
            df['M15_MACD_Hist'] = df['M15_MACD_Hist_Raw'].shift(1)
            df['M15_BB_ZScore'] = df['M15_BB_ZScore_Raw'].shift(1)

            df.drop(['M15_RSI_14_Raw', 'M15_MACD_Hist_Raw', 'M15_BB_ZScore_Raw'], axis=1, inplace=True)
        else:
            print("⚠️ Nincs elég adat az M15 resample-hez, kimarad.")
            df['M15_RSI_14'] = 0
            df['M15_MACD_Hist'] = 0
            df['M15_BB_ZScore'] = 0

        # Drop NaN-s caused by rolling windows and shifts
        df = df.dropna().copy()

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
