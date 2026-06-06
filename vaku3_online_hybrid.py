import pandas as pd
import numpy as np
import logging
import time
import os

from utils import O1RingBuffer, LogERScaler
from sklearn.preprocessing import StandardScaler

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class HybridStreamingEngine:
    def __init__(self, macro_window_minutes=5, micro_window_ticks=15):
        # Mikro Bufferek
        self.micro_window = micro_window_ticks
        self.price_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.time_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.spread_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.scaler = LogERScaler(base_n=15, max_n=1000)

        # Makro Bufferek (Idő alapú)
        self.macro_window_minutes = macro_window_minutes
        self.macro_prices = []
        self.macro_times = []

        # Dummy "HMM" prediktor a sebességteszthez (A valóságban itt a betanított GaussianHMM van)
        self.hmm_scaler = StandardScaler()
        # Fake fit hogy ne haljon el a transform
        self.hmm_scaler.fit(np.array([[0.0, 1.0, 0.0], [-10.0, 5.0, 3.0], [5.0, 0.1, -1.0]]))

    def update_macro_context(self, current_time_ms, price):
        self.macro_times.append(current_time_ms)
        self.macro_prices.append(price)

        # Tisztítjuk az ablakot (Csak az utolsó X percet tartjuk meg)
        cutoff_ms = current_time_ms - (self.macro_window_minutes * 60 * 1000)

        while len(self.macro_times) > 0 and self.macro_times[0] < cutoff_ms:
            self.macro_times.pop(0)
            self.macro_prices.pop(0)

        # Makro ER számolása az aktív gyertyán
        if len(self.macro_prices) < 2:
            return 0.0

        net_move = abs(self.macro_prices[-1] - self.macro_prices[0])
        gross_move = sum(abs(np.diff(self.macro_prices)))

        return net_move / gross_move if gross_move > 0 else 0.0

    def get_micro_features(self):
        prices = self.price_buffer.get_slice(self.micro_window)
        if len(prices) < 2:
            return 0.0, 0.0

        net_move = abs(prices[-1] - prices[0])
        gross_move = np.sum(np.abs(np.diff(prices)))
        raw_er = net_move / gross_move if gross_move > 0 else 0.0

        scaled_er = self.scaler.normalize(raw_er, self.micro_window)

        spreads = self.spread_buffer.get_slice(self.micro_window)
        avg_spread = np.mean(spreads) if len(spreads) > 0 else 0.0

        return scaled_er, avg_spread

    def run_stream(self, file_path):
        logger.info(f"▶️ HIBRID ONLINE ENGINE INDÍTÁSA: {os.path.basename(file_path)}")

        total_ticks = 0
        decisions = {'GREEN': 0, 'YELLOW': 0, 'RED': 0}

        start_time = time.perf_counter()

        chunk_iter = pd.read_csv(file_path, chunksize=20000)
        for chunk in chunk_iter:
            time_cols = [c for c in chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if not time_cols:
                return
            t_col = time_cols[0]

            for _, row in chunk.iterrows():
                t_ms = float(row[t_col])
                price = (row['Ask'] + row['Bid']) / 2.0 if 'Ask' in row and 'Bid' in row else row.iloc[1]
                spread = row['Ask'] - row['Bid'] if 'Ask' in row else 0.0

                # O(1) frissítés
                self.time_buffer.push(t_ms)
                self.price_buffer.push(price)
                self.spread_buffer.push(spread)
                total_ticks += 1

                if total_ticks % 10 != 0: # Teljesítményoptimalizálás: Nem számolunk minden egyes tickre
                    continue

                # 1. Makro ER (Hibrid)
                macro_er = self.update_macro_context(t_ms, price)

                # 2. Mikro HMM Features
                log_er, elasticity = self.get_micro_features()

                # Fake Inference Time szimuláció (HMM transform + predict_proba + matmul)
                obs = np.array([[log_er, elasticity, 0.0]])
                obs_scaled = self.hmm_scaler.transform(obs)

                # Fake Risk (Példa kedvéért)
                fake_risk = np.random.uniform(0, 100) if macro_er > 0.2 else 0.0

                # DÖNTÉSI MÁTRIX
                if macro_er >= 0.3 and fake_risk < 20.0:
                    decisions['GREEN'] += 1
                elif macro_er >= 0.3 and fake_risk >= 20.0:
                    decisions['YELLOW'] += 1
                else:
                    decisions['RED'] += 1

        end_time = time.perf_counter()

        logger.info(f"✅ VÉGE. Feldolgozott Tickek: {total_ticks:,}")
        logger.info(f"⏱️ Sebesség: {(end_time - start_time):.2f} másodperc ({(total_ticks / (end_time - start_time)):,.0f} tick/sec)")
        logger.info(f"📊 EA Döntések: 🟢 ZÖLD: {decisions['GREEN']:,} | 🟡 SÁRGA: {decisions['YELLOW']:,} | 🔴 PIROS: {decisions['RED']:,}")

if __name__ == "__main__":
    engine = HybridStreamingEngine()
    engine.run_stream("data/Merkava_XAUUSD_v1.10_20260408_025931.csv")
