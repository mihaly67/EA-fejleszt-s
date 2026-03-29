import os
import glob
import pandas as pd
import numpy as np
import logging
import warnings
warnings.filterwarnings('ignore')

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

try:
    import matplotlib
    matplotlib.use('Agg') # Server mód grafikus felület nélkül (VPS-en)
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_PLOT = True
except ImportError:
    HAS_PLOT = False
    logger.warning("Matplotlib nincs telepítve. Grafikonok (PNG) nem készülnek! (pip install matplotlib)")

# ==============================================================================
# ⚙️ FELHASZNÁLÓI BEÁLLÍTÁSOK (CÍMKÉZÉSI SZABÁLYOK FINOMHANGOLÁSA)
# Ezt a blokkot nyugodtan módosíthatod a CSV teszteléseid (Data Profiling) alapján!
# ==============================================================================

class LabelerConfig:
    # Milyen messzire nézzünk előre a belépés/zárás után (tickekben)?
    FORWARD_WINDOW = 10

    # 📉 ADVERSE EXCURSION (Rám Ugrás / Lassú Kivéreztetés)
    # Minimális ellentétes elmozdulás pontban. Mivel 0.5 túl érzékeny volt (rengeteg Fals Pozitív "Concrete" bukó),
    # egy szigorúbb (pl. 1.5 - 2.0) érték kiszűri a sima piaci zajt/visszahúzódást.
    EXCURSION_THRESHOLD = 1.5

    # ↔️ SPREAD MANIPULÁCIÓ
    # Hányszorosára kell tágulnia a Spreadnek a helyi átlaghoz képest?
    # (A bróker profit zárásnál gyakran agresszívebb. Pl. 2.0 = duplázódás, 1.5 = 50% tágulás)
    SPREAD_MULTIPLIER_OPEN = 2.0
    SPREAD_MULTIPLIER_CLOSE = 2.5

    # ⏱️ TICK LEFAGYASZTÁS / KÉSLELTETÉS (LATENCY)
    # Milyen Time_Delta_MS (milliszekundum) számít "lefagyasztásnak"?
    LATENCY_THRESHOLD_MS = 2000

    # ⚡ SL VADÁSZAT / RÁNGATÁS (WHIPSAW)
    # Hányszorosa legyen a 10-tickes jövőbeli volatilitás (Max-Min) az előző 50 tick átlagának?
    # Szigorítottuk 1.5-ről 2.0-ra, hogy csak az igazi "Színház" (Theater) rángatások akadjanak fenn.
    WHIPSAW_THRESHOLD = 2.0

# ==============================================================================

