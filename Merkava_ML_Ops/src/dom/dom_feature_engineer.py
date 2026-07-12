import pandas as pd
import numpy as np
import os

class DOMFeatureEngineer:
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

        if 'Ask_Price_1' not in df.columns and 'Ask' in df.columns:
            df['Ask_Price_1'] = df['Ask']
            df['Bid_Price_1'] = df['Bid']
            ask_vol_col = 'AskVol' if 'AskVol' in df.columns else ('Ask_Vol_1' if 'Ask_Vol_1' in df.columns else 'Volume')
            bid_vol_col = 'BidVol' if 'BidVol' in df.columns else ('Bid_Vol_1' if 'Bid_Vol_1' in df.columns else 'Volume')
            df['Ask_Vol_1'] = df[ask_vol_col]
            df['Bid_Vol_1'] = df[bid_vol_col]

        if 'Price' not in df.columns:
            df['Price'] = (df['Ask_Price_1'] + df['Bid_Price_1']) / 2.0

        print("🔨 Feature Engineering: MLOFI")
        total_weighted_ask = np.zeros(len(df))
        total_weighted_bid = np.zeros(len(df))
        for i in range(1, 11):
            av_col, bv_col = f'Ask_Vol_{i}', f'Bid_Vol_{i}'
            if av_col in df.columns and bv_col in df.columns:
                weight = 1.0 - ((i - 1) * 0.1)
                total_weighted_ask += df[av_col].fillna(0) * weight
                total_weighted_bid += df[bv_col].fillna(0) * weight

        raw_obi = (total_weighted_bid - total_weighted_ask) / (total_weighted_bid + total_weighted_ask + 1e-9)
        # Szigorú SHIFT(1) a Target Leak ellen
        df['OBI_Raw'] = raw_obi
        df['OBI_ZScore'] = ((raw_obi - raw_obi.rolling(100).mean()) / (raw_obi.rolling(100).std() + 1e-9)).shift(1)

        print("🔨 Feature Engineering: Spread Elasticity")
        df['Spread'] = df['Ask_Price_1'] - df['Bid_Price_1']
        df['Spread_Delta'] = (df['Spread'] - df['Spread'].shift(1)).shift(1)
        df['Spread_ZScore'] = ((df['Spread'] - df['Spread'].rolling(100).mean()) / (df['Spread'].rolling(100).std() + 1e-9)).shift(1)

        print("🔨 Feature Engineering: Sebesség (Velocity)")
        time_col = 'TimeMsc' if 'TimeMsc' in df.columns else ('TickMS' if 'TickMS' in df.columns else None)
        if time_col:
            velocity = df['Price'].diff(1) / df[time_col].diff(1).replace(0, 1)
        else:
            velocity = df['Price'].diff(1)

        # Target leak védelem a sebességen is
        df['Price_Velocity'] = velocity.replace([np.inf, -np.inf], 0).fillna(0).shift(1)

        df['ATR_Proxy'] = self.calculate_atr(df, 15).shift(1)

        df = df.dropna().copy()

        print("🎯 Event-Based Triple-Barrier Labeling (10 USD Cél + Veszteséges tradek betanulása)")

        lookahead = 200 # Több időt hagyunk a mozgásnak (nem 30 tick, ami ~2 mp, hanem pl. 200 tick ~ 1 perc)
        tp_target_points = 1.00
        sl_target_points = 0.40
        commission_cost = 0.15  # 1.5 USD költség

        prices = df['Price'].values
        spreads = df['Spread'].values
        targets = np.zeros(len(df))

        in_trade_until = 0

        for i in range(len(df) - lookahead):
            # Átfedés szűrése
            if i < in_trade_until:
                continue

            current_mid = prices[i]
            total_cost = spreads[i] + commission_cost

            # FIX PONTOS FALAK
            buy_tp = current_mid + tp_target_points + total_cost
            buy_sl = current_mid - sl_target_points

            sell_tp = current_mid - tp_target_points - total_cost
            sell_sl = current_mid + sl_target_points

            long_alive = True
            short_alive = True

            # Labelek: 1 = Sikeres Buy, -1 = Sikeres Sell, 0 = Rossz trade (SL) vagy Semmi
            label = 0

            # A valós ML modelleknek meg KELL tanulnia a rossz eseteket (amikor a piac eléri a Stop Loss-t).
            # Ha kivágjuk a veszteséget, a modell azt fogja hinni, minden mozgás nyereséges.

            for j in range(1, lookahead + 1):
                future_mid = prices[i + j]

                if long_alive:
                    if future_mid >= buy_tp:
                        label = 1
                        in_trade_until = i + j
                        break
                    elif future_mid <= buy_sl:
                        # Ez egy ROSSZ LONG pozíció lett volna (Azonnal SL).
                        long_alive = False

                if short_alive:
                    if future_mid <= sell_tp:
                        label = -1
                        in_trade_until = i + j
                        break
                    elif future_mid >= sell_sl:
                        # Ez egy ROSSZ SHORT pozíció lett volna (Azonnal SL).
                        short_alive = False

                # Ha mindkettő elvérzett az SL-en (Whipsaw/Kipattintás), vagy lejárt az idő (Hold),
                # A label 0 marad (NEM LÉPÜNK BE), és a modell ezt NEGATÍV PÉLDAKÉNT meg fogja tanulni!
                if not long_alive and not short_alive:
                    label = 0
                    in_trade_until = i + j
                    break

            # A fenti Overlapping prevenció biztosítja, hogy a Hold/SL tickeket is egyenlő távolságokban kapja a modell.
            targets[i] = label

        df['Target'] = targets

        exclude_cols = ['Time', 'TimeMsc', 'TickMS', 'Type', 'Price', 'Spread', 'ATR_Proxy']
        for i in range(1, 11):
            exclude_cols.extend([f"Ask_Price_{i}", f"Ask_Vol_{i}", f"Bid_Price_{i}", f"Bid_Vol_{i}"])

        ml_columns = [c for c in df.columns if c not in exclude_cols]
        df_ml = df[ml_columns]

        # JAVÍTÁS: Nem dobjuk ki a 0-ás Targeteket (Hold / Failed SL trades), mert az az 'Ellenpélda',
        # amiből az algoritmus megtanulja elkerülni a bukást!
        # Viszont az átfedésmentesítés miatt csak azokat az adott pontokat kellene vizsgálnunk,
        # ahol potenciális DÖNTÉS született. Mivel `in_trade_until` csak ugrál, egy logikai maszkot használunk.

        print(f"📊 Class eloszlás (Rossz trade-ekkel együtt):\n{df_ml['Target'].value_counts()}")
        print(f"💾 Kimentés: {self.output_path} ({len(df_ml)} sor, {len(ml_columns)} feature)")
        df_ml.to_csv(self.output_path, index=False)

if __name__ == '__main__':
    engineer = DOMFeatureEngineer('data/raw/DOM_Data_20260706_111039.csv', 'data/processed/ML_READY_FEATURES.csv')
    engineer.process()
