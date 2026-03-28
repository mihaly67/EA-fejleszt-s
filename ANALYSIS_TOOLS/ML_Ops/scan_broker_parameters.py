import os
import glob
import pandas as pd
import numpy as np
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class BrokerParameterScanner:
    """
    'A Szkenner' - Data Profiling Eszköz a Címkéző Paramétereinek beállításához.

    Végigfut a megadott CSV fájlokon, megkeresi az összes Pozíció Nyitást és Zárást
    (a PosCount oszlop ugrásai alapján). Minden eseménynél megvizsgálja a rákövetkező
    ablakot (pl. 10 tick), és kigyűjti a tényleges brókeri reakciók paramétereit
    (Spread tágulás szorzója, Adverse Excursion pontban, Max Latency ms-ban,
    Volatilitás rángatás szorzója).

    A végeredményt egy olvasható TXT riportba menti, soronként listázva az eseményeket,
    majd a végén egy Átlagos/Maximális/90. Percentilis statisztikát ad.
    """

    def __init__(self, forward_window=10, lookback_window=50):
        self.forward_window = forward_window
        self.lookback_window = lookback_window

    def scan_file(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"🔍 Szkenner indítása: {file_name}")

        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            logger.error(f"Fájl beolvasási hiba: {str(e)}")
            return

        if 'PosCount' not in df.columns or 'Bid' not in df.columns:
            logger.warning(f"Kritikus oszlopok (PosCount, Bid) hiányoznak a {file_name} fájlból.")
            return

        # Segédváltozók a statisztikához
        open_events = []
        close_events = []

        # Soronként végigiterálunk a fájlon
        for i in range(1, len(df)):
            is_open = df.loc[i, 'PosCount'] > df.loc[i-1, 'PosCount']
            is_close = df.loc[i, 'PosCount'] < df.loc[i-1, 'PosCount']

            if not (is_open or is_close):
                continue

            # Esemény alapadatok
            event_type = "NYITÁS" if is_open else "ZÁRÁS"
            # Dinamikus Irány (LotDir, Trade_Dir, vagy szöveges Buy/Sell) felismerése
            raw_dir = 0
            if 'LotDir' in df.columns:
                raw_dir = df.loc[i, 'LotDir']
            elif 'Trade_Dir' in df.columns:
                raw_dir = df.loc[i, 'Trade_Dir']

            trade_dir = 0
            if isinstance(raw_dir, str):
                raw_str = raw_dir.strip().lower()
                if raw_str in ['1', 'buy', 'long']: trade_dir = 1
                elif raw_str in ['-1', 'sell', 'short', '0']: trade_dir = -1 # A MetaTrader-ben sokszor a 0 a SELL vagy a BUY!
            else:
                # MT5 ENUM_ORDER_TYPE: 0 = BUY, 1 = SELL (Gyakran ez exportálódik)
                # Vagy 1 = BUY, -1 = SELL. Ezt le kell fedni!
                if raw_dir == 0:
                    trade_dir = 1 # Ha 0, feltételezzük, hogy MT5 BUY (ORDER_TYPE_BUY)
                elif raw_dir == 1:
                    trade_dir = -1 if 'Order_Type' in df.columns else 1 # Ha Order Type, akkor 1 = Sell. Ha LotDir, 1 = Buy. Ezt nehéz eldönteni.
                elif raw_dir == -1:
                    trade_dir = -1
                elif raw_dir > 0:
                    trade_dir = 1
                elif raw_dir < 0:
                    trade_dir = -1

            entry_price = df.loc[i, 'Bid']
            timestamp = df.loc[i, 'TimeMsc'] if 'TimeMsc' in df.columns else (df.loc[i, 'TickMSC'] if 'TickMSC' in df.columns else df.loc[i, 'Time'] if 'Time' in df.columns else i)

            # Ablakok (Jövő és Múlt)
            end_idx = min(i + self.forward_window, len(df))
            start_idx = max(0, i - self.lookback_window)

            future_window = df.iloc[i:end_idx]
            past_window = df.iloc[start_idx:i]

            if future_window.empty or past_window.empty:
                continue

            # --- PARAMÉTEREK KISZÁMÍTÁSA ---

            # 1. Spread Tágulás (Multiplier)
            spread_multiplier = 1.0
            max_spread = 0.0
            if 'Spread' in df.columns:
                local_avg_spread = past_window['Spread'].mean()
                if local_avg_spread > 0:
                    max_spread = future_window['Spread'].max()
                    spread_multiplier = max_spread / local_avg_spread

            # 2. Tick Lefagyasztás (Max Latency)
            # A felhasználó panasza: "mennyi ideig nem jelentkezik újabb tick".
            # Ez NEM az ablak hossza, hanem az egymást követő tickek közötti MAXIMÁLIS ugrás (diff) a future_window-ban!
            max_latency = 0.0
            # Kisbetűs-nagybetűs rugalmas oszlopkeresés (TimeMsc, Time_msc, TickMSC)
            time_cols = [c for c in df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if time_cols:
                time_col = time_cols[0]
                max_latency = future_window[time_col].diff().max()
            elif 'Time_Delta_MS' in df.columns:
                max_latency = future_window['Time_Delta_MS'].max() # Ez már eleve a diff

            if pd.isna(max_latency):
                max_latency = 0.0

            # 3. Adverse Excursion (Rám Ugrás maximuma)
            adverse_excursion = 0.0
            if is_open and trade_dir != 0:
                if trade_dir == 1: # Buy (Az esés a rám ugrás)
                    min_future = future_window['Bid'].min()
                    adverse_excursion = entry_price - min_future if min_future < entry_price else 0.0
                elif trade_dir == -1: # Sell (A növekedés a rám ugrás)
                    max_future = future_window['Bid'].max()
                    adverse_excursion = max_future - entry_price if max_future > entry_price else 0.0

            # Zárásnál (Close) is nézhetünk adverse elmozdulást az előző trade irányához képest,
            # de mivel a zárás önmagában egy esemény (Spread a lényeg), az Excursiont 0-nak hagyjuk,
            # hacsak nem akarjuk mérni a slippage-et a kért zárt árhoz képest (de a kért ár nincs a CSV-ben).

            # 4. SL Vadászat / Rángatás (Whipsaw Multiplier)
            whipsaw_multiplier = 1.0
            local_volatility = past_window['Bid'].max() - past_window['Bid'].min()
            future_volatility = future_window['Bid'].max() - future_window['Bid'].min()
            if local_volatility > 0:
                whipsaw_multiplier = future_volatility / local_volatility

            # Profit/Veszteség Zárás meghatározása (Pribék logika)
            profit_status = "N/A"
            if is_close and 'Profit' in df.columns:
                profit_val = df.loc[i, 'Profit']
                if profit_val > 0:
                    profit_status = "PROFITOS"
                elif profit_val < 0:
                    profit_status = "VESZTESÉGES"
                else:
                    profit_status = "NULLSZALDÓ"

            # Esemény mentése
            event_data = {
                "Type": event_type,
                "Time": str(timestamp),
                "Dir": "BUY" if trade_dir == 1 else ("SELL" if trade_dir == -1 else "N/A"),
                "Spread_Mult": spread_multiplier,
                "Max_Spread": max_spread,
                "Latency_MS": max_latency,
                "Adverse_Exc": adverse_excursion,
                "Whipsaw_Mult": whipsaw_multiplier,
                "Profit_Status": profit_status
            }

            if is_open:
                open_events.append(event_data)
            else:
                close_events.append(event_data)

        # --- TXT RIPORT GENERÁLÁSA ---
        self._generate_report(file_name, output_dir, open_events, close_events)

    def _generate_report(self, file_name, output_dir, open_events, close_events):
        report_lines = []
        report_lines.append(f"=========================================================================")
        report_lines.append(f"🔍 BRÓKERI PARAMÉTER SZKENNER RIPORT: {file_name}")
        report_lines.append(f"=========================================================================\n")

        # RÉSZLETES LISTA - NYITÁSOK
        report_lines.append(f"--- [ 1. NYITÁSOK ({len(open_events)} db) - ESEMÉNY LISTA ] ---")
        for i, ev in enumerate(open_events, 1):
            line = f"#{i:03d} | Idő: {ev['Time']} | Irány: {ev['Dir']} | Spread Tágulás: {ev['Spread_Mult']:.2f}x (Max: {ev['Max_Spread']:.1f}) | Adverse Rám Ugrás: {ev['Adverse_Exc']:.3f} | Rángatás (Whipsaw): {ev['Whipsaw_Mult']:.2f}x | Max Lefagyás: {ev['Latency_MS']:.0f}ms"
            report_lines.append(line)

        # RÉSZLETES LISTA - ZÁRÁSOK
        report_lines.append(f"\n--- [ 2. ZÁRÁSOK ({len(close_events)} db) - ESEMÉNY LISTA ] ---")
        for i, ev in enumerate(close_events, 1):
            line = f"#{i:03d} | Idő: {ev['Time']} | Típus: {ev['Profit_Status']} | Spread Tágulás: {ev['Spread_Mult']:.2f}x (Max: {ev['Max_Spread']:.1f}) | Rángatás (Whipsaw): {ev['Whipsaw_Mult']:.2f}x | Max Lefagyás: {ev['Latency_MS']:.0f}ms"
            report_lines.append(line)

        # --- ÖSSZESÍTŐ STATISZTIKA ---
        report_lines.append(f"\n=========================================================================")
        report_lines.append(f"📊 ÖSSZESÍTŐ STATISZTIKA (AZ ALAP BEÁLLÍTÁSÁHOZ A CÍMKÉZŐBEN)")
        report_lines.append(f"=========================================================================\n")

        def generate_stats(events, name):
            if not events:
                return f"\n[Nincsenek {name} adatok]\n"

            df_ev = pd.DataFrame(events)
            lines = [f"--- {name} STATISZTIKA ({len(events)} db) ---"]

            # Spread
            lines.append(f"Spread Tágulás Szorzó:   Átlag: {df_ev['Spread_Mult'].mean():.2f}x  |  Medián (P50): {df_ev['Spread_Mult'].median():.2f}x  |  Extrém (P90): {df_ev['Spread_Mult'].quantile(0.90):.2f}x  |  Max: {df_ev['Spread_Mult'].max():.2f}x")
            # Adverse Excursion (Csak nyitásnál van értelme)
            if name == "NYITÁS":
                lines.append(f"Adverse Excursion (pont):Átlag: {df_ev['Adverse_Exc'].mean():.3f}   |  Medián (P50): {df_ev['Adverse_Exc'].median():.3f}   |  Extrém (P90): {df_ev['Adverse_Exc'].quantile(0.90):.3f}   |  Max: {df_ev['Adverse_Exc'].max():.3f}")
            # Latency
            lines.append(f"Max Lefagyás (Latency):  Átlag: {df_ev['Latency_MS'].mean():.0f}ms  |  Medián (P50): {df_ev['Latency_MS'].median():.0f}ms  |  Extrém (P90): {df_ev['Latency_MS'].quantile(0.90):.0f}ms  |  Max: {df_ev['Latency_MS'].max():.0f}ms")
            # Whipsaw
            lines.append(f"Rángatás (Whipsaw Mult): Átlag: {df_ev['Whipsaw_Mult'].mean():.2f}x  |  Medián (P50): {df_ev['Whipsaw_Mult'].median():.2f}x  |  Extrém (P90): {df_ev['Whipsaw_Mult'].quantile(0.90):.2f}x  |  Max: {df_ev['Whipsaw_Mult'].max():.2f}x")
            lines.append("")
            return "\n".join(lines)

        report_lines.append(generate_stats(open_events, "NYITÁS"))

        # Zárások bontása (Profitos vs. Veszteséges)
        close_df = pd.DataFrame(close_events) if close_events else pd.DataFrame()
        if not close_df.empty:
            profit_closes = [e for e in close_events if e['Profit_Status'] == "PROFITOS"]
            loss_closes = [e for e in close_events if e['Profit_Status'] == "VESZTESÉGES"]

            report_lines.append(generate_stats(close_events, "ÖSSZES ZÁRÁS"))
            if profit_closes:
                report_lines.append(generate_stats(profit_closes, "PROFITOS ZÁRÁS"))
            if loss_closes:
                report_lines.append(generate_stats(loss_closes, "VESZTESÉGES ZÁRÁS"))

        # Mentés TXT-be
        report_text = "\n".join(report_lines)

        output_file = os.path.join(output_dir, f"BROKER_REPORT_{file_name.replace('.csv', '')}.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(report_text)

        logger.info(f"✅ Jelentés kimentve: {output_file}")


def run_scanner():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'reports_tmp') # Külön mappa a riportoknak

    os.makedirs(output_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
    # Szűrjük a már feldolgozott/címkézett fájlokat
    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning(f"Nem találtam megfelelő CSV fájlokat a {input_dir} könyvtárban a szkenneléshez!")
        return

    logger.info(f"Összesen {len(csv_files)} fájl vár Statisztikai Szkennelésre...")

    scanner = BrokerParameterScanner(forward_window=10, lookback_window=50)

    for file in csv_files:
        scanner.scan_file(file, output_dir)

if __name__ == '__main__':
    run_scanner()
