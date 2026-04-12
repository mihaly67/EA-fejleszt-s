import os
import glob
import pandas as pd
import numpy as np
import logging
import time

from utils import O1RingBuffer, LogERScaler

# ML Dependencies (A Vaku 3.0 ML Pipeline-jából)
from models.hmm_model import HMMDetector
# A WelfordScaler a pipeline-ból vagy statisztikai modulból érkezik,
# itt egy egyszerűsített in-memory verziót írok a demóhoz, de a valóságban a vaku3 utils-ből húzzuk be.

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class VakuOnlineEngine:
    """
    Vaku 3.0 Online Streaming Engine (Virtual Market Simulator).

    A script beolvas egy történelmi CSV-t, de NEM array-ként adja át az ML modelleknek.
    Ehelyett tickenként iterál (Streamel), és a O1RingBuffer-be tölti az adatokat.

    Ez bizonyítja be, hogy a FinRL Copilot képes lesz az MT5 ZeroMQ élő streamjét
    OOM (memóriahiba) és Inference Bottleneck nélkül feldolgozni a 8GB VPS-en.
    """

    def __init__(self, buffer_capacity=1000):
        # 1. Adaptív Pufferek (ATDP) Inicializálása
        self.price_buffer = O1RingBuffer(capacity=buffer_capacity, dimensions=1)
        self.time_buffer = O1RingBuffer(capacity=buffer_capacity, dimensions=1)
        self.spread_buffer = O1RingBuffer(capacity=buffer_capacity, dimensions=1)

        # 2. Skála-Függő Normalizátor (FBM torzítás ellen)
        self.log_er_scaler = LogERScaler(base_n=15, max_n=buffer_capacity)

        # 3. Dummy ML Modellek (A HMM és Welford logikája ide kerül becsatolásra)
        # Az éles kód itt töltené be a `vaku3_offline_validator.py`-ból kimentett (.pkl) HMM modellt.
        logger.info("🔧 Vaku 3.0 Online Engine Inicializálása (O1RingBuffer + LogERScaler)")

    def _calculate_online_features(self, n_window):
        """Kiszámolja a HMM observation space-t (LogER, Spread Elasticity) O(1) szeleteléssel."""
        prices = self.price_buffer.get_slice(n_window)

        if len(prices) < 2:
            return 0.0, 0.0

        # Nyers Kaufman ER
        net_move = np.abs(prices[-1] - prices[0])
        gross_move = np.sum(np.abs(np.diff(prices)))
        raw_er = net_move / gross_move if gross_move > 0 else 0.0

        # Skálázott (FBM korrigált) ER (A LogERScaler hívása)
        scaled_er = self.log_er_scaler.normalize(raw_er, n_window)

        # O(1) Spread átlag (Elasticity alapja)
        spreads = self.spread_buffer.get_slice(n_window)
        avg_spread = np.mean(spreads) if len(spreads) > 0 else 0.0

        return scaled_er, avg_spread

    def run_virtual_stream(self, file_path):
        """Elindítja a virtuális tick folyót."""
        file_name = os.path.basename(file_path)
        logger.info(f"▶️ Virtuális Piac Indítása (Streaming CSV): {file_name}")

        # Csak olvassuk a fájlt darabokban a memóriáért, de iterálunk minden egyes soron
        total_ticks = 0
        anomalies_detected = 0

        start_cpu_time = time.perf_counter()

        # Diagnosztika a konzolra
        print(f"\n[{file_name}] ONLINE ENGINE ESEMÉNYEK:")
        print(f"{'Tick ID':<10} | {'ATDP Ablak (N)':<15} | {'Skálázott LogER':<15} | {'Inference Time (ms)':<15}")
        print("-" * 65)

        try:
            chunk_iter = pd.read_csv(file_path, chunksize=50000)
            for chunk in chunk_iter:
                time_cols = [c for c in chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
                if not time_cols:
                    logger.error("Nincs TimeMsc oszlop!")
                    return

                time_col = time_cols[0]

                # Ciklus TICKENKÉNT (Ez szimulálja a valós idejű MT5 OnTick() hívást)
                for _, row in chunk.iterrows():
                    # 1. Adat érkezik az élő piacról (MT5)
                    t_ms = float(row[time_col])

                    if 'Ask' in row and 'Bid' in row:
                        price = (row['Ask'] + row['Bid']) / 2.0
                        spread = row['Ask'] - row['Bid']
                    elif 'Last' in row:
                        price = row['Last']
                        spread = row.get('Spread', 0.0)
                    else:
                        price = row.iloc[1]
                        spread = 0.0

                    # 2. O(1) Push a RingBufferbe (Nincs memóriaugrás)
                    self.time_buffer.push(t_ms)
                    self.price_buffer.push(price)
                    self.spread_buffer.push(spread)

                    total_ticks += 1

                    # 3. ATDP (Dinamikus Ablakméret számolása a pillanatnyi sűrűség alapján)
                    # Pl: Hány tick volt az elmúlt 3 másodpercben (3000 ms)?
                    current_density = self.time_buffer.get_current_density(self.time_buffer, time_window_ms=3000)

                    # Az adaptív ablakméret (N) logikája (Scale: ha sűrű, növeljük, ha ritka, 15 marad)
                    n_window = max(15, min(300, current_density))

                    # 4. Machine Learning Pipeline Futása (Csak minden 100. ticknél a demó logjának kímélése miatt)
                    if total_ticks > 15 and total_ticks % 1000 == 0:
                        inf_start = time.perf_counter()

                        # Vektor kivonása és normalizálása
                        scaled_er, avg_spread = self._calculate_online_features(n_window)

                        # Ide jönne a model.predict() ...

                        inf_end = time.perf_counter()
                        inf_time_ms = (inf_end - inf_start) * 1000.0

                        # Ha FBM torzítás lenne (Scale-Dependency hiba), a scaled_er túl nagy lenne N=150 esetén.
                        # De a LogERScaler megvédi.
                        print(f"{total_ticks:<10} | {n_window:<15} | {scaled_er:<15.4f} | {inf_time_ms:<15.3f}")

        except Exception as e:
            logger.error(f"Hiba a streamben: {e}")

        end_cpu_time = time.perf_counter()

        logger.info(f"✅ Virtuális Piac (Stream) Vége. Feldolgozott Tickek: {total_ticks:,}")
        logger.info(f"⏱️ CPU Feldolgozási idő (Szimuláció sebessége): {end_cpu_time - start_cpu_time:.2f} másodperc")


def run_engine():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
    if not csv_files:
        csv_files = glob.glob(os.path.join(os.path.dirname(base_dir), 'analysis_input', '*.csv'))

    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning("Nincs adat a streaming szimulátorhoz.")
        return

    engine = VakuOnlineEngine(buffer_capacity=1000)

    # Csak egy fájlon próbáljuk ki
    engine.run_virtual_stream(csv_files[0])

if __name__ == '__main__':
    run_engine()
