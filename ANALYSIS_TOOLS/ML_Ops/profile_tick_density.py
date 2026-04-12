import os
import glob
import pandas as pd
import numpy as np
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class ScalpingDensityProfiler:
    """
    Kutatási Eszköz (Napszakok és Volatilitás Profilozására):
    A célja, hogy felmérje a különböző időpontokban exportált CSV fájlok
    'Tick Sűrűségét' és Brókeri Fagyásait (Tick Density, Latency, Burst Events).

    A script 'chunkolt' (memóriakímélő) módszerrel olvassa a fájlokat,
    és pontos 15-perces Skalpoló Felbontást készít mélystatisztikákkal.
    """

    def __init__(self, chunksize=250000):
        self.chunksize = chunksize

    def process_file_chunked(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"📊 Mély Skalpoló Statisztika (Density & Latency) indítása: {file_name}")

        # Kulcs: YYYY-MM-DD HH:MM, Érték: komplex statisztikai szótár
        hourly_stats = {}

        total_ticks_processed = 0
        last_time_msc = None
        global_min_msc = float('inf')
        global_max_msc = 0.0

        time_col = None
        spread_col = None

        try:
            first_chunk = next(pd.read_csv(file_path, chunksize=10))

            # Idő oszlop
            time_cols = [c for c in first_chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if not time_cols:
                logger.warning(f"Nem található milliszekundumos időbélyeg (TimeMsc) a {file_name} fájlban!")
                return None
            time_col = time_cols[0]

            # Keresünk spread vagy bid/ask oszlopokat, hogy a sűrűség-spread korrelációt nézzük
            usecols = [time_col]
            has_spread = False

            if 'Spread' in first_chunk.columns:
                spread_col = 'Spread'
                usecols.append(spread_col)
                has_spread = True
            elif 'Ask' in first_chunk.columns and 'Bid' in first_chunk.columns:
                usecols.extend(['Ask', 'Bid'])
                has_spread = True

            for chunk_idx, chunk in enumerate(pd.read_csv(file_path, chunksize=self.chunksize, usecols=usecols)):

                times_ms = chunk[time_col].astype(float)

                if times_ms.empty:
                    continue

                global_min_msc = min(global_min_msc, times_ms.min())
                global_max_msc = max(global_max_msc, times_ms.max())
                total_ticks_processed += len(chunk)

                # Spread kalkuláció ha nincs natív Spread oszlop
                if has_spread and 'Spread' not in chunk.columns:
                    chunk['Spread'] = chunk['Ask'] - chunk['Bid']
                    spread_col = 'Spread'

                if last_time_msc is not None:
                    times_with_prev = pd.concat([pd.Series([last_time_msc]), times_ms])
                    diffs_ms = times_with_prev.diff().dropna().values
                    valid_times = times_ms.values
                    if has_spread:
                        valid_spreads = chunk[spread_col].values
                else:
                    diffs_ms = times_ms.diff().dropna().values
                    valid_times = times_ms.values[1:]
                    if has_spread:
                        valid_spreads = chunk[spread_col].values[1:]

                last_time_msc = times_ms.iloc[-1]

                if len(diffs_ms) != len(valid_times):
                    continue

                valid_mask = diffs_ms > 0
                valid_diffs = diffs_ms[valid_mask]
                valid_times = valid_times[valid_mask]
                if has_spread:
                    valid_spreads = valid_spreads[valid_mask]

                if len(valid_diffs) > 0:
                    speeds = 1000.0 / valid_diffs # Tick/Sec

                    if global_min_msc > 1000000000000:
                        dt_series = pd.to_datetime(valid_times, unit='ms')
                        rounded_dt = dt_series.floor('15min')
                        interval_keys = rounded_dt.strftime('%Y-%m-%d %H:%M').values
                    else:
                        quarters_from_start = ((valid_times - global_min_msc) / (1000 * 60 * 15)).astype(int)
                        interval_keys = np.array([f"Q_{q:04d}" for q in quarters_from_start])

                    # DataFrame a chunk aggregálásához
                    data_dict = {
                        'Interval': interval_keys,
                        'Speed': speeds,
                        'IAT_ms': valid_diffs
                    }
                    if has_spread:
                        data_dict['Spread'] = valid_spreads

                    df_chunk = pd.DataFrame(data_dict)

                    for interval_key, group in df_chunk.groupby('Interval'):
                        if interval_key not in hourly_stats:
                            hourly_stats[interval_key] = {
                                "ticks": 0,
                                "speeds_sample": [],
                                "max_latency_ms": 0,
                                "freeze_count_2sec": 0, # Hányszor fagyott be a bróker feed 2mp-nél tovább
                                "burst_count_20tps": 0, # Hányszor volt 20 Tick/Sec feletti kitörés
                                "spread_in_burst": [] # Spread minták HFT burstök alatt
                            }

                        stat = hourly_stats[interval_key]
                        stat["ticks"] += len(group)

                        # Max Latency frissítése
                        local_max_iat = group['IAT_ms'].max()
                        if local_max_iat > stat["max_latency_ms"]:
                            stat["max_latency_ms"] = local_max_iat

                        # Fagyások és Kitörések számolása
                        stat["freeze_count_2sec"] += (group['IAT_ms'] > 2000).sum()

                        burst_mask = group['Speed'] > 20.0
                        stat["burst_count_20tps"] += burst_mask.sum()

                        # Spread minta gyűjtése a burstök alatt (ha van)
                        if has_spread and burst_mask.any():
                            stat["spread_in_burst"].extend(group.loc[burst_mask, 'Spread'].head(50).tolist())

                        sample_size = min(len(group), 1000)
                        if sample_size > 0:
                            sampled = np.random.choice(group['Speed'].values, sample_size, replace=False)
                            stat["speeds_sample"].extend(sampled.tolist())

                if chunk_idx % 5 == 0:
                    logger.info(f"  ... {total_ticks_processed:,} tick feldolgozva a memóriában.")

        except Exception as e:
            logger.error(f"Hiba a fájl chunkolt beolvasásakor: {e}")
            return None

        if total_ticks_processed == 0:
            return None

        total_time_sec = (global_max_msc - global_min_msc) / 1000.0
        global_avg_speed = total_ticks_processed / total_time_sec if total_time_sec > 0 else 0

        logger.info(f"✅ Skalpoló elemzés kész! Összes tick: {total_ticks_processed:,}, Futtatási idő: {total_time_sec/3600:.1f} óra.")

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
        report_lines.append("=========================================================================================")
        report_lines.append("🔥 VAKU 3.0: MÉLY DIAGNOSZTIKAI SKALPOLÓ RIJPORT (TICK SŰRŰSÉG & BRÓKERI FAGYÁSOK)")
        report_lines.append("=========================================================================================\n")
        report_lines.append(f"Fájl: {file_name}")
        report_lines.append(f"Feldolgozott adat: {stats['Total_Ticks']:,} tick")
        report_lines.append(f"Teljes időtartam: {stats['Duration_Hours']:.2f} óra")
        report_lines.append(f"Globális átlagsebesség: {stats['Global_Avg_Tick_Per_Sec']:.2f} Tick/Másodperc\n")

        report_lines.append("Ez a jelentés 15-perces ('Skalpoló') időszeletekben tárja fel a bróker feed anomáliáit,")
        report_lines.append("beleértve a HFT kitöréseket (>20 Tick/s), a latency fagyásokat (>2s szünet), és a sűrűség-spread kapcsolatot.\n")

        header = (f"{'Időszak (15-Perc)':<18} | {'Tickek':<8} | {'P50(T/s)':<8} | {'P90(T/s)':<8} | "
                  f"{'Max Fagyás(s)':<13} | {'>2s Fagyások':<12} | {'HFT Burst(>20T/s)':<18} | {'Javasolt N'}")
        report_lines.append(header)
        report_lines.append("-" * len(header))

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

            max_freeze_sec = h_data['max_latency_ms'] / 1000.0
            freezes = h_data['freeze_count_2sec']
            bursts = h_data['burst_count_20tps']

            # Dinamikus ablak logikája P90 alapján
            suggested_window = int(p90 * 3.0)
            suggested_window = max(15, min(300, suggested_window))

            # Színezés/Kiemelés a riportban
            freeze_str = f"{max_freeze_sec:.1f}"
            if max_freeze_sec > 5.0:
                freeze_str += " ⚠️"

            burst_str = str(bursts)
            if bursts > 100:
                burst_str += " 🔥"

            line = (f"{h:<18} | {ticks:<8,} | {p50:<8.1f} | {p90:<8.1f} | "
                    f"{freeze_str:<13} | {freezes:<12} | {burst_str:<18} | N={suggested_window}")
            report_lines.append(line)

        report_lines.append("\n[ATDP ARCHITEKTURÁLIS DIAGNÓZIS]")
        report_lines.append("1. Fagyások (Freezes): Ha a 'Max Fagyás' tartósan magas, a bróker feedje instabil vagy manipulált (Latency Hold).")
        report_lines.append("   Ezekben a 15 perces szakaszokban a CUSUM indikátorunk fogja biztosítani a manipuláció detektálását, nem a HMM.")
        report_lines.append("2. HFT Kitörések (Bursts): Ha egy időszakban sok a HFT Burst, az ATDP dinamikusan kitágítja a RingBuffert (N növelése),")
        report_lines.append("   hogy a HMM ne legyen 'vaksi' az extrém rángatásokra.")

        output_file = os.path.join(output_dir, f"SCALPING_DIAGNOSTIC_{file_name.replace('.csv', '')}.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(f"✅ Diagnosztikai Riport Kimentve: {output_file}")


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

    logger.info(f"Megtalált fájlok száma: {len(csv_files)}. Mély Skalpoló Diagnosztika indítása...")

    profiler = ScalpingDensityProfiler(chunksize=250000)

    for file in csv_files:
        stats = profiler.process_file_chunked(file, output_dir)
        if stats:
            profiler.generate_report(stats, output_dir)

if __name__ == '__main__':
    run_profiler()
