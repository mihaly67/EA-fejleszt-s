import os
import glob
import time
import pandas as pd
import numpy as np
import logging
from hmmlearn.hmm import GaussianHMM
from collections import deque

# Teljesítmény profilinghoz
import psutil

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class HMMLatencyScanner:
    """
    Stressz-Profilozó eszköz:
    Célja, hogy megmérje a GaussianHMM következtetési idejét (Inference Latency - Viterbi decoding)
    különböző $N$ ablakméretek (Window Sizes) esetén.
    Ezzel meghatározzuk a VPS maximális számítási kapacitását (Inference Bottleneck),
    hogy tudjuk, meddig emelhetjük az adaptív ablakméretet nappali HFT körülmények között.
    """

    def __init__(self):
        self.test_windows = [15, 30, 50, 100, 150, 200, 300]
        self.num_iterations = 50 # Hányszor futtassuk le ugyanazt az ablakot az átlagoláshoz

        # Egy dummy modell inicializálása, ami szerkezetében megegyezik a Vaku 3.0-val
        # (3 dimenziós megfigyelési tér: LogER, Spread, Tick Density Residual)
        self.n_components = 2
        self.model = GaussianHMM(n_components=self.n_components, covariance_type="diag", n_iter=10)

        # Előzetes betanítás random adattal, hogy a model() hívható legyen predict()-hez
        dummy_X = np.random.randn(100, 3)
        self.model.fit(dummy_X)

    def extract_test_data(self, df):
        """Kivon egy 3D jellemző mátrixot a nyers CSV-ből a szimulációhoz."""
        # A valóságban a LogER, NormSpread, TickResidual lenne,
        # de a következtetési idő szempontjából mindegy mi az adat, csak a dimenzió és hossz a fontos.

        if 'Ask' in df.columns and 'Bid' in df.columns:
            prices = (df['Ask'] + df['Bid']) / 2.0
            spread = df['Ask'] - df['Bid']
        elif 'Last' in df.columns:
            prices = df['Last']
            spread = np.zeros(len(df))
        else:
            # Fallback
            prices = df.iloc[:, 1] if len(df.columns) > 1 else np.random.randn(len(df))
            spread = np.zeros(len(df))

        # Dummy features: Returns, Spread, Volatility
        f1 = prices.diff().fillna(0).values
        f2 = spread.values
        f3 = prices.rolling(10).std().fillna(0).values

        X = np.column_stack((f1, f2, f3))
        # Skálázás dummy módon (a valóságban StandardScaler)
        X = (X - np.mean(X, axis=0)) / (np.std(X, axis=0) + 1e-8)
        return X

    def profile_latency(self, X):
        """Lefuttatja a Viterbi dekódolást különböző ablakméreteken és méri a CPU időt."""
        results = []
        total_data_len = len(X)

        for n in self.test_windows:
            if n > total_data_len:
                logger.warning(f"A fájl rövidebb ({total_data_len}), mint az N={n} ablak. Ezt kihagyjuk.")
                continue

            latencies_ms = []

            # Véletlenszerű indexek kiválasztása a fájlból, hogy ne mindig ugyanazt az adatot dekódolja
            start_indices = np.random.randint(0, total_data_len - n, size=self.num_iterations)

            for start_idx in start_indices:
                window_data = X[start_idx : start_idx + n]

                # ---- IDŐMÉRÉS KEZDETE ----
                t_start = time.perf_counter()

                # Viterbi dekódolás (predict)
                _ = self.model.predict(window_data)

                # ---- IDŐMÉRÉS VÉGE ----
                t_end = time.perf_counter()

                latency_ms = (t_end - t_start) * 1000.0
                latencies_ms.append(latency_ms)

            avg_latency = np.mean(latencies_ms)
            max_latency = np.max(latencies_ms)
            min_latency = np.min(latencies_ms)

            results.append({
                'Window_Size_N': n,
                'Avg_Latency_ms': avg_latency,
                'Max_Latency_ms': max_latency,
                'Min_Latency_ms': min_latency
            })

            logger.info(f"N={n:<3} | Átlag: {avg_latency:.2f} ms | Max: {max_latency:.2f} ms")

        return results

    def run_on_files(self, input_dir, output_dir):
        csv_files = glob.glob(os.path.join(input_dir, '*.csv'))
        # Keresés a teljes munkakönyvtárban, ha az ML_Ops/data üres
        if not csv_files:
            logger.info(f"Nem találtam CSV-t a {input_dir}-ben. Keresés alternatív könyvtárakban...")
            csv_files = glob.glob(os.path.join(os.path.dirname(os.path.dirname(input_dir)), 'analysis_input', '*.csv'))

        if not csv_files:
            logger.error("Nem találtam egyetlen tesztelhető CSV fájlt sem a stressz-profilozáshoz!")
            return

        # Csak 1-2 fájlt vizsgálunk, mert a hardveres idő számít, nem a fájl tartalma
        test_file = csv_files[0]
        file_name = os.path.basename(test_file)
        logger.info(f"🧪 Stressz-Profilozás indítása (HMM Inference Latency) ezen a fájlon: {file_name}")

        try:
            df = pd.read_csv(test_file)
            X = self.extract_test_data(df)

            # Warm-up (hogy az első futás Python overheadje ne torzítson)
            logger.info("Rendszer bemelegítése (Warm-up)...")
            self.model.predict(X[:50])

            # Profilozás
            logger.info(f"Számítási idő mérése iterációnként: {self.num_iterations}")
            results = self.profile_latency(X)

            self.generate_report(results, file_name, output_dir)

        except Exception as e:
            logger.error(f"Hiba a fájl feldolgozásakor: {e}")

    def generate_report(self, results, file_name, output_dir):
        report_lines = []
        report_lines.append("=========================================================================")
        report_lines.append("🔥 VAKU 3.0 BOTTLENECK TESZT: HMM INFERENCE LATENCY SCANNER")
        report_lines.append("=========================================================================\n")
        report_lines.append(f"Célfájl: {file_name}")
        report_lines.append(f"A teszt célja annak meghatározása, hogy a VPS (Ryzen 3) hardver")
        report_lines.append("meddig képes lineáris (vagy legalább elviselhető) időben kiszámolni")
        report_lines.append("a HMM Viterbi dekódolását, miközben az 'N' ablakméret növekszik.\n")

        report_lines.append("Kritikus határérték: ~50 ms (Efelett a HMM önmaga okoz piaci lemaradást)\n")

        report_lines.append(f"{'Ablakméret (N)':<15} | {'Átlagos Késés (ms)':<20} | {'Max Késés (ms)':<15}")
        report_lines.append("-" * 60)

        for r in results:
            avg = r['Avg_Latency_ms']
            max_ms = r['Max_Latency_ms']
            n = r['Window_Size_N']

            warning_flag = "⚠️ KRITIKUS!" if avg > 50.0 else "✅ OK"
            report_lines.append(f"{n:<15} | {avg:<20.2f} | {max_ms:<15.2f} {warning_flag}")

        report_lines.append("\n[KÖVETKEZTETÉS ÉS JAVASLAT]")

        # Javaslat megfogalmazása az adatok alapján
        safe_windows = [r['Window_Size_N'] for r in results if r['Avg_Latency_ms'] <= 50.0]
        if safe_windows:
            max_safe = max(safe_windows)
            report_lines.append(f"A jelenlegi hardveren a biztonságos maximális ablakméret: N = {max_safe}.")
            report_lines.append("Nappali HFT körülmények között (a Tick Sűrűség Profilozó adatai alapján)")
            report_lines.append("a dinamikus ablak méretét NEM SZABAD ezen érték fölé engedni.")
        else:
            report_lines.append("⚠️ FIGYELEM: Minden mért ablakméret meghaladja a megengedett 50ms-ot!")
            report_lines.append("A VPS erőforrásai végzetesen elégtelenek az online HMM futtatáshoz.")

        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, "HMM_INFERENCE_LATENCY_REPORT.txt")

        with open(output_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

        logger.info(f"✅ Riport mentve: {output_file}")


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(base_dir, 'data')
    output_dir = os.path.join(base_dir, 'reports_tmp')

    scanner = HMMLatencyScanner()
    scanner.run_on_files(input_dir, output_dir)

if __name__ == "__main__":
    main()
