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

        # Ensure we don't divide by zero
        total_vol = df['Total_Volume'] + 1e-9

        print("🔨 Feature Engineering: Order Book Imbalance (OBI)")
        df['OBI_Raw'] = (df['Ask_Volume'] - df['Bid_Volume']) / total_vol
        rolling_obi_mean = df['OBI_Raw'].rolling(100).mean()
        rolling_obi_std = df['OBI_Raw'].rolling(100).std() + 1e-9
        df['OBI_ZScore'] = ((df['OBI_Raw'] - rolling_obi_mean) / rolling_obi_std).shift(1)

        print("🔨 Feature Engineering: Price Velocity & Tick Speed")
        df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
        df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
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
        # RSI 14
        df['Micro_RSI_14'] = ta.momentum.RSIIndicator(df['Close'], window=14).rsi().shift(1)

        # MACD (12, 26, 9) Momentum (Histogram)
        macd = ta.trend.MACD(df['Close'], window_slow=26, window_fast=12, window_sign=9)
        df['Micro_MACD_Hist'] = macd.macd_diff().shift(1)

        # Bollinger Bands Z-Score (Distance from mid normalized by std)
        bb = ta.volatility.BollingerBands(df['Close'], window=20, window_dev=2)
        df['Micro_BB_ZScore'] = ((df['Close'] - bb.bollinger_mavg()) / (df['Close'].rolling(20).std() + 1e-9)).shift(1)

        # --- MAKRO M15 INDIKÁTOROK SZIMULÁLÁSA FORWARD FILL-LEL ---
        # Mivel a Dollar Barhoz már hozzá van fűzve a "15m_Close", ebből az oszlopból kiszámoljuk a makro indikátorokat.
        # Megjegyzés: Ez nem a tökéletes OHLC M15, hanem az aktuális gyertyában érvényes legfrissebb M15 záróár (amely ritkábban változik).
        print("🔨 Feature Engineering: Macro (M15) Oscillators (Proxy)")

        df['M15_RSI_14'] = ta.momentum.RSIIndicator(df['15m_Close'], window=14).rsi().shift(1)

        macd_m15 = ta.trend.MACD(df['15m_Close'], window_slow=26, window_fast=12, window_sign=9)
        df['M15_MACD_Hist'] = macd_m15.macd_diff().shift(1)

        # M15 BB Z-Score
        bb_m15 = ta.volatility.BollingerBands(df['15m_Close'], window=20, window_dev=2)
        df['M15_BB_ZScore'] = ((df['15m_Close'] - bb_m15.bollinger_mavg()) / (df['15m_Close'].rolling(20).std() + 1e-9)).shift(1)

        # Drop NaN-s caused by rolling windows and shifts
        df = df.dropna().copy()

        print(f"💾 Saving processed features: {self.output_path} ({len(df)} rows)")
        df.to_csv(self.output_path, index=False)
        return df

if __name__ == '__main__':
    import sys

    # A "features_dollar_bars.csv" mostantól sokkal több oszlopot fog tartalmazni.
    # Ahhoz, hogy az új feature-ök meglegyenek, a sima "dollar_bars.csv"-ből kell kiindulnunk.
    input_csv = '/home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv'
    if len(sys.argv) > 1:
        input_csv = sys.argv[1]

    out_dir = os.path.dirname(input_csv)
    out_csv = os.path.join(out_dir, 'features_dollar_bars.csv')

    engineer = MTFFeatureEngineer(input_csv, out_csv)
    engineer.process()
