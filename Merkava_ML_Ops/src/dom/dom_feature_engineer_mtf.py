import pandas as pd
import numpy as np
import os

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
        # Calculate raw OBI for the bar: (Ask_Vol - Bid_Vol) / Total_Vol
        # Reminder: Ask_Vol = Buy pressure (market buyers hitting asks)
        # Bid_Vol = Sell pressure (market sellers hitting bids)
        df['OBI_Raw'] = (df['Ask_Volume'] - df['Bid_Volume']) / total_vol

        # Z-Score OBI (Rolling 100 bars)
        # SHIFT(1) is CRITICAL to prevent data leakage (predicting current bar using current bar's OBI)
        rolling_obi_mean = df['OBI_Raw'].rolling(100).mean()
        rolling_obi_std = df['OBI_Raw'].rolling(100).std() + 1e-9
        df['OBI_ZScore'] = ((df['OBI_Raw'] - rolling_obi_mean) / rolling_obi_std).shift(1)

        print("🔨 Feature Engineering: Price Velocity")
        # Time difference in seconds between bars
        df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
        df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])

        # Time it took to form the Dollar Bar
        df['Bar_Time_Seconds'] = (df['End_Timestamp'] - df['Start_Timestamp']).dt.total_seconds().replace(0, 1) # Prevent div by 0

        # Velocity = Price Change / Time
        velocity = df['Close'].diff(1) / df['Bar_Time_Seconds']
        df['Price_Velocity'] = velocity.replace([np.inf, -np.inf], 0).fillna(0).shift(1)

        # Tick Speed (Activity proxy: How fast the dollar bar was filled)
        # Lower time = Higher Speed (more aggressive market)
        df['Tick_Speed'] = (1.0 / df['Bar_Time_Seconds']).shift(1)

        print("🔨 Feature Engineering: Macro Confluence")
        # Distance to MTF Closings (Proxy for short term trend)
        df['Dist_1m'] = ((df['Close'] - df['1m_Close']) / df['Close'] * 100).shift(1)
        df['Dist_5m'] = ((df['Close'] - df['5m_Close']) / df['Close'] * 100).shift(1)
        df['Dist_15m'] = ((df['Close'] - df['15m_Close']) / df['Close'] * 100).shift(1)

        print("🔨 Feature Engineering: ATR Proxy")
        df['ATR_Proxy'] = self.calculate_atr(df, 15).shift(1)

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
