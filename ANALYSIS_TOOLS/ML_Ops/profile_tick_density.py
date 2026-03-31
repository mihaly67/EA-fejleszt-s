import os
import glob
import pandas as pd
import numpy as np
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class TickDensityProfiler:
    """
    Kutatási Eszköz (Napszakok és Volatilitás Profilozására):
    A célja, hogy felmérje a különböző időpontokban (pl. 20:00 vs 22:00) exportált
    CSV fájlok 'Tick Sűrűségét' (Tick Density = Ticks / Second).

    A kapott statisztikák (Min, Max, Átlag, P50, P90 tick/sec) alapján később
    biztonságosan meghatározható egy dinamikus HMM/Labeler Ablakméret (Window Size)
    képlet az online működéshez.
    """

    def process_file(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"📊 Tick Sűrűség Profilozása: {file_name}")

        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            logger.error(f"Hiba a beolvasáskor: {e}")
            return None

        # Időbélyeg (Msc) keresése
        time_cols = [c for c in df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
        if not time_cols:
            logger.warning(f"Nem található milliszekundumos időbélyeg (TimeMsc) a {file_name} fájlban!")
            return None

        time_col = time_cols[0]

        # 1. Kiszámoljuk az inter-arrival time-ot (két tick közötti idő MS-ban)
        # float konverzió a biztonság kedvéért, ha stringként érkezne a hatalmas int64.
        iat_ms = df[time_col].astype(float).diff().dropna()

        # Kiszűrjük az irreális (negatív vagy 0) időugrásokat, amik MT5 export hibák lehetnek
        iat_ms = iat_ms[iat_ms > 0]

        if len(iat_ms) == 0:
            logger.warning(f"Nincs elegendő érvényes tick sebesség adat a {file_name} fájlban.")
            return None

        # 2. Átszámítjuk másodpercenkénti tick sebességre (Tick / Sec)
        # Ha a két tick között 50ms telt el -> 1000 / 50 = 20 tick/sec sebesség abban a pillanatban.
        tick_speed_sec = 1000.0 / iat_ms

        # 3. Kiszámoljuk a teljes fájl "Makro" sebességét (Total Ticks / Total Seconds)
        total_time_ms = df[time_col].astype(float).max() - df[time_col].astype(float).min()
        total_time_sec = total_time_ms / 1000.0
        macro_avg_speed = len(df) / total_time_sec if total_time_sec > 0 else 0

        # 4. Statisztikák kinyerése
        stats = {
            "File": file_name,
            "Total_Ticks": len(df),
            "Duration_Min": total_time_sec / 60.0,
            "Macro_Avg_Tick_Per_Sec": macro_avg_speed,
            "Micro_Speed_P50": tick_speed_sec.median(), # Jellemző pillanatnyi sebesség
            "Micro_Speed_P90": tick_speed_sec.quantile(0.90), # Sűrűsödési csúcsok (pl. hír vagy manipuláció)
            "Micro_Speed_Max": tick_speed_sec.max()
        }

        return stats

    def generate_global_report(self, all_stats, output_dir):
        if not all_stats:
            logger.warning("Nincs mit riportálni.")
            return

        report_lines = []
        report_lines.append("=========================================================================")
        report_lines.append("⏱️ KUTATÁSI RIPORT: NAPSZAKOS TICK SŰRŰSÉG (TICK DENSITY PROFILER)")
        report_lines.append("=========================================================================\n")
        report_lines.append("Ezek az adatok szolgálnak alapul a jövőbeli dinamikus ablakméret (Window Size)")
        report_lines.append("szabályrendszerének felépítéséhez, hogy a nappali (HFT) és éjszakai (Lassú)")
        report_lines.append("piacokat az AI egyformán fizikai időben (pl. 3 másodperc) tudja vizsgálni.\n")

        # Sort by Macro Avg Speed (descending) to easily see Active vs Quiet sessions
        all_stats_sorted = sorted(all_stats, key=lambda x: x["Macro_Avg_Tick_Per_Sec"], reverse=True)

        for i, s in enumerate(all_stats_sorted, 1):
            report_lines.append(f"--- [ {i}. {s['File']} ] ---")
            report_lines.append(f"  Időtartam: {s['Duration_Min']:.1f} perc | Összes Tick: {s['Total_Ticks']}")
            report_lines.append(f"  Makro Átlagos Sebesség: {s['Macro_Avg_Tick_Per_Sec']:.1f} Tick/Másodperc")
            report_lines.append(f"  Jellemző Pillanatnyi Sebesség (P50): {s['Micro_Speed_P50']:.1f} Tick/Másodperc")
            report_lines.append(f"  Csúcssebesség (P90): {s['Micro_Speed_P90']:.1f} Tick/Másodperc")
            report_lines.append(f"  Abszolút Maximum Sebesség: {s['Micro_Speed_Max']:.1f} Tick/Másodperc\n")

            # Dinamikus Ablakméret javaslat (Pl. 3 másodperces fizikai fókuszhoz)
            suggested_window = int(s['Macro_Avg_Tick_Per_Sec'] * 3.0)
            suggested_window = max(10, min(150, suggested_window)) # Bounded between 10 and 150
            report_lines.append(f"  [AI JAVASLAT] Ideális 3-másodperces HMM Ablakméret erre a fájlra: ~{suggested_window} tick\n")

        output_file = os.path.join(output_dir, "RESEARCH_TICK_DENSITY_PROFILES.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(f"✅ Kutatási Riport Kimentve: {output_file}")


def run_profiler():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'reports_tmp')

    os.makedirs(output_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
    # Szűrjük a már feldolgozott/címkézett fájlokat, csak az eredetieket akarjuk
    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning(f"Nem találtam eredeti CSV fájlokat a {input_dir} könyvtárban a sűrűségméréshez!")
        return

    logger.info(f"Összesen {len(csv_files)} fájl vár Tick Sűrűség (Napszak) Profilozásra...")

    profiler = TickDensityProfiler()
    all_stats = []

    for file in csv_files:
        stats = profiler.process_file(file, output_dir)
        if stats:
            all_stats.append(stats)

    if all_stats:
        profiler.generate_global_report(all_stats, output_dir)

if __name__ == '__main__':
    run_profiler()
