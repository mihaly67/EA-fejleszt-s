import os
import glob
import pandas as pd
import numpy as np
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class MRI_DensityProfiler:
    """
    MRI-Szintű Skalpoló Diagnosztika (5-perces alap + 1-perces Deep Dive).
    Célja, hogy a "brókeri fojtásokat" (Throttle), a makro hír alatti kitöréseket (Bursts),
    és a fagyásokat (Freezes) tűpontosan térképezze fel.
    """

    def __init__(self, chunksize=250000):
        self.chunksize = chunksize

    def process_file_chunked(self, file_path, output_dir):
        file_name = os.path.basename(file_path)
        logger.info(f"📊 MRI Diagnosztika (5m + 1m Zoom) indítása: {file_name}")

        # Kulcs: YYYY-MM-DD HH:MM (5 perces kerekítéssel)
        # Értéke: Stat dict, amely tartalmaz egy '1m_sub_stats' dictet is
        mri_stats = {}

        total_ticks_processed = 0
        last_time_msc = None
        global_min_msc = float('inf')
        global_max_msc = 0.0

        try:
            first_chunk = next(pd.read_csv(file_path, chunksize=10))

            time_cols = [c for c in first_chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']]
            if not time_cols:
                logger.warning(f"Nem található milliszekundumos időbélyeg (TimeMsc) a {file_name} fájlban!")
                return None
            time_col = time_cols[0]

            usecols = [time_col]
            has_spread = False

            if 'Spread' in first_chunk.columns:
                usecols.append('Spread')
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

                if has_spread and 'Spread' not in chunk.columns:
                    chunk['Spread'] = chunk['Ask'] - chunk['Bid']

                if last_time_msc is not None:
                    times_with_prev = pd.concat([pd.Series([last_time_msc]), times_ms])
                    diffs_ms = times_with_prev.diff().dropna().values
                    valid_times = times_ms.values
                    if has_spread:
                        valid_spreads = chunk['Spread'].values
                else:
                    diffs_ms = times_ms.diff().dropna().values
                    valid_times = times_ms.values[1:]
                    if has_spread:
                        valid_spreads = chunk['Spread'].values[1:]

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
                        # EET (IC Markets GMT+2/3) -> CET (Magyar idő) korrekció (-1 óra)
                        # A nyers unix milliszekundumból kivonunk 1 órát (3,600,000 ms)
                        cet_times_ms = valid_times - 3600000.0
                        dt_series = pd.to_datetime(cet_times_ms, unit='ms')

                        # 5 perces kulcsok az alap nézethez
                        keys_5m = dt_series.floor('5min').strftime('%Y-%m-%d %H:%M').values
                        # 1 perces kulcsok a zoomhoz
                        keys_1m = dt_series.floor('1min').strftime('%Y-%m-%d %H:%M').values
                    else:
                        minutes_from_start = ((valid_times - global_min_msc) / (1000 * 60)).astype(int)
                        # 5 perces blokk = minutes // 5 * 5
                        m5_from_start = (minutes_from_start // 5) * 5
                        keys_5m = np.array([f"M5_{m:05d}" for m in m5_from_start])
                        keys_1m = np.array([f"M1_{m:05d}" for m in minutes_from_start])

                    data_dict = {
                        'Interval_5m': keys_5m,
                        'Interval_1m': keys_1m,
                        'Speed': speeds,
                        'IAT_ms': valid_diffs
                    }
                    if has_spread:
                        data_dict['Spread'] = valid_spreads

                    df_chunk = pd.DataFrame(data_dict)

                    # Először 5-perces csoportosítás
                    for interval_5m, group_5m in df_chunk.groupby('Interval_5m'):
                        if interval_5m not in mri_stats:
                            mri_stats[interval_5m] = {
                                "ticks": 0, "speeds_sample": [], "max_latency_ms": 0,
                                "freeze_count_2sec": 0, "burst_count_20tps": 0, "1m_sub_stats": {}
                            }

                        stat_5m = mri_stats[interval_5m]
                        stat_5m["ticks"] += len(group_5m)

                        local_max_iat = group_5m['IAT_ms'].max()
                        if local_max_iat > stat_5m["max_latency_ms"]: stat_5m["max_latency_ms"] = local_max_iat

                        stat_5m["freeze_count_2sec"] += (group_5m['IAT_ms'] > 2000).sum()
                        stat_5m["burst_count_20tps"] += (group_5m['Speed'] > 20.0).sum()

                        sample_size = min(len(group_5m), 500)
                        if sample_size > 0:
                            sampled = np.random.choice(group_5m['Speed'].values, sample_size, replace=False)
                            stat_5m["speeds_sample"].extend(sampled.tolist())

                        # --- DEEP DIVE (1-Perces aggregáció ezen az 5 percen belül) ---
                        for interval_1m, group_1m in group_5m.groupby('Interval_1m'):
                            sub_stats = stat_5m["1m_sub_stats"]
                            if interval_1m not in sub_stats:
                                sub_stats[interval_1m] = {
                                    "ticks": 0, "speeds_sample": [], "max_latency_ms": 0,
                                    "freeze_count_2sec": 0, "burst_count_20tps": 0
                                }

                            s1m = sub_stats[interval_1m]
                            s1m["ticks"] += len(group_1m)

                            local_max_1m = group_1m['IAT_ms'].max()
                            if local_max_1m > s1m["max_latency_ms"]: s1m["max_latency_ms"] = local_max_1m

                            s1m["freeze_count_2sec"] += (group_1m['IAT_ms'] > 2000).sum()
                            s1m["burst_count_20tps"] += (group_1m['Speed'] > 20.0).sum()

                            # Mintavétel az 1 percesből
                            s1 = min(len(group_1m), 100)
                            if s1 > 0:
                                s_spl = np.random.choice(group_1m['Speed'].values, s1, replace=False)
                                s1m["speeds_sample"].extend(s_spl.tolist())

                if chunk_idx % 5 == 0:
                    logger.info(f"  ... {total_ticks_processed:,} tick feldolgozva a memóriában.")

        except Exception as e:
            logger.error(f"Hiba a fájl chunkolt beolvasásakor: {e}")
            return None

        if total_ticks_processed == 0:
            return None

        total_time_sec = (global_max_msc - global_min_msc) / 1000.0
        return {
            "File": file_name, "Total_Ticks": total_ticks_processed, "Duration_Hours": total_time_sec / 3600.0,
            "Global_Avg": total_ticks_processed / total_time_sec if total_time_sec > 0 else 0, "MRI_Stats": mri_stats
        }

    def generate_report(self, stats, output_dir):
        if not stats: return

        file_name = stats['File']
        report_lines = []
        report_lines.append("=========================================================================================")
        report_lines.append("🔍 VAKU 3.0: MRI SKALPOLÓ DIAGNOSZTIKA (5m ALAP + 1m DEEP DIVE)")
        report_lines.append("=========================================================================================\n")
        report_lines.append(f"Fájl: {file_name}")
        report_lines.append(f"Feldolgozott adat: {stats['Total_Ticks']:,} tick | Időtartam: {stats['Duration_Hours']:.2f} óra\n")

        report_lines.append("SZABÁLY: A rendszer 5 perces időszeleteket listáz ki. Ha egy 5 perces szakaszban anomália")
        report_lines.append("történik (Fagyás > 5s VAGY Bármilyen HFT Burst), az algoritmus rázoomol (Deep Dive),")
        report_lines.append("és alatta 1-perces felbontásban is kilistázza a kritikus esemény pontos helyét.")
        report_lines.append("IDŐZÓNA: EET (IC Markets) szerveridő -1 óra korrekcióval Magyar Időre (CET) konvertálva!\n")

        header = (f"{'Időszak':<18} | {'Tickek':<8} | {'P50(T/s)':<8} | {'P90(T/s)':<8} | "
                  f"{'Max Fagyás(s)':<13} | {'>2s Fagyások':<12} | {'HFT Burst(>20T)':<18}")
        report_lines.append(header)
        report_lines.append("-" * len(header))

        sorted_5m = sorted(stats['MRI_Stats'].keys())

        for h in sorted_5m:
            s5m = stats['MRI_Stats'][h]
            ticks = s5m['ticks']

            p50 = np.median(s5m['speeds_sample']) if s5m['speeds_sample'] else 0
            p90 = np.percentile(s5m['speeds_sample'], 90) if s5m['speeds_sample'] else 0
            max_frz = s5m['max_latency_ms'] / 1000.0
            frz_cnt = s5m['freeze_count_2sec']
            bursts = s5m['burst_count_20tps']

            # Formázás 5m-re
            frz_str = f"{max_frz:.1f}"
            if max_frz > 5.0: frz_str += " ⚠️"
            brst_str = str(bursts)
            if bursts > 0: brst_str += " 🔥"

            # Kritikus Blokkok Szűrése:
            # Csak akkor printelünk, ha volt legalább némi aktivitás (nem teljesen döglött éjszaka nulla tickkel)
            # ÉS ha anomália van. Ha minden rendben, és alacsony a volatilitás, csak az alap nézet megy ki.
            line = f"{h:<18} | {ticks:<8,} | {p50:<8.1f} | {p90:<8.1f} | {frz_str:<13} | {frz_cnt:<12} | {brst_str:<18}"

            is_anomaly = (max_frz > 5.0) or (bursts > 0)

            report_lines.append(line)

            # Ha anomália van, nyomunk egy Deep Dive-ot (Zoom) az alatta lévő 1 percekbe!
            if is_anomaly:
                sorted_1m = sorted(s5m['1m_sub_stats'].keys())
                for m in sorted_1m:
                    s1m = s5m['1m_sub_stats'][m]
                    if s1m['ticks'] == 0: continue

                    m_p50 = np.median(s1m['speeds_sample']) if s1m['speeds_sample'] else 0
                    m_p90 = np.percentile(s1m['speeds_sample'], 90) if s1m['speeds_sample'] else 0
                    m_max_frz = s1m['max_latency_ms'] / 1000.0
                    m_frz_cnt = s1m['freeze_count_2sec']
                    m_bursts = s1m['burst_count_20tps']

                    # Csak a releváns (ahol anomália vagy aktivitás volt) 1-perceseket printeljük
                    if m_max_frz > 2.0 or m_bursts > 0 or s1m['ticks'] > 100:
                        m_frz_str = f"{m_max_frz:.1f}"
                        if m_max_frz > 5.0: m_frz_str += " ⚠️"
                        m_brst_str = str(m_bursts)
                        if m_bursts > 0: m_brst_str += " 🔥"

                        m_line = f"  ↳ {m:<14} | {s1m['ticks']:<8,} | {m_p50:<8.1f} | {m_p90:<8.1f} | {m_frz_str:<13} | {m_frz_cnt:<12} | {m_brst_str:<18}"
                        report_lines.append(m_line)

        output_file = os.path.join(output_dir, f"MRI_DIAGNOSTIC_{file_name.replace('.csv', '')}.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(f"✅ MRI Riport Kimentve: {output_file}")


def run_profiler():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'reports_tmp')

    os.makedirs(output_dir, exist_ok=True)
    csv_files = glob.glob(os.path.join(input_dir, '*.csv'))

    if not csv_files:
        csv_files = glob.glob(os.path.join(os.path.dirname(base_dir), 'analysis_input', '*.csv'))

    csv_files = [f for f in csv_files if "ANALYZED" not in os.path.basename(f) and "LABELED" not in os.path.basename(f)]

    if not csv_files:
        return

    profiler = MRI_DensityProfiler(chunksize=250000)

    for file in csv_files:
        stats = profiler.process_file_chunked(file, output_dir)
        if stats:
            profiler.generate_report(stats, output_dir)

if __name__ == '__main__':
    run_profiler()
