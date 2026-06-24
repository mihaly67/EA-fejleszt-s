import os
import sys
import glob
import logging
import pandas as pd

# Biztosítjuk, hogy a lokális csomagok importálhatók legyenek (ModuleNotFoundError fix)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from pipeline.virtual_streamer import VirtualClockStreamer
from pipeline.adaptive_windowing import calculate_kaufman_efficiency_ratio, get_optimal_sequence_length
from pipeline.page_hinkley import PageHinkleyTest
from models.rolling_lstm import RollingLSTMAutoencoder

# Logolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- PARAMÉTEREK ---
CALIBRATION_INTERVAL_MINUTES = 15.0 # Milyen sűrűn (virtuális perc) kalibráljuk újra a szekvencia ablakot (tanítással)? - Ritkítva a sebességért
INITIAL_SEQ_LENGTH = 80 # "Vak" repülés induláskor (Warm-Up fázis)

def extract_recent_history(streamer: VirtualClockStreamer, lookback_minutes: float = 60.0) -> pd.DataFrame:
    """
    Az önadaptációhoz szükséges 'múltbeli' adatok kinyerése a Streamerből.
    Hogy ne legyen jövőbe látás (Target Leak), csak a 'virtual_clock' előtti
    tickeket használhatja a kalibrátor.
    """
    current_time = streamer.virtual_clock
    lookback_ms = int(lookback_minutes * 60 * 1000)
    start_time = max(0, current_time - lookback_ms)

    # A DataFrame-ből kivágjuk a múltat (Szigorúan < current_time, tehát az aktuális tick még nincs benne)
    history_df = streamer.df[(streamer.df[streamer.time_col] >= start_time) &
                             (streamer.df[streamer.time_col] < current_time)].copy()

    return history_df

def calibrate_lstm_window(history_df: pd.DataFrame, lstm: RollingLSTMAutoencoder):
    """
    A Kaufman Efficiency Ratio (ER) alapján újra-kalkulálja a piaci trend/zaj arányt,
    és meghatározza az optimális szekvenciahosszt. Ez a paradigmaváltás:
    Alacsony Volatilitás (ER~0) -> Nagy Ablak (150+)
    Magas Volatilitás (ER~1) -> Kis Ablak (40)
    """
    # 5 percnyi (legalább 200) adat kell az első stabil ER értékhez
    if len(history_df) < 200:
        logger.warning("Nincs elég múltbeli adat a stabil kalibrációhoz (warm-up). Várunk.")
        return

    # Keressük az árat (Bid)
    target_col = 'Bid'
    if target_col not in history_df.columns:
        logger.warning("Nincs 'Bid' oszlop az adatokban, az Efficiency Ratio nem számítható megfelelően.")
        return

    logger.info(f"[KALIBRÁCIÓ] Múltbeli tickek száma: {len(history_df)}. Fókusz: '{target_col}'")
    prices = history_df[target_col].ffill().fillna(0).values

    # Számítjuk az Efficiency Ratiot az utolsó 50 mozgás alapján
    er = calculate_kaufman_efficiency_ratio(prices, period=min(50, len(prices)-1))

    # Kiszámítjuk a Gemini-kutatás alapján az ideális ablakot
    final_window = get_optimal_sequence_length(er)

    logger.info(f"[KALIBRÁCIÓ] Piaci Állapot: ER={er:.4f} -> Javasolt Látótér: {final_window} tick.")

    # Ablak frissítése a memóriában
    try:
        lstm.update_window_size(final_window)

        # Ha a modell 'kiesett' a képzésből (mert átméreteződött, vagy ez az első kalibráció)
        # Akkor újra kell tanítani a legutolsó "normális" 60 percen (History_df)
        if not lstm.is_trained:
            logger.info(f"[KALIBRÁCIÓ] LSTM újratanítása a {final_window} ablakra a legfrissebb adatokkal...")
            # Nem szivárogtatunk Targetet, a history_df is csak a múlt.
            lstm.train(history_df)

    except Exception as e:
        logger.error(f"[KALIBRÁCIÓ] Kritikus hiba a hálózat frissítésében: {e}")