class BrokerReactionLabeler:
    """
    'A Kályha' - Felügyelt Tanulás (Supervised Learning) Címkéző Algoritmus

    A szkript célja az "Állapotfelmérés" (Situational Awareness) a trade belépés pillanatában.
    Végigiterál a historikus tick adatokon, megkeresi a belépési pontokat (PosCount ugrás),
    majd megvizsgálja az azt követő, rendkívül rövid (1-10 tick) ablakot.

    Ha a bróker algoritmusa egyértelműen beavatkozott VAGY trükközött, a belépést megelőző
    állapotot TARGET = 1 (Bróker Algoritmus Aktív) címkével látja el.
    Ha a piac természetes mederben haladt tovább a belépés után: TARGET = 0 (Természetes Piac).
    """

    def __init__(self, config=LabelerConfig):
        self.config = config

    def process_file(self, file_path, output_dir, report_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"\n=======================================================")
        logger.info(f"🏷️ VISELKEDÉSPROFILOZÓ CÍMKÉZÉS: {file_name}")
        logger.info(f"=======================================================")

        report_lines = []
        report_lines.append(f"=========================================================================")
        report_lines.append(f"🏷️ BRÓKERI REAKCIÓ (CÍMKÉZÉSI) RIPORT: {file_name}")
        report_lines.append(f"=========================================================================\n")

        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            logger.error(f"Nem sikerült beolvasni a fájlt: {str(e)}")
            return

        if 'PosCount' not in df.columns or 'LotDir' not in df.columns or 'Bid' not in df.columns:
            logger.warning(f"Hiányoznak a kritikus oszlopok (PosCount, LotDir, Bid) a {file_name} fájlból!")
            return

        # Létrehozzuk az új Target oszlopot (Alapértelmezett: 0, azaz Nincs Reakció)
        df['Broker_Reaction_Target'] = 0
        df['Reaction_Type'] = "None" # Szöveges magyarázat a címke okáról

        trade_count = 0
        reaction_count = 0
        trade_events_for_plot = []

        # Végigfutunk a sorokon és megkeressük az ESEMÉNYEKET (Belépés / Zárás)
        for i in range(1, len(df)):
            # 1. NYITÁSOK VIZSGÁLATA (amikor a PosCount megnő)
            is_open = df.loc[i, 'PosCount'] > df.loc[i-1, 'PosCount']
            # 2. ZÁRÁSOK VIZSGÁLATA (amikor a PosCount csökken)
            is_close = df.loc[i, 'PosCount'] < df.loc[i-1, 'PosCount']

            if is_open or is_close:
                trade_count += 1

                # Robusztus Trade Irány feldolgozás
                raw_dir = 0
                if 'LotDir' in df.columns:
                    raw_dir = df.loc[i, 'LotDir']
                elif 'Trade_Dir' in df.columns:
                    raw_dir = df.loc[i, 'Trade_Dir']

                trade_dir = 0
                if isinstance(raw_dir, str):
                    raw_str = raw_dir.strip().lower()
                    if raw_str in ['1', 'buy', 'long']: trade_dir = 1
                    elif raw_str in ['-1', 'sell', 'short', '0']: trade_dir = -1
                else:
                    if raw_dir == 0:
                        trade_dir = 1 # Ha 0, feltételezzük, hogy MT5 BUY (ORDER_TYPE_BUY)
                    elif raw_dir == 1:
                        trade_dir = -1 if 'Order_Type' in df.columns else 1
                    elif raw_dir == -1:
                        trade_dir = -1
                    elif raw_dir > 0:
                        trade_dir = 1
                    elif raw_dir < 0:
                        trade_dir = -1

                event_type = "NYITÁS" if is_open else "ZÁRÁS"
                entry_price = df.loc[i, 'Bid']

                # A belépés/zárás utáni rövid 'forward_window'
                end_idx = min(i + self.config.FORWARD_WINDOW, len(df))
                future_window = df.iloc[i:end_idx]

                if future_window.empty or trade_dir == 0:
                    continue

                is_reaction = False
                reaction_reasons = []

                # --- MINTÁZATOK (VISELKEDÉSPROFILOZÁS) ---

                # MINTÁZAT 1: "Fake Breakout / Reversal" (Álpozitív Irány, aztán Bumm)
                # A bróker trükközik: az első 1-3 tick kedvező, aztán beszakad az entry alá.
                if len(future_window) >= 4:
                    first_ticks = future_window.iloc[0:3]
                    rest_ticks = future_window.iloc[3:]

                    if trade_dir == 1: # Buy
                        max_first = first_ticks['Bid'].max()
                        min_rest = rest_ticks['Bid'].min()
                        if max_first > entry_price and min_rest < entry_price:
                            is_reaction = True
                            reaction_reasons.append(f"Trükk/Visszafordulás (Fake: +{max_first-entry_price:.2f}, Rev: -{entry_price-min_rest:.2f})")
                    elif trade_dir == -1: # Sell
                        min_first = first_ticks['Bid'].min()
                        max_rest = rest_ticks['Bid'].max()
                        if min_first < entry_price and max_rest > entry_price:
                            is_reaction = True
                            reaction_reasons.append(f"Trükk/Visszafordulás (Fake: -{entry_price-min_first:.2f}, Rev: +{max_rest-entry_price:.2f})")

                # MINTÁZAT 2: "SL Hunting / Whipsaw" (Agresszív Rángatás / Le-Felszúrás) - CSAK NYITÁSKOR
                start_lookback = max(0, i - 50)
                local_volatility = df.iloc[start_lookback:i]['Bid'].max() - df.iloc[start_lookback:i]['Bid'].min()
                future_volatility = future_window['Bid'].max() - future_window['Bid'].min()

                if is_open and local_volatility > 0 and future_volatility > (local_volatility * self.config.WHIPSAW_THRESHOLD):
                    is_reaction = True
                    reaction_reasons.append(f"SL Vadászat/Rángatás (Vol: {future_volatility:.2f})")

                # MIKRO-TREND MEGHATÁROZÁSA (Az Attribúciós Hiba kiszűrése Counter-Trend belépéseknél) - CSAK NYITÁSKOR
                # Ha eső piacon veszel (Buy), az árfolyam normális, természetes (Target=0) viselkedése, hogy tovább esik ellened.
                # Ezt a "Lassú Kivéreztetést" csak TRENDIRÁNYÚ (Trend-Following) belépésnél büntetjük (Target=1).
                start_lookback = max(0, i - 50)
                past_prices = df.iloc[start_lookback:i]['Bid'].values
                if len(past_prices) > 10:
                    # Egyszerű lineáris regresszió (meredekség / slope) az elmúlt 50 tickre
                    x = np.arange(len(past_prices))
                    slope, _ = np.polyfit(x, past_prices, 1)
                    is_uptrend = slope > 0.0001
                    is_downtrend = slope < -0.0001
                else:
                    is_uptrend = False
                    is_downtrend = False

                is_counter_trade = (trade_dir == 1 and is_downtrend) or (trade_dir == -1 and is_uptrend)

                # MINTÁZAT 3: "Slow Bleed" (Kivéreztetés Döglött Piacon / Klasszikus Adverse Excursion) - CSAK NYITÁSKOR
                if is_open:
                    if not is_counter_trade:
                        if trade_dir == 1: # Buy (Az árfolyam esése az ellenség)
                            lowest_bid = future_window['Bid'].min()
                            excursion = entry_price - lowest_bid
                            if excursion > self.config.EXCURSION_THRESHOLD and not any("Vadászat" in r for r in reaction_reasons) and not any("Trükk" in r for r in reaction_reasons):
                                is_reaction = True
                                reaction_reasons.append(f"Lassú Kivéreztetés (-{excursion:.2f})")
                        elif trade_dir == -1: # Sell (Az árfolyam növekedése az ellenség)
                            highest_bid = future_window['Bid'].max()
                            excursion = highest_bid - entry_price
                            if excursion > self.config.EXCURSION_THRESHOLD and not any("Vadászat" in r for r in reaction_reasons) and not any("Trükk" in r for r in reaction_reasons):
                                is_reaction = True
                                reaction_reasons.append(f"Lassú Kivéreztetés (+{excursion:.2f})")
                    else:
                        # MINTÁZAT 3B (COUNTER-TREND): A bróker algoritmusa "rácsatlakozik" a Counter-Trade-re.
                        if trade_dir == 1: # Buy eső piacon
                            highest_bid = future_window['Bid'].max()
                            counter_excursion = highest_bid - entry_price
                            if counter_excursion > self.config.EXCURSION_THRESHOLD and not any("Vadászat" in r for r in reaction_reasons):
                                is_reaction = True
                                reaction_reasons.append(f"Természetellenes Azonnali Fordulat (Counter: +{counter_excursion:.2f})")
                        elif trade_dir == -1: # Sell emelkedő piacon
                            lowest_bid = future_window['Bid'].min()
                            counter_excursion = entry_price - lowest_bid
                            if counter_excursion > self.config.EXCURSION_THRESHOLD and not any("Vadászat" in r for r in reaction_reasons):
                                is_reaction = True
                                reaction_reasons.append(f"Természetellenes Azonnali Fordulat (Counter: -{counter_excursion:.2f})")

                # 4. SPREAD MANIPULÁCIÓ (Nyitáskor és Záráskor is!)
                if 'Spread' in df.columns:
                    local_avg_spread = df.iloc[start_lookback:i]['Spread'].mean()
                    if not pd.isna(local_avg_spread) and local_avg_spread > 0:
                        max_future_spread = future_window['Spread'].max()

                        # Külön szorzó nyitásra és zárásra (profit védelme)
                        active_multiplier = self.config.SPREAD_MULTIPLIER_OPEN if is_open else self.config.SPREAD_MULTIPLIER_CLOSE

                        if max_future_spread > (local_avg_spread * active_multiplier):
                            is_reaction = True
                            reaction_reasons.append(f"Spread Tágítás {event_type} ({max_future_spread:.1f})")

                # 5. TICK LEFAGYASZTÁS / LATENCY (Kiegészítő fegyver)
                # Mennyi ideig nem jelentkezik újabb tick? (MAX ugrás két egymást követő tick között)
                max_latency = 0.0

                # Ha van Time_Delta_MS (két tick közötti diff MS-ban), az eleve a válasz.
                if 'Time_Delta_MS' in df.columns:
                    max_latency = future_window['Time_Delta_MS'].max()
                else:
                    # Második kör: Ha nincs Time_Delta, megkeressük a nyers TickMSC / TimeMsc oszlopot.
                    time_cols = [c for c in df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
                    if time_cols:
                        time_col = time_cols[0]
                        # Az MT5 TimeMsc / TickMSC valójában egy gigantikus int64 Unix Timestamp (1767258001136).
                        # Nincs szükség Date/Time konverzióra! A sima numerikus kivonás (diff) megadja a késleltetést MS-ban:
                        try:
                            latencies = future_window[time_col].astype(float).diff()
                            max_latency = latencies.max()
                        except Exception:
                            pass

                if pd.isna(max_latency) or max_latency < 0:
                    max_latency = 0.0

                if max_latency > self.config.LATENCY_THRESHOLD_MS:
                    is_reaction = True
                    reaction_reasons.append(f"Lefagyás/Késleltetés {event_type} ({max_latency:.0f}ms)")

                # Ha a Bróker Algoritmus reagált (Bármelyik a fentiek közül teljesült)
                if is_reaction:
                    reaction_count += 1
                    # A belépés/zárás előtti "Állapotot" felcímkézzük 1-esre
                    label_start = max(0, i - 10)
                    df.loc[label_start:i, 'Broker_Reaction_Target'] = 1
                    df.loc[i, 'Reaction_Type'] = " | ".join(reaction_reasons)

                    msg = f"🚨 [BRÓKER REAKCIÓ] {event_type} #{trade_count} (Sor: {i}) -> Ok: {df.loc[i, 'Reaction_Type']}"
                    logger.info(f"   {msg}")
                    report_lines.append(msg)
                    trade_events_for_plot.append({'index': i, 'type': event_type, 'target': 1})
                else:
                    msg = f"✅ [TERMÉSZETES PIAC] {event_type} #{trade_count} (Sor: {i}) -> A piac akadálytalanul haladt tovább."
                    logger.info(f"   {msg}")
                    report_lines.append(msg)
                    trade_events_for_plot.append({'index': i, 'type': event_type, 'target': 0})

        # --- RÉSZLETES DIAGNOSZTIKA A CÍMKÉZÉS ÖSSZETÉTELÉRŐL (A HMM VAKU 3.0 MIATT) ---
        reaction_types = df[df['Broker_Reaction_Target'] == 1]['Reaction_Type'].tolist()
        whipsaw_count = sum(1 for r in reaction_types if "Rángatás" in r or "Trükk" in r)
        slow_bleed_count = sum(1 for r in reaction_types if "Lassú Kivéreztetés" in r)
        spread_count = sum(1 for r in reaction_types if "Spread Tágítás" in r)
        latency_count = sum(1 for r in reaction_types if "Lefagyás" in r)

        # Összegzés a Riportba
        summary = f"\n--- ÖSSZEGZÉS: {file_name} ---\nÖsszes Esemény (Trade Nyitás/Zárás): {trade_count}\nEbből Brókeri Reakció (Target=1): {reaction_count} ({(reaction_count/max(1, trade_count))*100:.1f}%)\n"
        summary += f"  -> Ebből 'Színház / Whipsaw / Trükk': {whipsaw_count} db\n"
        summary += f"  -> Ebből 'Lassú Kivéreztetés' (Adverse Excursion): {slow_bleed_count} db\n"
        summary += f"  -> Ebből 'Spread Tágítás': {spread_count} db\n"
        summary += f"  -> Ebből 'Tick Lefagyás': {latency_count} db\n"

        report_lines.append(summary)

        # Fájlok Mentése
        output_file = os.path.join(output_dir, f"LABELED_{file_name}")
        df.to_csv(output_file, index=False)

        report_file = os.path.join(report_dir, f"LABEL_REPORT_{file_name.replace('.csv', '')}.txt")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(summary)
        logger.info(f"Adatbázis Kimentve: {output_file}")
        logger.info(f"Riport Kimentve: {report_file}\n")

        # Vizualizáció Grafikonon (Ha van Matplotlib)
        if HAS_PLOT:
            self._plot_labels(df, trade_events_for_plot, file_name, report_dir)

    def _plot_labels(self, df, trade_events, file_name, report_dir):
        """Kirajzolja a Bid árat, és piros háttérrel megjelöli az 1-esre címkézett (Manipulált) területeket."""
        try:
            plt.figure(figsize=(16, 8))
            plt.title(f"Brókeri Reakció (Címkézés) Vizualizációja: {file_name}")

            # X tengely (Index vagy Tick sorszám)
            x_data = df.index
            y_data = df['Bid']
            plt.plot(x_data, y_data, label='Bid (Árfolyam)', color='blue', linewidth=1)

            # Beszínezzük pirossal azokat az "Állapotokat" (10 tickes sávokat), amik Target=1 címkét kaptak
            labeled_indices = df[df['Broker_Reaction_Target'] == 1].index
            for idx in labeled_indices:
                plt.axvspan(idx - 0.5, idx + 0.5, color='red', alpha=0.3, lw=0)

            # Megjelöljük a konkrét Trade (Nyitás/Zárás) Eseményeket pöttyökkel
            for ev in trade_events:
                idx = ev['index']
                price = df.loc[idx, 'Bid']
                if ev['target'] == 1:
                    plt.scatter(idx, price, color='red', s=100, marker='X', zorder=5, label='Reakció (Trükk)' if 'Reakció (Trükk)' not in plt.gca().get_legend_handles_labels()[1] else "")
                else:
                    plt.scatter(idx, price, color='green', s=100, marker='o', zorder=5, label='Normál Piac' if 'Normál Piac' not in plt.gca().get_legend_handles_labels()[1] else "")

            plt.xlabel('Tick Sorszám')
            plt.ylabel('Bid Árfolyam')
            plt.legend(loc='best')
            plt.grid(True, linestyle='--', alpha=0.6)
            plt.tight_layout()

            plot_file = os.path.join(report_dir, f"LABEL_PLOT_{file_name.replace('.csv', '')}.png")
            plt.savefig(plot_file, dpi=150)
            plt.close()
            logger.info(f"📊 Vizualizáció kimentve: {plot_file}")
        except Exception as e:
            logger.error(f"Hiba a grafikon generálása során: {str(e)}")

def run_labeler():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'data', 'labeled')
    report_dir = os.path.join(base_dir, 'reports_tmp')

    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(report_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning(f"Nem találtam megfelelő CSV fájlokat a {input_dir} könyvtárban!")
        return

    logger.info(f"Összesen {len(csv_files)} fájl vár viselkedésprofilozó címkézésre (Állapotfelmérés).")

    # A Címkéző inicializálása a globális Config blokk alapján
    labeler = BrokerReactionLabeler(config=LabelerConfig)

    for file in csv_files:
        labeler.process_file(file, output_dir, report_dir)

if __name__ == '__main__':
    run_labeler()
