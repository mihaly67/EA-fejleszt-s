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

        # Ha nincs megadva specifikus oszloplista, akkor az összes DataMiner BlackBox v1.00
        # (Physics, Context EMAs, Flow, Momentum) oszlopot betöltjük. Nincs több szándékos adatvesztés.
        logger.info(f"Adatbetöltés indítása: {file_path}")
        self.monitor.log_usage("Betöltés Előtt")

        chunk_list = []
        try:
            # Chunking filtering paraméter összeállítása
            read_kwargs = {'chunksize': self.chunksize}
            if relevant_columns:
                read_kwargs['usecols'] = lambda c: c in relevant_columns

            # Teljes CSV felolvasása (vagy a megadott oszlopoké)
            for i, chunk in enumerate(pd.read_csv(file_path, **read_kwargs)):
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

            # ---- BEHAVIORAL PROFILING: Tick Sűrűség (Lefagyás) Számítás ----
            # Ha van TickMSC vagy TimeMsc oszlop, kiszámoljuk a két tick közötti időt.
            # Ebből az LSTM azonnal látni fogja, ha a bróker "lefagyasztja" a chartot (pl. 60000 ms = 1 perc).
            time_col = None
            if 'TickMSC' in df_final.columns:
                time_col = 'TickMSC'
            elif 'TimeMsc' in df_final.columns:
                time_col = 'TimeMsc'

            if time_col:
                # Kiszámoljuk az időeltolódást ms-ban. Az első sornál NaN lesz, amit 0-ra állítunk.
                df_final['Time_Delta_MS'] = df_final[time_col].diff().fillna(0)
                # Ha véletlenül negatív lenne (óra átállítás vagy rossz sorrend), 0-ra cseréljük
                df_final['Time_Delta_MS'] = df_final['Time_Delta_MS'].clip(lower=0)
                logger.info(f"✔ 'Time_Delta_MS' (Tick Sűrűség / Lefagyás) indikátor kiszámítva a '{time_col}' alapján.")
            else:
                # Fallback, ha nincs milliszekundum, csak 'Time' (másodperc).
                # Megpróbáljuk datetime-má alakítani és másodpercben kifejezni, majd ms-ra váltani.
                if 'Time' in df_final.columns:
                    try:
                        df_final['Time_Parsed'] = pd.to_datetime(df_final['Time'], errors='coerce')
                        df_final['Time_Delta_MS'] = df_final['Time_Parsed'].diff().dt.total_seconds().fillna(0) * 1000
                        df_final['Time_Delta_MS'] = df_final['Time_Delta_MS'].clip(lower=0)
                        df_final.drop(columns=['Time_Parsed'], inplace=True)
                        logger.info(f"✔ 'Time_Delta_MS' (Tick Sűrűség / Lefagyás) indikátor kiszámítva a 'Time' alapján.")
                    except Exception as e:
                        logger.warning(f"Nem sikerült a Time oszlopból delta-t számolni: {e}")
                        df_final['Time_Delta_MS'] = 0
                else:
                    logger.warning("Nem találtam Time vagy TickMSC oszlopot a fájlban, 'Time_Delta_MS' nullázva.")
                    df_final['Time_Delta_MS'] = 0

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
