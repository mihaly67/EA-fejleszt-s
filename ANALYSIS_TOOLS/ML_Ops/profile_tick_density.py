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

    A script 'chunkolt' (memóriakímélő) módszerrel olvassa a fájlokat,
    de az időbélyegek alapján szigorú és pontos ÓRÁNKÉNTI felbontást készít.
    """

    def __init__(self, chunksize=250000):
        self.chunksize = chunksize

    def process_file_chunked(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"📊 Pontos Órás Tick Sűrűség Profilozása indítása: {file_name}")

        hourly_stats = {} # Kulcs: YYYY-MM-DD HH:00, Érték: {ticks, speeds_sample}

        total_ticks_processed = 0
        last_time_msc = None
        global_min_msc = float('inf')
        global_max_msc = 0.0

        time_col = None

        try:
            # Az első chunk alapján határozzuk meg a time_col-t
            first_chunk = next(pd.read_csv(file_path, chunksize=10))
            time_cols = [c for c in first_chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if not time_cols:
                logger.warning(f"Nem található milliszekundumos időbélyeg (TimeMsc) a {file_name} fájlban!")
                return None
            time_col = time_cols[0]

            usecols = [time_col]

            for chunk_idx, chunk in enumerate(pd.read_csv(file_path, chunksize=self.chunksize, usecols=usecols)):

                times_ms = chunk[time_col].astype(float)

                if times_ms.empty:
                    continue

                global_min_msc = min(global_min_msc, times_ms.min())
                global_max_msc = max(global_max_msc, times_ms.max())
                total_ticks_processed += len(chunk)

                # Inter-arrival times számítása
                if last_time_msc is not None:
                    # Ha volt előző chunk, a diff hossza egyezni fog a times_ms hosszával, mert hozzáadjuk a last_time_msc-t az elejére
                    times_with_prev = pd.concat([pd.Series([last_time_msc]), times_ms])
                    diffs_ms = times_with_prev.diff().dropna().values
                    valid_times = times_ms.values
                else:
                    # Ha ez az első chunk, a diff az első elemnél NaN lesz, amit a dropna() kidob
                    diffs_ms = times_ms.diff().dropna().values
                    valid_times = times_ms.values[1:] # Az első elemhez nincs diff

                last_time_msc = times_ms.iloc[-1]

                # Biztosítjuk, hogy a diffs_ms és a valid_times ugyanolyan hosszúak
                if len(diffs_ms) != len(valid_times):
                    logger.warning(f"Dimenzió hiba a chunkban: diffs({len(diffs_ms)}) != times({len(valid_times)})")
                    continue

                valid_mask = diffs_ms > 0
                valid_diffs = diffs_ms[valid_mask]
                valid_times = valid_times[valid_mask]

                if len(valid_diffs) > 0:
                    speeds = 1000.0 / valid_diffs

                    # --- PONTOS 15-PERCES BONTÁS A CHUNKON BELÜL ---
                    if global_min_msc > 1000000000000: # 2001 utáni dátum MS-ban
                        dt_series = pd.to_datetime(valid_times, unit='ms')
                        # A 15 perces kerekítés trükkje: a perceket leosztjuk 15-tel, majd visszaszorozzuk
                        # Ezzel kapjuk meg a :00, :15, :30, :45 időablakokat
                        rounded_dt = dt_series.floor('15min')
                        hour_keys = rounded_dt.strftime('%Y-%m-%d %H:%M').values
                    else:
                        # Ha relatív idő, akkor negyedórákban (15 perc = 900,000 ms) számolunk
                        quarters_from_start = ((valid_times - global_min_msc) / (1000 * 60 * 15)).astype(int)
                        hour_keys = np.array([f"Q_{q:04d}" for q in quarters_from_start])

                    df_chunk_speeds = pd.DataFrame({'Interval': hour_keys, 'Speed': speeds})

                    for interval_key, group in df_chunk_speeds.groupby('Interval'):
                        if interval_key not in hourly_stats:
                            hourly_stats[interval_key] = {
                                "ticks": 0,
                                "speeds_sample": []
                            }

                        hourly_stats[interval_key]["ticks"] += len(group)

                        sample_size = min(len(group), 1000)
                        if sample_size > 0:
                            sampled = np.random.choice(group['Speed'].values, sample_size, replace=False)
                            hourly_stats[interval_key]["speeds_sample"].extend(sampled.tolist())

                if chunk_idx % 5 == 0:
                    logger.info(f"  ... {total_ticks_processed:,} tick feldolgozva a memóriában.")

        except Exception as e:
            logger.error(f"Hiba a fájl chunkolt beolvasásakor: {e}")
            return None

        if total_ticks_processed == 0:
            return None

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
        report_lines.append("🔥 VAKU 3.0: 24/48-ÓRÁS PONTOSÍTOTT TICK SŰRŰSÉG HŐTÉRKÉP (15-PERCES SKALPOLÓ NÉZET)")
        report_lines.append("=========================================================================\n")
        report_lines.append(f"Fájl: {file_name}")
        report_lines.append(f"Feldolgozott adat: {stats['Total_Ticks']:,} tick")
        report_lines.append(f"Teljes időtartam: {stats['Duration_Hours']:.2f} óra")
        report_lines.append(f"Globális átlagsebesség: {stats['Global_Avg_Tick_Per_Sec']:.2f} Tick/Másodperc\n")

        report_lines.append(f"{'Időszak (15-Perc)':<20} | {'Időszaki Tick Szám':<18} | {'P50 Seb. (T/s)':<15} | {'P90 Seb. (T/s)':<15} | {'Javasolt N Ablak'}")
        report_lines.append("-" * 95)

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

            suggested_window = int(p50 * 3.0)
            suggested_window = max(15, min(300, suggested_window))

            report_lines.append(f"{h:<20} | {ticks:<18,} | {p50:<15.1f} | {p90:<15.1f} | N = {suggested_window}")

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

    if not csv_files:
        alt_dir = os.path.join(os.path.dirname(base_dir), 'analysis_input')
        csv_files = glob.glob(os.path.join(alt_dir, '*.csv'))

    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        logger.warning("Nem találtam elemezhető CSV fájlokat!")
        return

    logger.info(f"Megtalált fájlok száma: {len(csv_files)}. Gigantikus Chunkolt elemzés indítása...")

    profiler = TickDensityProfiler(chunksize=250000)

    for file in csv_files:
        stats = profiler.process_file_chunked(file, output_dir)
        if stats:
            profiler.generate_report(stats, output_dir)

if __name__ == '__main__':
    run_profiler()
