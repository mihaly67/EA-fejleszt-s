import os
import glob
import pandas as pd
import numpy as np
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# ==============================================================================
# ⚙️ FELHASZNÁLÓI BEÁLLÍTÁSOK (CÍMKÉZÉSI SZABÁLYOK FINOMHANGOLÁSA)
# Ezt a blokkot nyugodtan módosíthatod a CSV teszteléseid (Data Profiling) alapján!
# ==============================================================================

class LabelerConfig:
    # Milyen messzire nézzünk előre a belépés/zárás után (tickekben)?
    FORWARD_WINDOW = 10

    # 📉 ADVERSE EXCURSION (Rám Ugrás / Lassú Kivéreztetés)
    # Minimális ellentétes elmozdulás pontban. (pl. 0.5 vagy 1.0)
    EXCURSION_THRESHOLD = 0.5

    # ↔️ SPREAD MANIPULÁCIÓ
    # Hányszorosára kell tágulnia a Spreadnek a helyi átlaghoz képest?
    # (A bróker profit zárásnál gyakran agresszívebb. Pl. 2.0 = duplázódás, 1.5 = 50% tágulás)
    SPREAD_MULTIPLIER_OPEN = 1.5
    SPREAD_MULTIPLIER_CLOSE = 2.0

    # ⏱️ TICK LEFAGYASZTÁS / KÉSLELTETÉS (LATENCY)
    # Milyen Time_Delta_MS (milliszekundum) számít "lefagyasztásnak"?
    LATENCY_THRESHOLD_MS = 2000

    # ⚡ SL VADÁSZAT / RÁNGATÁS (WHIPSAW)
    # Hányszorosa legyen a 10-tickes jövőbeli volatilitás (Max-Min) az előző 50 tick átlagának?
    WHIPSAW_THRESHOLD = 1.5

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

    def process_file(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"\n=======================================================")
        logger.info(f"🏷️ VISELKEDÉSPROFILOZÓ CÍMKÉZÉS: {file_name}")
        logger.info(f"=======================================================")

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

        # Végigfutunk a sorokon és megkeressük az ESEMÉNYEKET (Belépés / Zárás)
        for i in range(1, len(df)):
            # 1. NYITÁSOK VIZSGÁLATA (amikor a PosCount megnő)
            is_open = df.loc[i, 'PosCount'] > df.loc[i-1, 'PosCount']
            # 2. ZÁRÁSOK VIZSGÁLATA (amikor a PosCount csökken)
            is_close = df.loc[i, 'PosCount'] < df.loc[i-1, 'PosCount']

            if is_open or is_close:
                trade_count += 1
                trade_dir = df.loc[i, 'LotDir']
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
                if 'Time_Delta_MS' in df.columns:
                    max_latency = future_window['Time_Delta_MS'].max()
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

                    logger.info(f"   🚨 [BRÓKER REAKCIÓ] {event_type} #{trade_count} -> Ok: {df.loc[i, 'Reaction_Type']}")
                else:
                    logger.info(f"   ✅ [TERMÉSZETES PIAC] {event_type} #{trade_count} -> A piac akadálytalanul haladt tovább.")

        # Fájl Mentése
        output_file = os.path.join(output_dir, f"LABELED_{file_name}")
        df.to_csv(output_file, index=False)

        logger.info(f"--- ÖSSZEGZÉS: {file_name} ---")
        logger.info(f"Összes Belépés (Trade): {trade_count}")
        logger.info(f"Ebből Brókeri Reakció (Target=1): {reaction_count} ({(reaction_count/max(1, trade_count))*100:.1f}%)")
        logger.info(f"Kimentve: {output_file}\n")


def run_labeler():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'data', 'labeled')

    os.makedirs(output_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning(f"Nem találtam megfelelő CSV fájlokat a {input_dir} könyvtárban!")
        return

    logger.info(f"Összesen {len(csv_files)} fájl vár viselkedésprofilozó címkézésre (Állapotfelmérés).")

    # A Címkéző inicializálása a globális Config blokk alapján
    labeler = BrokerReactionLabeler(config=LabelerConfig)

    for file in csv_files:
        labeler.process_file(file, output_dir)

if __name__ == '__main__':
    run_labeler()
