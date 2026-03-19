import os
import glob
import pandas as pd
import numpy as np
import logging
from pipeline.data_loader import RobustDataLoader
from models.lstm_autoencoder import LSTMAutoencoderDetector
from dtaianomaly.windowing import compute_window_size

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def determine_optimal_window(df: pd.DataFrame, method: str = 'fft') -> int:
    """
    Szekvencia Önadaptáció (SWAT4 RAG)
    Megpróbálja megállapítani az optimális szekvencia ablakméretet a múltbeli adatok alapján
    a dtaianomaly könyvtár (Fourier vagy ACF) módszerével.
    """
    # Keresünk egy domináns indikátort a Fourier analízishez
    target_col = None
    for col in ['Time_Delta_MS', 'RSI', 'Flow_MFI', 'Hybrid_Context_EMA_25']:
        if col in df.columns:
            target_col = col
            break

    if not target_col:
        # Fallback: Keresünk egy Price oszlopot
        for col in df.columns:
            if 'Bid' in col or 'Ask' in col:
                target_col = col
                break

    if not target_col:
        logger.warning(f"Nem találtam megfelelő oszlopot az önadaptív ablakméret számításához. Fallback: 30")
        return 30

    logger.info(f"Szekvencia Önadaptáció: '{target_col}' elemzése '{method}' módszerrel...")

    # Kinyerjük a Pandas oszlopot NumPy tömbként (biztosítjuk, hogy nincs NaN)
    series = df[target_col].ffill().fillna(0).values

    try:
        # Felső határ limitálása, hogy a memóriakorlátokat betartsa (max 150)
        window = compute_window_size(series, window_size=method, lower_bound=3, upper_bound=150)

        # dtaianomaly -1-et ad vissza hiba esetén
        if window == -1:
             logger.warning(f"A '{method}' módszer nem tudott optimális ablakot számítani. Fallback: 30")
             return 30

        logger.info(f"💡 SIKER: Az optimális ablakméret automatikusan meghatározva ({method}): {window} tick")
        return int(window)
    except Exception as e:
        logger.error(f"Hiba az ablakméret számításakor ({method}): {str(e)}. Fallback: 30")
        return 30


def run_profiler():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'analyzed')

    # Biztosítsuk, hogy az output mappa létezik
    os.makedirs(output_dir, exist_ok=True)

    # Keresünk minden olyan CSV-t, amit profilozni kell
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

        # 1. Betöltés (Teljes CSV a BlackBox összes oszlopával)
        df_original = loader.load_tick_data(file_path)

        if df_original.empty:
            logger.warning(f"A fájl {file_name} üres, kihagyjuk.")
            continue

        # 2. LSTM Inicializálása Dinamikus Ablakmérettel (ÖN-ADAPTÁCIÓ)
        # Az összes [3, 5, ... 120] végigpörgetése helyett kiszámítjuk a domináns frekvenciát
        opt_window_fft = determine_optimal_window(df_original, method='fft')
        opt_window_acf = determine_optimal_window(df_original, method='acf')

        # A két módszer átlagolásával kapunk egy robusztusabb "Ideális" ablakot (ha valamelyik hibázna)
        ideal_window = int((opt_window_fft + opt_window_acf) / 2)

        # Opcionálisan megnézzük a 'suss' módszert is (Summary Statistics Subsequences)
        opt_window_suss = determine_optimal_window(df_original, method='suss')

        logger.info(f"Önadaptív Eredmények: FFT={opt_window_fft}, ACF={opt_window_acf}, SUSS={opt_window_suss}")

        # A SUSS hajlamos nagyon pontos lenni a sorozatoknál, ha az bevált, használjuk, különben az átlagot
        final_window = opt_window_suss if opt_window_suss > 3 else ideal_window
        final_window = max(3, min(150, final_window)) # Biztonsági korlátok

        # Továbbra is megtartunk pár végletet az emberi vizuális spektrum összehasonlításhoz (A Riport generáló miatt),
        # de a "Dinamikus" hálózat megkapja a kiemelt fókuszát.
        spectrum_windows = [3, final_window, 120]

        # Kiszűrjük a duplikációkat, ha az ideális 3 vagy 120 lenne
        spectrum_windows = sorted(list(set(spectrum_windows)))

        for seq_length in spectrum_windows:
            if seq_length == final_window:
                logger.info(f"\n--- [SPEKTRUM FÁZIS: seq_length={seq_length} (ÖNADAPTÍV OPTIMUM)] ---")
            else:
                logger.info(f"\n--- [SPEKTRUM FÁZIS: seq_length={seq_length} (KONTROLL ABLAK)] ---")

            # Nehéztüzérség bevetése: CPU optimalizált, RAM kímélő batch_size
            lstm = LSTMAutoencoderDetector(seq_length=seq_length, latent_dim=8, batch_size=256, epochs=5)

            # 3. Betanítás (Az LSTM 'vak' marad a Balance, PosCount, Trade_ oszlopokra)
            logger.info(f"[{file_name} - seq{seq_length}] LSTM Hálózat betanítása a piaci (vak) adatokon...")
            try:
                # Klónozzuk, mert a belső függvény (scale/detect) esetleg inplace beleír a dataframe-be
                lstm.train(df_original.copy())
            except Exception as e:
                logger.error(f"[{file_name} - seq{seq_length}] Hiba a betanítás során: {str(e)}")
                continue

            # 4. Detektálás és Összevetés
            logger.info(f"[{file_name} - seq{seq_length}] Predikció és Anomália (Színész) keresés...")
            df_analyzed = lstm.detect(df_original.copy())

            # 5. Eredmények Mentése, külön fájlban per spektrum ablak
            tag = "ADAPTIVE_" if seq_length == final_window else ""
            output_file = os.path.join(output_dir, f"ANALYZED_{tag}{file_name.replace('.csv', '')}_seq{seq_length}.csv")
            df_analyzed.to_csv(output_file, index=False)

            logger.info(f"✅ SIKER: Elemzett fájl kimentve (seq={seq_length}): {output_file}")

    logger.info("\n🎉 Minden fájl feldolgozása befejeződött!")

if __name__ == '__main__':
    run_profiler()
