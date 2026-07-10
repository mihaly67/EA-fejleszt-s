import pandas as pd
import numpy as np
import os
from sklearn.preprocessing import StandardScaler

class DOMFeatureEngineer:
    """
    Ez az eszköz a 10-szintű DOM (Depth of Market) CSV fájlból készít
    olyan 'Microstructure Feature'-öket (OFI, Spread Elasticity, Imbalance Z-Score),
    amiket a LightGBM, XGBoost vagy LSTM fel tud dolgozni.
    """
    def __init__(self, data_path, output_path):
        self.data_path = data_path
        self.output_path = output_path

    def calculate_atr(self, df, period=7):
        if 'Bar_High' in df.columns:
            high_low = df["Bar_High"] - df["Bar_Low"]
            high_close = np.abs(df["Bar_High"] - df["Bar_Close"].shift())
            low_close = np.abs(df["Bar_Low"] - df["Bar_Close"].shift())
            ranges = pd.concat([high_low, high_close, low_close], axis=1)
            true_range = np.max(ranges, axis=1)
            return true_range.rolling(period).mean()
        else:
            return df['Price'].diff().abs().rolling(period).mean()

    def process(self):
        print(f"🔄 Adatok beolvasása: {self.data_path}")
        df = pd.read_csv(self.data_path)

        if 'Price' not in df.columns:
            df['Price'] = (df['Ask_Price_1'] + df['Bid_Price_1']) / 2.0

        print("🔨 Feature Engineering: MLOFI (Multi-Level Order Flow Imbalance)")
        total_weighted_ask = np.zeros(len(df))
        total_weighted_bid = np.zeros(len(df))

        for i in range(1, 11):
            ap_col = f'Ask_Price_{i}'
            av_col = f'Ask_Vol_{i}'
            bp_col = f'Bid_Price_{i}'
            bv_col = f'Bid_Vol_{i}'

            if av_col in df.columns and bv_col in df.columns:
                weight = 1.0 - ((i - 1) * 0.1)
                total_weighted_ask += df[av_col].fillna(0) * weight
                total_weighted_bid += df[bv_col].fillna(0) * weight

        raw_obi = (total_weighted_bid - total_weighted_ask) / (total_weighted_bid + total_weighted_ask + 1e-9)
        df['OBI_Raw'] = raw_obi
        df['OBI_ZScore'] = (raw_obi - raw_obi.rolling(100).mean()) / (raw_obi.rolling(100).std() + 1e-9)

        print("🔨 Feature Engineering: Spread Elasticity")
        df['Spread'] = df['Ask_Price_1'] - df['Bid_Price_1']
        df['Spread_Delta'] = df['Spread'] - df['Spread'].shift(1)
        df['Spread_ZScore'] = (df['Spread'] - df['Spread'].rolling(100).mean()) / (df['Spread'].rolling(100).std() + 1e-9)

        print("🔨 Feature Engineering: Sebesség (Velocity) és Ár Momentum")
        df['Return_1'] = df['Price'].pct_change(1)
        df['Return_5'] = df['Price'].pct_change(5)
        df['Price_Velocity'] = df['Price'].diff(1) / df['TimeMsc'].diff(1).replace(0, 1)

        print("🔨 Feature Engineering: ATR és Relatív Távolságok")
        df['ATR_Proxy'] = self.calculate_atr(df, 15)

        df = df.dropna().copy()

        print("🎯 Valódi Triple-Barrier Labeling (Scalpinghoz optimalizálva)")
        lookahead = 15
        tp_mult = 0.2 # Take Profit (ATR szorzó)
        sl_mult = 0.15 # Stop Loss (ATR szorzó)

        closes = df['Price'].values
        atrs = df['ATR_Proxy'].values
        targets = np.zeros(len(df))
        target_returns = np.zeros(len(df))

        for i in range(len(df) - lookahead):
            current = closes[i]
            if atrs[i] == 0: continue

            upper_barrier = current + (atrs[i] * tp_mult)
            lower_barrier = current - (atrs[i] * sl_mult)

            label = 0 # Hold

            # Végignézzük az ablakot (Barrier érintés vizsgálata)
            for j in range(1, lookahead + 1):
                future_price = closes[i + j]

                # Ha elérte a felső korlátot hamarabb -> BUY nyer
                if future_price >= upper_barrier:
                    label = 1
                    break
                # Ha elérte az alsó korlátot hamarabb -> SELL nyer
                elif future_price <= lower_barrier:
                    label = -1
                    break

            targets[i] = label
            # Regression target: A valós elmozdulás a lookahead végén
            target_returns[i] = (closes[i + lookahead] - current) / current

        df['Target'] = targets
        df['Target_Return'] = target_returns

        exclude_cols = ['Time', 'TimeMsc', 'Type', 'Price']
        for i in range(1, 11):
            exclude_cols.extend([f"Ask_Price_{i}", f"Ask_Vol_{i}", f"Bid_Price_{i}", f"Bid_Vol_{i}"])

        ml_columns = [c for c in df.columns if c not in exclude_cols]
        df_ml = df[ml_columns]

        print(f"📊 Class eloszlás a Triple-Barrier után:\n{df_ml['Target'].value_counts()}")
        print(f"💾 Kimentés: {self.output_path} ({len(df_ml)} sor, {len(ml_columns)} feature)")
        df_ml.to_csv(self.output_path, index=False)

if __name__ == '__main__':
    engineer = DOMFeatureEngineer('/home/misi/Merkava_ML_Ops/data/raw/DOM_Data_10Level.csv', '/home/misi/Merkava_ML_Ops/data/processed/ML_READY_FEATURES.csv')
    # A fenti elérési útvonalat módosíthatod a tényleges CSV fájlod helyére, ami a te VPS-eden van.
    # Jelenleg csak illusztráció a kód.
    # engineer.process()
