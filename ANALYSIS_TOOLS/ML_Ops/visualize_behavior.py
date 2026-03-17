import os
import glob
import pandas as pd
import numpy as np
import logging
import warnings
warnings.filterwarnings('ignore')

# Alap loggolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# Opcionális plotoló import, gracefull fallback-el VPS-en (headless server)
try:
    import matplotlib
    matplotlib.use('Agg') # Server mód grafikus felület nélkül
    import matplotlib.pyplot as plt
    HAS_PLOT = True
except ImportError:
    HAS_PLOT = False
    logger.warning("Matplotlib nincs telepítve. Csak szöveges kiértékelés (Konzol Riport) készül! (pip install matplotlib)")

def analyze_trade_impact(df, filename):
    """
    Kikeresi a Trade eseményeket (ahol a 'PosCount' megváltozott 0-ról 1-re vagy 1-ről 0-ra),
    és megvizsgálja az azt megelőző és követő 15-30 tickes ablakot az 'LSTM_Anomaly' (Manipuláció) tekintetében.
    """
    logger.info(f"\n=======================================================")
    logger.info(f"🔍 MÉLYELEMZÉS: {filename}")
    logger.info(f"=======================================================")

    if 'PosCount' not in df.columns or 'LSTM_Anomaly' not in df.columns:
        logger.error(f"Hiányoznak a szükséges oszlopok (PosCount, LSTM_Anomaly) a {filename} fájlból!")
        return

    # Megkeressük azokat a sorokat (tickeket), ahol tranzakció történt (PosCount változott)
    # Ahol a .diff() nem 0, ott történt egy Trade nyitás vagy zárás
    trade_indices = df.index[df['PosCount'].diff().fillna(0) != 0].tolist()

    if not trade_indices:
        logger.info("ℹ️ Ebben a fájlban NEM volt rögzített kereskedés (PosCount nem változott).")
        logger.info(f"Összes Brókeri Anomália (Piaci Zaj / Színész) a fájlban: {len(df[df['LSTM_Anomaly'] == -1])} db ({(len(df[df['LSTM_Anomaly'] == -1])/len(df))*100:.2f}%)")
        return

    logger.info(f"🔥 Talált Kereskedési Események (Nyitás/Zárás): {len(trade_indices)} db")

    window_size = 30 # Tick ablak a Trade ELŐTT és UTÁN
    actor_interventions = 0

    for idx in trade_indices:
        # Trade ideje (Time oszlop, ha van)
        trade_time = df.loc[idx, 'Time'] if 'Time' in df.columns else f"Tick Index: {idx}"

        # Trade előtti "előjáték" (Előkészíti-e a bróker a terepet a táguló spreaddel?)
        start_idx = max(0, idx - window_size)
        end_idx = min(len(df), idx + window_size)

        # Elemzés az ablakon belül
        window_df = df.iloc[start_idx:end_idx]
        anomalies_in_window = window_df[window_df['LSTM_Anomaly'] == -1]

        if not anomalies_in_window.empty:
            actor_interventions += 1
            max_error = anomalies_in_window['LSTM_Reconstruction_Error'].max()
            logger.info(f"🚨 [MANIPULÁCIÓ DETEKTÁLVA] Trade Időpont: {trade_time}")
            logger.info(f"   -> A Trade körüli +/- {window_size} tickben az AI {len(anomalies_in_window)} db 'Színész' beavatkozást talált!")
            logger.info(f"   -> Maximális Visszaépítési Hiba (Reconstruction Error): {max_error:.4f}")
        else:
            logger.info(f"✅ [TISZTA TRADE] Trade Időpont: {trade_time} -> Nem volt manipuláció a nyitás/zárás körül.")

    intervention_rate = (actor_interventions / len(trade_indices)) * 100
    logger.info(f"\n📊 ÖSSZEGZÉS:")
    logger.info(f"A bróker az esetek {intervention_rate:.2f}%-ában reagált aktívan ('Színészkedett') a te kereskedéseidre!")

