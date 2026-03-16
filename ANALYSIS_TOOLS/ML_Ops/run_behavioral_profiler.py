import os
import glob
import pandas as pd
import logging
from pipeline.data_loader import RobustDataLoader
from models.lstm_autoencoder import LSTMAutoencoderDetector

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def run_profiler():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'analyzed')

    # Biztosítsuk, hogy az output mappa létezik
    os.makedirs(output_dir, exist_ok=True)

    # Keresünk minden olyan CSV-t, amit profilozni kell (kihagyjuk az eleve "ANALYZED_" kezdetűeket és a mock adatot)
    csv_files = [f for f in glob.glob(os.path.join(data_dir, "*.csv"))
                 if not os.path.basename(f).startswith("ANALYZED_")
                 and not os.path.basename(f) == "mock_tick_data.csv"]

    if not csv_files:
        logger.error(f"Nem találtam elemezendő CSV fájlokat a {data_dir} mappában!")
        logger.info("Másold ide a Merkava_Behavioral_Profiler_v1.1.mq5 által generált CSV fájlokat (pl. BlackBox_*.csv).")
        return

    logger.info(f"Összesen {len(csv_files)} db CSV fájlt találtam profilozásra.")

    loader = RobustDataLoader(chunksize=5000) # RAM kímélő betöltés

    for file_path in csv_files:
        file_name = os.path.basename(file_path)
        logger.info(f"\n{'='*50}\n[FELDOLGOZÁS KEZDÉSE] Fájl: {file_name}\n{'='*50}")

        # 1. Betöltés (Teljes CSV a BlackBox_v2_10 összes oszlopával)
        df_original = loader.load_tick_data(file_path)

        if df_original.empty:
            logger.warning(f"A fájl {file_name} üres, kihagyjuk.")
            continue

        # 2. LSTM Inicializálása minden fájlhoz külön (hogy az adott instrumentum/időszak dinamikáját tanulja meg)
        # Nehéztüzérség bevetése: CPU optimalizált, RAM kímélő batch_size
        lstm = LSTMAutoencoderDetector(seq_length=30, latent_dim=8, batch_size=256, epochs=5)

        # 3. Betanítás (Az LSTM 'vak' marad a Balance, PosCount, Trade_ oszlopokra az lstm_autoencoder.py frissítése miatt)
        logger.info(f"[{file_name}] LSTM Hálózat betanítása a piaci (vak) adatokon...")
        try:
            lstm.train(df_original)
        except Exception as e:
            logger.error(f"[{file_name}] Hiba a betanítás során: {str(e)}")
            continue

        # 4. Detektálás és Összevetés
        # A detect metódus visszaadja a teljes DataFrame-et kiegészítve az LSTM_Anomaly és Error oszlopokkal
        logger.info(f"[{file_name}] Predikció és Anomália (Színész) keresés...")
        df_analyzed = lstm.detect(df_original.copy())

        # 5. Eredmények Mentése (Összevetés a jövőbeli elemzéshez)
        output_file = os.path.join(output_dir, f"ANALYZED_{file_name}")
        df_analyzed.to_csv(output_file, index=False)

        logger.info(f"✅ SIKER: Az elemzett fájl kimentve (összevetéshez kész): {output_file}")

    logger.info("\n🎉 Minden fájl feldolgozása befejeződött!")

if __name__ == '__main__':
    run_profiler()
