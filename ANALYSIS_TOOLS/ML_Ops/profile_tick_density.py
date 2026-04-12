import os
import glob
import pandas as pd
import numpy as np
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class TickDensityProfiler:
    """
    Kutatási Eszköz (Napszakok és Volatilitás Profilozására):
    A célja, hogy felmérje a különböző időpontokban exportált CSV fájlok
    'Tick Sűrűségét' (Tick Density = Ticks / Second).

    A script 'chunkolt' (memóriakímélő) módszerrel olvassa a gigantikus (akár több GB-os)
    fájlokat, hogy a 8GB RAM-os VPS-en se fusson OOM hibára.
    Létrehoz egy Órás Felbontású Sűrűség-Térképet.
    """

    def __init__(self, chunksize=100000):
        self.chunksize = chunksize

    def process_file_chunked(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"📊 Chunkolt Tick Sűrűség Profilozása indítása: {file_name}")

        hourly_stats = {} # Kulcs: YYYY-MM-DD HH, Érték: {ticks, total_time_ms, max_speed}

        total_ticks_processed = 0
        last_time_msc = None
        global_min_msc = float('inf')
        global_max_msc = 0.0

        time_col = None

        try:
            # Csak azokat az oszlopokat olvassuk be, amik kellenek a sebességhez
            # Az első chunk alapján határozzuk meg a time_col-t
            first_chunk = next(pd.read_csv(file_path, chunksize=10))
            time_cols = [c for c in first_chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if not time_cols:
                logger.warning(f"Nem található milliszekundumos időbélyeg (TimeMsc) a {file_name} fájlban!")
                return None
            time_col = time_cols[0]

            # Use columns filtering to save memory
            usecols = [time_col]

            for chunk_idx, chunk in enumerate(pd.read_csv(file_path, chunksize=self.chunksize, usecols=usecols)):

                # Biztosítjuk, hogy float legyen az int64 túlcsordulás miatt
                times_ms = chunk[time_col].astype(float)

                if times_ms.empty:
                    continue

                global_min_msc = min(global_min_msc, times_ms.min())
                global_max_msc = max(global_max_msc, times_ms.max())
                total_ticks_processed += len(chunk)

                # Ha volt előző chunk, hozzáfűzzük az utolsó elemet a diff számításhoz a határon
                if last_time_msc is not None:
                    times_with_prev = pd.concat([pd.Series([last_time_msc]), times_ms])
                    diffs_ms = times_with_prev.diff().dropna().values
                else:
                    diffs_ms = times_ms.diff().dropna().values

                last_time_msc = times_ms.iloc[-1]

                # Szűrjük a 0 vagy negatív értékeket
                valid_diffs = diffs_ms[diffs_ms > 0]

                if len(valid_diffs) > 0:
                    # Számítjuk a pillanatnyi tick sebességet (tick/sec)
                    speeds = 1000.0 / valid_diffs

                    # Órás bontáshoz időbélyegek generálása
                    # Itt közelítést alkalmazunk a memóriatakarékosság miatt: a chunk átlagos idejét használjuk
                    # MT5 TimeMsc általában Unix timestamp ezredmásodpercben
                    chunk_mean_msc = times_ms.mean()
                    try:
                        # Próbáljuk Unix timestampként értelmezni
                        hour_key = datetime.fromtimestamp(chunk_mean_msc / 1000.0).strftime('%Y-%m-%d %H:00')
                    except:
                        # Ha nem Unix, csak relatív idő a kezdettől
                        hours_from_start = int((chunk_mean_msc - global_min_msc) / (1000 * 60 * 60))
                        hour_key = f"Hour_{hours_from_start:03d}"

                    if hour_key not in hourly_stats:
                        hourly_stats[hour_key] = {
                            "ticks": 0,
                            "speeds_sample": [] # Csak mintát tárolunk, hogy ne egye meg a RAM-ot
                        }

                    hourly_stats[hour_key]["ticks"] += len(chunk)

                    # Csak minden N-edik sebességet mentjük el a mintába (downsampling), hogy ne teljen be a RAM 24 óra alatt
                    sample_size = min(len(speeds), 1000)
                    if sample_size > 0:
                        sampled = np.random.choice(speeds, sample_size, replace=False)
                        hourly_stats[hour_key]["speeds_sample"].extend(sampled.tolist())

                if chunk_idx % 10 == 0:
                    logger.info(f"  ... {total_ticks_processed:,} tick feldolgozva a memóriában.")

        except Exception as e:
            logger.error(f"Hiba a fájl chunkolt beolvasásakor: {e}")
            return None

        if total_ticks_processed == 0:
            return None

        # Globális statisztika számítása
        total_time_sec = (global_max_msc - global_min_msc) / 1000.0
        global_avg_speed = total_ticks_processed / total_time_sec if total_time_sec > 0 else 0

        logger.info(f"✅ Chunkolt elemzés kész! Összes tick: {total_ticks_processed:,}, Futtatási idő: {total_time_sec/3600:.1f} óra.")

        return {
            "File": file_name,
            "Total_Ticks": total_ticks_processed,
            "Duration_Hours": total_time_sec / 3600.0,
            "Global_Avg_Tick_Per_Sec": global_avg_speed,
            "Hourly_Stats": hourly_stats
        }

    def generate_report(self, stats, output_dir):
        if not stats:
            return

        file_name = stats['File']

        report_lines = []
        report_lines.append("=========================================================================")
        report_lines.append("🔥 VAKU 3.0: 24/48-ÓRÁS TICK SŰRŰSÉG HŐTÉRKÉP (ATDP ANALÍZIS)")
        report_lines.append("=========================================================================\n")
        report_lines.append(f"Fájl: {file_name}")
        report_lines.append(f"Feldolgozott adat: {stats['Total_Ticks']:,} tick")
        report_lines.append(f"Teljes időtartam: {stats['Duration_Hours']:.2f} óra")
        report_lines.append(f"Globális átlagsebesség: {stats['Global_Avg_Tick_Per_Sec']:.2f} Tick/Másodperc\n")

        report_lines.append("Ezek az adatok szolgálnak alapul az Adaptív Tick-Sűrűség Protokoll (ATDP) számára.")
        report_lines.append("Cél: A dinamikus HMM ablakméret (N) fizikai időhöz rögzítése a teljes nap folyamán.\n")

        report_lines.append(f"{'Időszak (Óra)':<20} | {'Órás Tick Szám':<18} | {'P50 Seb. (T/s)':<15} | {'P90 Seb. (T/s)':<15} | {'Javasolt N Ablak'}")
        report_lines.append("-" * 95)

        # Rendezzük időrendbe
        sorted_hours = sorted(stats['Hourly_Stats'].keys())

        for h in sorted_hours:
            h_data = stats['Hourly_Stats'][h]
            ticks = h_data['ticks']

            samples = h_data['speeds_sample']
            if samples:
                p50 = np.median(samples)
                p90 = np.percentile(samples, 90)
            else:
                p50 = 0
                p90 = 0

            # Javasolt Ablakméret egy 3 másodperces fókuszhoz (a P50 átlagos sebesség alapján)
            suggested_window = int(p50 * 3.0)
            # Capping based on our Inference Latency Scanner results (Safe up to 300)
            suggested_window = max(15, min(300, suggested_window))

            report_lines.append(f"{h:<20} | {ticks:<18,} | {p50:<15.1f} | {p90:<15.1f} | N = {suggested_window}")

        report_lines.append("\n[ATDP ARCHITEKTURÁLIS DÖNTÉS]")
        report_lines.append("A fenti táblázat P90 és P50 értékei alapján az online rendszernek egy olyan")
        report_lines.append("O(1) RingBuffert kell lefoglalnia, amely képes befogadni a legmagasabb")
        report_lines.append("javasolt N értéket, miközben alacsony volatilitásnál visszaskáláz N=15-re.")

        output_file = os.path.join(output_dir, f"DENSITY_HEATMAP_{file_name.replace('.csv', '')}.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(f"✅ Hőtérkép Riport Kimentve: {output_file}")


def run_profiler():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'reports_tmp')

    os.makedirs(output_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))

    # Ha nincs a data mappában, keressünk az analysis_input-ban is (VPS szerkezet miatt)
    if not csv_files:
        alt_dir = os.path.join(os.path.dirname(base_dir), 'analysis_input')
        csv_files = glob.glob(os.path.join(alt_dir, '*.csv'))

    # Szűrjük a már feldolgozott/címkézett fájlokat
    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning("Nem találtam elemezhető CSV fájlokat!")
        return

    logger.info(f"Megtalált fájlok száma: {len(csv_files)}. Gigantikus Chunkolt elemzés indítása...")

    # Memóriakímélő 100k soros chunkok
    profiler = TickDensityProfiler(chunksize=100000)

    for file in csv_files:
        stats = profiler.process_file_chunked(file, output_dir)
        if stats:
            profiler.generate_report(stats, output_dir)

if __name__ == '__main__':
    run_profiler()