def create_visual_plot(df, filename, output_dir):
    """
    Létrehoz egy kétrészes grafikont, ami a nyers árat és az LSTM Rekonstrukciós hibát veti össze.
    Kimenti .png formátumban az elemzett mappába.
    """
    if not HAS_PLOT:
        return

    if 'LSTM_Reconstruction_Error' not in df.columns or 'Bid' not in df.columns:
        return

    output_path = os.path.join(output_dir, f"PLOT_{filename.replace('.csv', '.png')}")

    # Kisebb minta, ha túl nagy a fájl (vizualizációhoz 10 000 tick elég, hogy látszódjon a tüske)
    plot_df = df.tail(10000).copy()
    plot_df.reset_index(drop=True, inplace=True)

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(15, 10), sharex=True)

    # Felső grafikon: Bid Ár + Kereskedések
    ax1.plot(plot_df.index, plot_df['Bid'], label='Bid Price', color='black', linewidth=1)

    if 'PosCount' in plot_df.columns:
        # Kereskedési pontok (Nyitás/Zárás)
        trade_points = plot_df[plot_df['PosCount'].diff().fillna(0) != 0]
        ax1.scatter(trade_points.index, trade_points['Bid'], color='blue', s=100, label='Kereskedés (Trade Event)', marker='v', zorder=5)

    ax1.set_title(f'Piaci Árfolyam (Bid) - {filename}')
    ax1.set_ylabel('Price')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Alsó grafikon: LSTM Hiba + Anomáliák
    ax2.plot(plot_df.index, plot_df['LSTM_Reconstruction_Error'], label='LSTM Reconstruction Error', color='orange')

    # Anomália pontok (ahol LSTM_Anomaly == -1)
    anomalies = plot_df[plot_df['LSTM_Anomaly'] == -1]
    ax2.scatter(anomalies.index, anomalies['LSTM_Reconstruction_Error'], color='red', s=30, label='AI Detektált Manipuláció (Színész)')

    ax2.set_title('AI Visszaépítési Hiba (Reconstruction Error / Manipuláció Tüskék)')
    ax2.set_xlabel('Utolsó 10000 Tick Index')
    ax2.set_ylabel('MSE Error')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()

    logger.info(f"📸 Grafikon generálva és elmentve ide: {output_path}")


def run_evaluator():
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'analyzed')

    if not os.path.exists(output_dir):
        logger.error(f"Nem találtam az '{output_dir}' mappát! Futtattad már a run_behavioral_profiler.py-t?")
        return

    csv_files = glob.glob(os.path.join(output_dir, "ANALYZED_*.csv"))

    if not csv_files:
        logger.error("Nem találtam elemzett (ANALYZED_) CSV fájlokat az összevetéshez!")
        return

    for file_path in csv_files:
        filename = os.path.basename(file_path)
        try:
            # Csak a legszükségesebb oszlopokat töltjük be memóriakímélő módon az értékeléshez
            usecols = None

            # Először betöltjük a fejlécet, hogy lássuk mik az elérhető oszlopok
            sample_df = pd.read_csv(file_path, nrows=1)
            cols = sample_df.columns.tolist()

            target_cols = ['Time', 'Bid', 'PosCount', 'LSTM_Reconstruction_Error', 'LSTM_Anomaly', 'Trade_Action', 'LotDir']
            usecols = [c for c in target_cols if c in cols]

            # Betöltés
            df = pd.read_csv(file_path, usecols=usecols)

            # 1. Konzol Riport és Kiértékelés (Emberi nyelven)
            analyze_trade_impact(df, filename)

            # 2. Vizuális Plot generálása (Kép)
            create_visual_plot(df, filename, output_dir)

        except Exception as e:
            logger.error(f"Hiba a {filename} fájl értékelésekor: {str(e)}")

if __name__ == '__main__':
    run_evaluator()
