import os
import glob
import pandas as pd
import numpy as np
import logging
import json
from pipeline.data_loader import RobustDataLoader
from models.lstm_autoencoder import LSTMAutoencoderDetector

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def load_global_anchor(symbol: str) -> dict:
    """Megpróbálja betölteni az 1-5 fokozatú Globális Volatilitás Horgonyt a fájlból."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    # Várható fájlnév: pl. XAUUSD_Volatility_Scale.json
    scale_path = os.path.join(base_dir, 'data', 'analyzed', f'{symbol}_Volatility_Scale.json')

    if os.path.exists(scale_path):
        try:
            with open(scale_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                logger.info(f"⚓ Globális Horgony sikeresen betöltve: {scale_path}")
                return data['Classes']
        except Exception as e:
            logger.error(f"Hiba a skála betöltésekor ({scale_path}): {e}")

    # Ha nincs meg az instrumentum-specifikus, próbálkozzunk az alapértelmezettel
    # (amit a teszt kedvéért ide raktunk le fix névvel a repóba)
    fallback_path = os.path.join(base_dir, 'data', 'analyzed', 'XAUUSD_Volatility_Scale.json')
    if os.path.exists(fallback_path):
         try:
            with open(fallback_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                logger.warning(f"⚠️ Nem találtam {symbol} specifikus horgonyt, a XAUUSD skáláját használom ({fallback_path})!")
                return data['Classes']
         except Exception as e:
            logger.error(f"Hiba a fallback skála betöltésekor: {e}")

    logger.error("❌ Kritikus hiba: Nem találtam Globális Volatilitás Horgonyt! Kérlek futtasd le a calculate_global_volatility.py-t először!")
    return None

def calculate_market_state(df: pd.DataFrame, window_size: int = 500, symbol: str = "XAUUSD") -> pd.DataFrame:
    """
    Kiszámítja a Tick Volatilitást és a Tick Sűrűséget egy hosszú (500 tickes) gördülő ablakban,
    majd ezek alapján felcímkézi a tickeket az 1-5 'Market_State' osztályba az Abszolút Horgony alapján.
    """
    logger.info(f"📊 Piaci állapotok (Volatilitás/Sűrűség) kiszámítása {window_size} tickes simítással...")
    df_state = df.copy()

    # Horgony betöltése
    anchor_classes = load_global_anchor(symbol)

    # 1. Tick Volatilitás (Árfolyam szórása)
    if 'Bid' in df_state.columns:
        df_state['Tick_Volatility'] = df_state['Bid'].rolling(window=window_size, min_periods=10).std().fillna(0)
    else:
        logger.warning("Nincs 'Bid' oszlop a volatilitás számításához!")
        df_state['Tick_Volatility'] = 0.0

    # 2. Tick Sűrűség (Mennyi idő telt el két tick között)
    time_col = 'TickMSC' if 'TickMSC' in df_state.columns else 'TimeMsc'
    if time_col in df_state.columns:
        df_state['Time_Delta'] = df_state[time_col].diff().fillna(0)
        df_state['Tick_Density_Avg'] = df_state['Time_Delta'].rolling(window=window_size, min_periods=10).mean().fillna(0)
    else:
        df_state['Tick_Density_Avg'] = 0.0

    # 3. Vödrözés (Bucketing) a Globális Horgony alapján (Class 1-5)
    if anchor_classes:
        conditions = [
            (df_state['Tick_Volatility'] <= anchor_classes['Class_1_Dead']['upper_bound']),
            (df_state['Tick_Volatility'] > anchor_classes['Class_2_Quiet']['lower_bound']) & (df_state['Tick_Volatility'] <= anchor_classes['Class_2_Quiet']['upper_bound']),
            (df_state['Tick_Volatility'] > anchor_classes['Class_3_Average']['lower_bound']) & (df_state['Tick_Volatility'] <= anchor_classes['Class_3_Average']['upper_bound']),
            (df_state['Tick_Volatility'] > anchor_classes['Class_4_Active']['lower_bound']) & (df_state['Tick_Volatility'] <= anchor_classes['Class_4_Active']['upper_bound']),
            (df_state['Tick_Volatility'] > anchor_classes['Class_5_Extreme']['lower_bound'])
        ]
        choices = ['Class_1_Dead', 'Class_2_Quiet', 'Class_3_Average', 'Class_4_Active', 'Class_5_Extreme']
        df_state['Market_State'] = np.select(conditions, choices, default='Class_3_Average')
        logger.info(f"✅ Adatok sikeresen besorolva a Globális 5-ös skálán (Abszolút Vödrözés).")
    else:
        # Biztonsági (visszafelé kompatibilis) ág, ha a fájl mégsem lenne ott, visszavált a régi logikára
        logger.warning("⚠️ Mivel nincs horgony, visszaváltok a régi lokális tercilis számításra (Low/Med/High).")
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

    # A spektrum kibővítve a felhasználó legújabb kérésére:
    # 10-től 200-ig 10-es lépésekben, onnan ritkítva 250, 300, 400, 500-ra.
    spectrum_windows = list(range(10, 201, 10)) + [250, 300, 400, 500]

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
