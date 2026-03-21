import os
import glob
import logging
import pandas as pd
from pipeline.virtual_streamer import VirtualClockStreamer
from models.rolling_lstm import RollingLSTMAutoencoder
from dtaianomaly.windowing import compute_window_size

# Logolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- PARAMÉTEREK ---
CALIBRATION_INTERVAL_MINUTES = 5.0 # Milyen sűrűn (virtuális perc) kalibráljuk újra a szekvencia ablakot?
INITIAL_SEQ_LENGTH = 30 # Kezdeti vak repülés, amíg nincs elég adat

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
    Fourier (FFT) és Autokorreláció (ACF) alapján újra-kalkulálja a domináns frekvenciát,
    majd lefordítja a Keras hálózatot az új (vagy maradék) adatokon, ha a méret változik.
    """
    if len(history_df) < INITIAL_SEQ_LENGTH * 2:
        logger.warning("Nincs elég múltbeli adat a kalibrációhoz. Várunk.")
        return

    # Keresünk egy Price/Indicator oszlopot
    target_col = 'Bid' # Default
    for col in ['Time_Delta_MS', 'RSI', 'Flow_MFI', 'Hybrid_Context_EMA_25']:
        if col in history_df.columns:
            target_col = col
            break

    logger.info(f"[KALIBRÁCIÓ] Múltbeli tickek száma: {len(history_df)}. Fókusz: '{target_col}'")
    series = history_df[target_col].ffill().fillna(0).values

    # Szekvencia önadaptáció
    try:
        opt_window_fft = compute_window_size(series, window_size='fft', lower_bound=3, upper_bound=150)
        opt_window_acf = compute_window_size(series, window_size='acf', lower_bound=3, upper_bound=150)

        # -1 = hiba a dtaianomaly-ban
        fft = opt_window_fft if opt_window_fft != -1 else 30
        acf = opt_window_acf if opt_window_acf != -1 else 30

        ideal_window = int((fft + acf) / 2)
        final_window = max(3, min(150, ideal_window))

        # Ablak frissítése a memóriában
        lstm.update_window_size(final_window)

        # Ha a modell 'kiesett' a képzésből (mert átméreteződött, vagy ez az első kalibráció)
        # Akkor újra kell tanítani a legutolsó "normális" 60 percen (History_df)
        if not lstm.is_trained:
            logger.info(f"[KALIBRÁCIÓ] LSTM újratanítása az új {final_window} ablakra...")
            # Nem szivárogtatunk Targetet, a history_df is csak a múlt.
            lstm.train(history_df)

    except Exception as e:
        logger.error(f"[KALIBRÁCIÓ] Hiba az önadaptációban: {e}")

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

    # 1. ÉLŐ STREAMING HUROK SZIMULÁLÁSA
    for current_virtual_time_ms, tick_dict in streamer.stream_ticks():
        tick_count += 1
        elapsed_min = streamer.get_elapsed_time_minutes()

        # 2. IDŐZÍTETT (TIME-BUCKETING) KALIBRÁCIÓ
        # "Ugrottunk 5 percet a virtuális időben?"
        if elapsed_min - last_calibration_time_min >= CALIBRATION_INTERVAL_MINUTES:
            logger.info(f"\n[VIRTUAL CLOCK] {elapsed_min:.2f} virtuális perc eltelt. Kalibráció indul...")

            # Kinyerjük a múltat a memóriából (Jövőbelátás nélkül!)
            history_df = extract_recent_history(streamer, lookback_minutes=60.0)

            # Lefuttatjuk a matematikai modellt az ablakméretre
            calibrate_lstm_window(history_df, lstm)

            last_calibration_time_min = elapsed_min

        # 3. ONLINE ANOMÁLIA DETEKTÁLÁS (Minden ticknél)
        # Hozzáadjuk a ticket a Rolling LSTM deque-hez
        is_window_full = lstm.add_tick(tick_dict)

        # Ha megvan a minimális ablakhossz, és a modell már be van tanítva
        if is_window_full and lstm.is_trained:
            mse = lstm.predict_current_window()
            state = lstm.evaluate_state(mse)

            if state == "STATE_ACTOR":
                anomalies_found += 1
                # Extrém logolás csak ritkán, hogy ne robbantsuk le a konzolt
                if anomalies_found % 50 == 0:
                     logger.warning(f"🚨 [BRÓKERI MANŐVER] Virtuális idő: {elapsed_min:.2f} perc | Hiba: {mse:.4f} > {lstm.threshold:.4f}")

    logger.info(f"\n✅ SZIMULÁCIÓ VÉGE.")
    logger.info(f"Feldolgozott tickek: {tick_count}")
    logger.info(f"Összes azonosított 'Színész/Actor' tick (visszafordulási javaslat): {anomalies_found}")

if __name__ == '__main__':
    run_simulation()