def run_simulation():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    csv_files = [f for f in glob.glob(os.path.join(data_dir, "*.csv"))
                 if not os.path.basename(f).startswith("ANALYZED_")
                 and not os.path.basename(f) == "mock_tick_data.csv"]

    if not csv_files:
        logger.error("Nincsenek CSV fájlok a data/ mappában!")
        return

    # Teszteljük az első fájlon (ez a stream)
    file_path = csv_files[0]
    logger.info(f"\n==============================================")
    logger.info(f"VIRTUAL CLOCK STREAMER INDÍTÁSA")
    logger.info(f"Fájl: {os.path.basename(file_path)}")
    logger.info(f"==============================================")

    streamer = VirtualClockStreamer(file_path)
    lstm = RollingLSTMAutoencoder(initial_seq_length=INITIAL_SEQ_LENGTH)

    # Változók az időzítőhöz (virtuális óra)
    last_calibration_time_min = 0.0
    tick_count = 0
    anomalies_found = 0

    # Kimeneti adatok (Állókép generálás a vizualizációhoz)
    output_rows = []

    # Hibrid Drift Kezelés inicializálása
    ph_test = PageHinkleyTest(threshold=15.0, delta=0.05)
    last_drift_recalibration_time = 0.0

    # 1. ÉLŐ STREAMING HUROK SZIMULÁLÁSA
    for current_virtual_time_ms, tick_dict in streamer.stream_ticks():
        tick_count += 1
        elapsed_min = streamer.get_elapsed_time_minutes()

        # Alapértelmezett kimeneti adatok (ha még nincs elég múltunk detektálni)
        row_output = tick_dict.copy()
        row_output['LSTM_Reconstruction_Error'] = 0.0
        row_output['LSTM_Threshold'] = getattr(lstm, 'threshold', 0.0)
        row_output['LSTM_Anomaly'] = 1 # 1 = Normál piac

        # 2. IDŐZÍTETT (TIME-BUCKETING) KALIBRÁCIÓ
        # "Ugrottunk 5 percet a virtuális időben?"
        if elapsed_min - last_calibration_time_min >= CALIBRATION_INTERVAL_MINUTES:
            logger.info(f"\n[VIRTUAL CLOCK] {elapsed_min:.2f} virtuális perc eltelt. Kalibráció indul...")

            # Kinyerjük a múltat a memóriából (Jövőbelátás nélkül!)
            history_df = extract_recent_history(streamer, lookback_minutes=60.0)

            # Lefuttatjuk a matematikai modellt az ablakméretre
            calibrate_lstm_window(history_df, lstm)

            last_calibration_time_min = elapsed_min

        # 3. ONLINE ANOMÁLIA DETEKTÁLÁS ÉS DRIFT KEZELÉS
        # Hozzáadjuk a ticket a Rolling LSTM deque-hez
        is_window_full = lstm.add_tick(tick_dict)

        # SEBESSÉG OPTIMALIZÁCIÓ (Mini-Batch Inferencia a VPS-hez):
        # A Keras modell C++ backend hívása minden egyes ticknél (pl. milliszekundumonként)
        # hatalmas overheadet jelent, ami miatt a szimuláció lassabb a valós időnél.
        # Megoldás: Csak minden 10. ticknél futtatunk AI inferenciát (Reconstruction Error-t).
        # A maradék 9 ticknél a legutolsó kiszámított MSE-t (és state-et) használjuk.
        if is_window_full and lstm.is_trained:
            if tick_count % 10 == 0:
                mse = lstm.predict_current_window()
                lstm.last_calculated_mse = mse # Eltároljuk a ritkított köztes állapotokhoz
            else:
                # Cache-elt hiba használata (nem hívjuk meg a nehéz TensorFlow-t)
                mse = getattr(lstm, 'last_calculated_mse', 0.0)

            # --- Page-Hinkley Drift Test ---
            # Figyeljük, hogy elszállt-e a piac normál hibaeloszlása (Koncepció-drift)
            is_drift = ph_test.update(mse)

            if is_drift and (elapsed_min - last_drift_recalibration_time) > 2.0:
                logger.warning(f"⚠️ [DRIFT DETEKTÁLVA] Page-Hinkley teszt hirtelen piac-karakterisztika változást észlelt! Küszöb újra-kalibrálás...")
                history_df = extract_recent_history(streamer, lookback_minutes=60.0)
                # Csak a thresholdot és az ablakot frissítjük az ER-ből, NEM tanítunk súlyokat, hogy ne tanulja be az anomáliát!
                calibrate_lstm_window(history_df, lstm)
                last_drift_recalibration_time = elapsed_min
                # Ha a hálózat a Page-Hinkley drift ellenére sem volt "kiesve", a threshold
                # a fenti calibrate híváson belül lefutó train(history_df) miatt már frissült (ha új az ablakméret).

            state = lstm.evaluate_state(mse)

            # Kimeneti adatok frissítése az adott ticken
            row_output['LSTM_Reconstruction_Error'] = mse
            row_output['LSTM_Threshold'] = lstm.threshold
            row_output['LSTM_Anomaly'] = -1 if state == "STATE_ACTOR" else 1

            if state == "STATE_ACTOR":
                anomalies_found += 1
                # Extrém logolás csak ritkán, hogy ne robbantsuk le a konzolt
                if anomalies_found % 50 == 0:
                     logger.warning(f"🚨 [BRÓKERI MANŐVER] Virtuális idő: {elapsed_min:.2f} perc | Hiba: {mse:.4f} > {lstm.threshold:.4f}")

        # Eredmény hozzáfűzése a listához
        output_rows.append(row_output)

    logger.info(f"\n✅ SZIMULÁCIÓ VÉGE.")
    logger.info(f"Feldolgozott tickek: {tick_count}")
    logger.info(f"Összes azonosított 'Színész/Actor' tick: {anomalies_found}")

    # 4. KIMENET GENERÁLÁSA A VIZUALIZÁCIÓHOZ (Az Állókép)
    # Ezt a CSV fájlt tudja a visualize_behavior.py megenni a grafikonok rajzolásához.
    output_df = pd.DataFrame(output_rows)
    filename = os.path.basename(file_path)

    # A visualize_behavior.py a 'data/analyzed' mappában keresi a fájlokat
    analyzed_dir = os.path.join(data_dir, "analyzed")
    if not os.path.exists(analyzed_dir):
        os.makedirs(analyzed_dir)

    output_path = os.path.join(analyzed_dir, f"ANALYZED_RESULTS_streaming_{filename}")

    logger.info(f"📈 Eredmények kimentése vizualizációhoz: {output_path}")
    output_df.to_csv(output_path, index=False)
    logger.info(f"Minden adat elmentve. Futtasd a 'python3 visualize_behavior.py'-t a grafikonokhoz!")

if __name__ == '__main__':
    run_simulation()
