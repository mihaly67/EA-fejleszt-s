import os
import glob
import pandas as pd
import numpy as np
import logging
try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_PLOT = True
    # Headless backend VPS-hez
    import matplotlib
    matplotlib.use('Agg')
except ImportError:
    HAS_PLOT = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

def analyze_matrix_trades(df: pd.DataFrame, filename: str, output_dir: str):
    """
    Kikeresi a Trade-eket a Mátrix CSV-ből, és minden Market_State-ben (Low/Med/High)
    megnézi, melyik Seq_X ablak (40, 80, 120, 150) adta a legtöbb anomália találatot
    a nyitás körüli +/- 30 tickes ablakban.
    """
    report_lines = []
    report_lines.append(f"=======================================================")
    report_lines.append(f"🧠 MÁTRIX KORRELÁCIÓS ELEMZÉS: {filename}")
    report_lines.append(f"=======================================================\n")

    if 'PosCount' not in df.columns:
        logger.warning(f"Nincs 'PosCount' a {filename} fájlban, nem lehet trade-eket keresni.")
        return

    # Trade indexek (ahol változik a pozíciók száma)
    trade_indices = df.index[df['PosCount'].diff().fillna(0) != 0].tolist()
    if not trade_indices:
        report_lines.append("Nem találtam kereskedési eseményt (PosCount változást) a fájlban.")
        _save_report(report_lines, filename, output_dir)
        return

    # Dinamikusan kikeresse a lefuttatott Seq ablakokat a CSV-ből (pl. 40, 80, 120)
    seq_cols = [c for c in df.columns if c.startswith('Anomaly_Seq_')]
    seq_lengths = sorted([int(c.split('_')[-1]) for c in seq_cols])

    if not seq_lengths:
        logger.warning(f"Nem találtam 'Anomaly_Seq_X' oszlopokat a {filename} fájlban.")
        return

    report_lines.append(f"🔎 Tesztelt Szekvencia Ablakok: {seq_lengths} tick")
    report_lines.append(f"🎯 Összes Kereskedés (Trade) száma: {len(trade_indices)}\n")

    # Statisztikák tárolása: stat[Market_State][Seq_Length] = (Talált Anomáliák, Összes Trade)
    stats = {
        'Low_Volatility': {seq: [0, 0] for seq in seq_lengths},
        'Medium_Volatility': {seq: [0, 0] for seq in seq_lengths},
        'High_Volatility': {seq: [0, 0] for seq in seq_lengths}
    }

    for idx in trade_indices:
        # Trade körüli +/- 30 tickes ablak vizsgálata (Brókeri 'rám ugrás' keresése)
        start_idx = max(0, idx - 30)
        end_idx = min(len(df), idx + 30)
        window = df.iloc[start_idx:end_idx]

        # Milyen piaci állapotban volt a trade (az adott ticknél)?
        m_state = df.at[idx, 'Market_State'] if 'Market_State' in df.columns else 'Medium_Volatility'
        # Biztosítás, ha a Pandas valamiért sorozatot ad vissza (pl. duplikált index)
        if isinstance(m_state, pd.Series):
             m_state = m_state.iloc[0]

        # Hozzáadjuk a statisztikához, hogy ebben a Market_State-ben volt egy trade
        if m_state in stats:
            for seq in seq_lengths:
                stats[m_state][seq][1] += 1 # Total trade counter

                # Volt-e anomália (-1) az adott Seq ablak szerint a trade körül?
                col_name = f'Anomaly_Seq_{seq}'
                if col_name in window.columns and (window[col_name] == -1).any():
                    stats[m_state][seq][0] += 1 # Találat (Intervention) counter

    # Riport generálása a statisztikákból
    for state in ['Low_Volatility', 'Medium_Volatility', 'High_Volatility']:
        report_lines.append(f"📊 PIACI ÁLLAPOT: {state.upper()}")
        report_lines.append("-" * 50)

        # Csak azokat írjuk ki, ahol volt legalább 1 trade
        total_trades_in_state = list(stats[state].values())[0][1]

        if total_trades_in_state == 0:
            report_lines.append("  Nincs kereskedés ebben a piaci állapotban.\n")
            continue

        report_lines.append(f"  Összes kereskedés itt: {total_trades_in_state}")

        best_rate = -1
        best_seq = None

        for seq in seq_lengths:
            hits = stats[state][seq][0]
            rate = (hits / total_trades_in_state) * 100
            report_lines.append(f"    - Ablak: {seq:3d} tick -> Találat: {hits:3d}/{total_trades_in_state} ({rate:5.1f}%)")

            if rate > best_rate:
                best_rate = rate
                best_seq = seq

        report_lines.append(f"  🏆 GYŐZTES EBBEN AZ ÁLLAPOTBAN: {best_seq} tickes ablak ({best_rate:.1f}% felismerés)\n")

    # Végső Konklúzió (A Szabály)
    report_lines.append("💡 KONKLÚZIÓ (A KORRELÁCIÓS SZABÁLY):")
    for state in ['Low_Volatility', 'Medium_Volatility', 'High_Volatility']:
        total_trades = list(stats[state].values())[0][1]
        if total_trades > 0:
            best_rate = -1
            best_seq = None
            for seq in seq_lengths:
                rate = (stats[state][seq][0] / total_trades) * 100
                if rate > best_rate:
                    best_rate = rate
                    best_seq = seq
            report_lines.append(f"Ha a piac {state.replace('_Volatility', '')}, akkor az ideális ablak: {best_seq} tick.")

    _save_report(report_lines, filename, output_dir)
    return stats

