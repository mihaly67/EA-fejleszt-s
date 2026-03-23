import os
import glob
import pandas as pd
import numpy as np
import logging
from pipeline.data_loader import RobustDataLoader
from models.lstm_autoencoder import LSTMAutoencoderDetector

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def calculate_market_state(df: pd.DataFrame, window_size: int = 500) -> pd.DataFrame:
    """
    Kiszámítja a Tick Volatilitást és a Tick Sűrűséget egy hosszú (500 tickes) gördülő ablakban,
    majd ezek alapján felcímkézi a tickeket 'Market_State' vödrökbe (Alacsony/Közepes/Magas Volatilitás).
    Ezzel elkerüljük, hogy a rövid brókeri rángatások fals "pörgős" címkét kapjanak.
    """
    logger.info(f"📊 Piaci állapotok (Volatilitás/Sűrűség) kiszámítása {window_size} tickes simítással...")
    df_state = df.copy()

    # 1. Tick Volatilitás (Árfolyam szórása)
    if 'Bid' in df_state.columns:
        df_state['Tick_Volatility'] = df_state['Bid'].rolling(window=window_size, min_periods=10).std().fillna(0)
    else:
        logger.warning("Nincs 'Bid' oszlop a volatilitás számításához!")
        df_state['Tick_Volatility'] = 0.0

    # 2. Tick Sűrűség (Mennyi idő telt el két tick között)
    time_col = 'TickMSC' if 'TickMSC' in df_state.columns else 'TimeMsc'
    if time_col in df_state.columns:
        # A különbség milliszekundumban (Két tick között eltelt idő)
        df_state['Time_Delta'] = df_state[time_col].diff().fillna(0)
        # 500 tickes mozgóátlag a sűrűségre (Nagy Time_Delta = Ritka tickek = Döglött piac)
        df_state['Tick_Density_Avg'] = df_state['Time_Delta'].rolling(window=window_size, min_periods=10).mean().fillna(0)
    else:
        logger.warning(f"Nincs időbélyeg oszlop a sűrűség számításához!")
        df_state['Tick_Density_Avg'] = 0.0

    # 3. Vödrözés (Bucketing) a Volatilitás alapján (Kvantilisekkel)
    # Csak ott számolunk kvantilist, ahol már beállt a mozgóátlag (ne az elejét torzítsa)
    valid_vol = df_state['Tick_Volatility'][df_state['Tick_Volatility'] > 0]

    if len(valid_vol) > 100:
        q33 = valid_vol.quantile(0.33)
        q66 = valid_vol.quantile(0.66)

        conditions = [
            (df_state['Tick_Volatility'] <= q33),
            (df_state['Tick_Volatility'] > q33) & (df_state['Tick_Volatility'] <= q66),
            (df_state['Tick_Volatility'] > q66)
        ]
        choices = ['Low_Volatility', 'Medium_Volatility', 'High_Volatility']
        df_state['Market_State'] = np.select(conditions, choices, default='Medium_Volatility')

        logger.info(f"Vödrök határai: Low <= {q33:.5f} < Medium <= {q66:.5f} < High")
    else:
        df_state['Market_State'] = 'Medium_Volatility'

    return df_state

def run_advanced_profiler():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'analyzed')

    os.makedirs(output_dir, exist_ok=True)

    csv_files = [f for f in glob.glob(os.path.join(data_dir, "*.csv"))
                 if not os.path.basename(f).startswith("ANALYZED_")
                 and not os.path.basename(f) == "mock_tick_data.csv"]

    if not csv_files:
        logger.error(f"Nem találtam elemezendő CSV fájlokat a {data_dir} mappában!")
        return

    logger.info(f"Összesen {len(csv_files)} db CSV fájlt találtam Haladó Profilozásra (Mátrix módszer).")
    loader = RobustDataLoader(chunksize=5000)

    # A spektrum, amit párhuzamosan le akarunk tesztelni minden fájlon
    # A felhasználó kérésére (finom felbontású spektrum elemzés a VPS-en éjszakára)
    # A 40 és 120 közötti kritikus tartományban 10 tickes lépésekkel finomítjuk a hálót,
    # hogy pontosan kirajzolódjon a "Szent Grál" haranggörbéje. Fölötte ritkítjuk.
    spectrum_windows = [40, 50, 60, 70, 80, 90, 100, 110, 120, 150]

    for file_path in csv_files:
        file_name = os.path.basename(file_path)
        logger.info(f"\n{'='*60}\n[HALADÓ PROFILOZÁS] Fájl: {file_name}\n{'='*60}")

        # 1. Betöltés
        df_original = loader.load_tick_data(file_path)
        if df_original.empty:
            continue

        # 2. Piaci állapotok (Címkék) legenerálása az egész fájlra
        df_matrix = calculate_market_state(df_original)

        # 3. Párhuzamos Spektrum Analízis (Végigfuttatjuk a teljes fájlt minden ablakmérettel)
        for seq_length in spectrum_windows:
            logger.info(f"\n--- [MÁTRIX FÁZIS: seq_length = {seq_length} tick] ---")

            lstm = LSTMAutoencoderDetector(seq_length=seq_length, latent_dim=8, batch_size=256, epochs=5)

            try:
                # Betanítás
                logger.info(f"[{file_name} - seq{seq_length}] LSTM Betanítása...")
                lstm.train(df_original.copy())

                # Detektálás (az eredmény egy új DataFrame)
                logger.info(f"[{file_name} - seq{seq_length}] Predikció és Anomália keresés...")
                df_analyzed = lstm.detect(df_original.copy())

                # Eredmények átemelése a Fő Mátrixba (Csak az anomália és a hiba oszlopok)
                df_matrix[f'Anomaly_Seq_{seq_length}'] = df_analyzed['LSTM_Anomaly']
                df_matrix[f'Error_Seq_{seq_length}'] = df_analyzed['LSTM_Reconstruction_Error']
                df_matrix[f'Threshold_Seq_{seq_length}'] = lstm.threshold

            except Exception as e:
                logger.error(f"[{file_name} - seq{seq_length}] Hiba: {str(e)}")
                continue

        # 4. Mátrix kimentése
        output_file = os.path.join(output_dir, f"MATRIX_ANALYZED_{file_name}")
        df_matrix.to_csv(output_file, index=False)
        logger.info(f"✅ SIKER: Mátrix fájl (minden szekvenciával egyben) kimentve: {output_file}")

    logger.info("\n🎉 Minden fájl Mátrix-Profilozása befejeződött!")
    logger.info("Most már készíthetünk egy elemző scriptet, ami megmondja, melyik Market_State-ben melyik Anomaly_Seq_X teljesített a legjobban!")

if __name__ == '__main__':
    run_advanced_profiler()
