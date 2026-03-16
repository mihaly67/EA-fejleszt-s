import pandas as pd
import gc
import logging
import sys
import os

# Gyökérmappa hozzáadása a relatív importokhoz ha közvetlenül futtatjuk
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from utils.monitor import ResourceMonitor

logger = logging.getLogger(__name__)

class RobustDataLoader:
    """
    Kifejezetten 8GB RAM-os (vagy kisebb) környezetre tervezett adatbetöltő MT5 tick CSV-khez.
    A pandas chunking és usecols paramétereivel minimalizálja a memória lábnyomot.
    """
    def __init__(self, chunksize=100000):
        self.chunksize = chunksize
        self.monitor = ResourceMonitor()

    def load_tick_data(self, file_path, relevant_columns=None):
        if not os.path.exists(file_path):
            logger.error(f"Fájl nem található: {file_path}")
            raise FileNotFoundError(f"A kért fájl nem létezik: {file_path}")

        if not relevant_columns:
            # Csak az anomália detektáláshoz feltétlenül szükséges oszlopokat tartjuk meg
            # A 'DataMiner_BlackBox_v1_00.mqh' által biztosított valós fejlécek:
            relevant_columns = [
                "TickMSC", "Bid", "Ask", "Spread", "Ping_MS", "Ping",
                "Velocity", "Acceleration", "Flow_Delta", "Hybrid_DFCurve", "WPR"
            ]

        logger.info(f"Adatbetöltés indítása: {file_path}")
        self.monitor.log_usage("Betöltés Előtt")

        chunk_list = []
        try:
            # Chunking és column filtering
            for i, chunk in enumerate(pd.read_csv(file_path, usecols=lambda c: c in relevant_columns, chunksize=self.chunksize)):
                # Ha a rendszer RAM túl magas (pl. 90%), megállítjuk a betöltést a halál előtt
                if not self.monitor.check_memory_limit():
                     logger.warning(f"Memória korlát elérve a(z) {i}. chunknál. Betöltés megszakítva, csak az eddigi adatokat adjuk vissza.")
                     break

                chunk_list.append(chunk)
                logger.info(f"✔ Chunk {i+1} beolvasva ({len(chunk)} sor)")

            if not chunk_list:
                 logger.error("Nem sikerült egyetlen chunkot sem beolvasni. Rosszak az oszlopnevek?")
                 return pd.DataFrame()

            df_final = pd.concat(chunk_list, ignore_index=True)

            # Memória kitakarítása
            del chunk_list
            gc.collect()

            self.monitor.log_usage("Betöltés Után")
            logger.info(f"Sikeres adatbetöltés: {len(df_final)} sor.")
            return df_final

        except ValueError as e:
            logger.error(f"ValueError a betöltéskor (Oszlop hiba?): {e}")
            raise
        except Exception as e:
            logger.error(f"Kritikus hiba a betöltéskor: {e}")
            raise

if __name__ == "__main__":
     logging.basicConfig(level=logging.INFO)
     loader = RobustDataLoader(chunksize=1000)
     base_dir = os.path.dirname(os.path.abspath(__file__))
     test_file = os.path.join(base_dir, "..", "data", "mock_tick_data.csv")
     df = loader.load_tick_data(test_file)
     if not df.empty:
         print(f"Betöltött oszlopok: {list(df.columns)}")
         print(df.head())