def _save_report(lines, filename, output_dir):
    report_filename = f"REPORT_MATRIX_{filename.replace('.csv', '.txt')}"
    output_path = os.path.join(output_dir, report_filename)
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        logger.info(f"📝 Mátrix Korrelációs Riport (.txt) kimentve ide: {output_path}")
    except Exception as e:
        logger.error(f"Hiba a txt riport mentése közben: {str(e)}")

def create_matrix_plot(df, filename, output_dir):
    """
    Rajzol egy összetett, gyönyörű grafikont a Mátrix elemzéshez.
    Felső sáv: Bid Árfolyam, beszínezett háttérrel a Piaci Állapot szerint.
    Alsó sávok: Az egyes Seq_X ablakok rekonstrukciós hibái egymás alatt.
    """
    if not HAS_PLOT:
        logger.warning("Matplotlib nincs telepítve, a grafikonok nem generálódnak.")
        return

    output_path = os.path.join(output_dir, f"PLOT_MATRIX_{filename.replace('.csv', '.png')}")

    # Trade-ek kikeresése a fókuszhoz
    trade_indices = df.index[df['PosCount'].diff().fillna(0) != 0].tolist() if 'PosCount' in df.columns else []

    if trade_indices:
        first_trade = max(0, trade_indices[0] - 500)
        last_trade = min(len(df), trade_indices[-1] + 500)
        plot_df = df.iloc[first_trade:last_trade].copy()
    else:
        plot_df = df.tail(10000).copy()

    seq_cols = [c for c in plot_df.columns if c.startswith('Error_Seq_')]
    seq_lengths = sorted([int(c.split('_')[-1]) for c in seq_cols])
    num_seq = len(seq_lengths)

    if num_seq == 0:
        return

    # Felső árfolyam + alsó hibasávok (num_seq darab)
    fig, axes = plt.subplots(num_seq + 1, 1, figsize=(18, 4 + 3*num_seq), sharex=True)
    if num_seq == 0: # Biztosíték, ha csak 1 lenne
        axes = [axes]

    ax_price = axes[0]

    # --- 1. PIACI ÁLLAPOTOK SZÍNEZÉSE (Háttér) ---
    if 'Market_State' in plot_df.columns:
        # Kitöltjük a hátteret a Low/Med/High szerint (zöld, sárga, piros)
        colors = {'Low_Volatility': 'lightgreen', 'Medium_Volatility': 'lightyellow', 'High_Volatility': 'lightcoral'}
        labels_added = {'Low_Volatility': False, 'Medium_Volatility': False, 'High_Volatility': False}

        # Kis trükk a folytonos színezéshez: iterálunk az állapotváltásokon
        plot_df['State_Change'] = (plot_df['Market_State'] != plot_df['Market_State'].shift()).cumsum()

        for state_grp, group in plot_df.groupby('State_Change'):
            state_name = group['Market_State'].iloc[0]
            if isinstance(state_name, pd.Series): state_name = state_name.iloc[0]
            color = colors.get(state_name, 'white')

            # Csak az első alkalommal adunk neki labelet, hogy ne legyen ezer elem a legendben
            if not labels_added.get(state_name, False):
                label_name = state_name.replace('_', ' ')
                labels_added[state_name] = True
                # Vízszintes span festés label-lel
                ax_price.axvspan(group.index.min(), group.index.max(), color=color, alpha=0.3, lw=0, label=label_name)
            else:
                # További szakaszoknál nincs label, csak szín
                ax_price.axvspan(group.index.min(), group.index.max(), color=color, alpha=0.3, lw=0)

    # --- 2. ÁRFOLYAM (Bid) ÉS TRADE-EK ---
    ax_price.plot(plot_df.index, plot_df['Bid'], color='black', lw=1, label='Bid Price')
    if trade_indices:
        trade_points = plot_df[plot_df['PosCount'].diff().fillna(0) != 0]
        ax_price.scatter(trade_points.index, trade_points['Bid'], color='blue', s=100, label='Trade (Nyitás/Zárás)', marker='v', zorder=5)

    ax_price.set_title(f'Piaci Árfolyam és Market State - {filename}')
    ax_price.set_ylabel('Bid Price')
    ax_price.legend(loc='upper right')
    ax_price.grid(True, alpha=0.3)

    # --- 3. REKONSTRUKCIÓS HIBÁK (Ablakonként külön sávban) ---
    for i, seq in enumerate(seq_lengths):
        ax = axes[i + 1]
        err_col = f'Error_Seq_{seq}'
        anom_col = f'Anomaly_Seq_{seq}'
        thresh_col = f'Threshold_Seq_{seq}'

        if err_col in plot_df.columns:
            ax.plot(plot_df.index, plot_df[err_col], color='darkorange', label=f'LSTM Error ({seq} tick)')

            if thresh_col in plot_df.columns:
                threshold = plot_df[thresh_col].iloc[0]
                ax.axhline(y=threshold, color='r', linestyle='--', alpha=0.5, label='Threshold')

            if anom_col in plot_df.columns:
                anomalies = plot_df[plot_df[anom_col] == -1]
                ax.scatter(anomalies.index, anomalies[err_col], color='red', s=20, label='Anomália Detektálva', zorder=5)

        ax.set_ylabel('MSE Error')
        ax.set_title(f'{seq} tickes Szekvencia Elemzés')
        ax.legend(loc='upper right')
        ax.grid(True, alpha=0.3)

    axes[-1].set_xlabel('Tick Index')

    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()
    logger.info(f"📸 Mátrix Grafikon generálva és elmentve ide: {output_path}")

def run_matrix_evaluator():
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'analyzed')

    if not os.path.exists(output_dir):
        logger.error(f"Nem találtam az '{output_dir}' mappát! Futtattad már a run_advanced_profiler.py-t?")
        return

    csv_files = glob.glob(os.path.join(output_dir, "MATRIX_ANALYZED_*.csv"))

    if not csv_files:
        logger.error("Nem találtam Mátrix (MATRIX_ANALYZED_) CSV fájlokat az összevetéshez!")
        return

    for file_path in csv_files:
        filename = os.path.basename(file_path)
        try:
            logger.info(f"Betöltés: {filename}...")
            df = pd.read_csv(file_path)

            # Elemzés (Riport)
            analyze_matrix_trades(df, filename, output_dir)

            # Rajzolás
            create_matrix_plot(df, filename, output_dir)

        except Exception as e:
            logger.error(f"Hiba a {filename} mátrix értékelésekor: {str(e)}")

    logger.info("\n🎉 Minden Mátrix CSV feldolgozva és kiértékelve. Olvasd el a REPORT_MATRIX fájlokat!")

if __name__ == '__main__':
    run_matrix_evaluator()
