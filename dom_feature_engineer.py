#!/usr/bin/env python3
import pandas as pd
import numpy as np
import os
import glob
import sys

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

        # Fallback ha 1-szintű a CSV (Demo account pl.)
        if 'Ask_Price_1' not in df.columns and 'Ask' in df.columns:
            print("⚠️ 1-szintű (L1) DOM CSV formátum detektálva! Adatok konvertálása 10-szintű formátumra (üres mélységgel)...")
            df['Ask_Price_1'] = df['Ask']
            df['Bid_Price_1'] = df['Bid']

            # Keresünk Volume oszlopot
            ask_vol_col = 'AskVol' if 'AskVol' in df.columns else ('Ask_Vol_1' if 'Ask_Vol_1' in df.columns else 'Volume')
            bid_vol_col = 'BidVol' if 'BidVol' in df.columns else ('Bid_Vol_1' if 'Bid_Vol_1' in df.columns else 'Volume')

            df['Ask_Vol_1'] = df[ask_vol_col]
            df['Bid_Vol_1'] = df[bid_vol_col]

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

        time_col = 'TimeMsc' if 'TimeMsc' in df.columns else ('TickMS' if 'TickMS' in df.columns else None)
        if time_col:
            df['Price_Velocity'] = df['Price'].diff(1) / df[time_col].diff(1).replace(0, 1)
        else:
            df['Price_Velocity'] = df['Price'].diff(1) # Fallback

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

            for j in range(1, lookahead + 1):
                future_price = closes[i + j]
                if future_price >= upper_barrier:
                    label = 1
                    break
                elif future_price <= lower_barrier:
                    label = -1
                    break

            targets[i] = label
            target_returns[i] = (closes[i + lookahead] - current) / current

        df['Target'] = targets
        df['Target_Return'] = target_returns

        exclude_cols = ['Time', 'TimeMsc', 'TickMS', 'Type', 'Price']
        for i in range(1, 11):
            exclude_cols.extend([f"Ask_Price_{i}", f"Ask_Vol_{i}", f"Bid_Price_{i}", f"Bid_Vol_{i}"])

        ml_columns = [c for c in df.columns if c not in exclude_cols]
        df_ml = df[ml_columns]

        print(f"📊 Class eloszlás a Triple-Barrier után:\n{df_ml['Target'].value_counts()}")
        print(f"💾 Kimentés: {self.output_path} ({len(df_ml)} sor, {len(ml_columns)} feature)")
        df_ml.to_csv(self.output_path, index=False)

if __name__ == '__main__':
    # Auto-keresés
    raw_dir = "/home/misi/Merkava_ML_Ops/data/raw/"
    csv_file = None
    if os.path.exists(raw_dir):
        dom_files = glob.glob(os.path.join(raw_dir, "*DOM*.csv"))
        if dom_files: csv_file = max(dom_files, key=os.path.getmtime)

    if not csv_file:
        local_files = glob.glob("*DOM*.csv")
        if local_files: csv_file = max(local_files, key=os.path.getmtime)
        else:
            print("❌ Nem talalhato DOM CSV fajl az adatok elokeszitesehez.")
            sys.exit(1)

    out_file = "ML_READY_FEATURES.csv"
    engineer = DOMFeatureEngineer(csv_file, out_file)
    engineer.process()
