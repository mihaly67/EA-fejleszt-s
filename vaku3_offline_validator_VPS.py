import os
import glob
import pandas as pd
import numpy as np
import logging
from collections import deque

try:
    from hmmlearn import hmm
    HMMLEARN_INSTALLED = True
except ImportError:
    HMMLEARN_INSTALLED = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class NumpyRingBuffer:
    """O(1) sebességű Sliding Window a memóriakímélő 2. mag (Feature Engineering) számára."""
    def __init__(self, capacity, dtype=float):
        self.capacity = capacity
        self.buffer = np.zeros(capacity, dtype=dtype)
        self.index = 0
        self.is_full = False

    def append(self, value):
        self.buffer[self.index] = value
        self.index += 1
        if self.index == self.capacity:
            self.index = 0
            self.is_full = True

    def get_data(self):
        if not self.is_full:
            return self.buffer[:self.index]
        return np.concatenate((self.buffer[self.index:], self.buffer[:self.index]))

class Vaku3OfflineValidator:
    """
    A 'Smoking Gun' Bizonyíték Kályhája: Összeköti a Vaku 3.0 (HMM, CUSUM IAT, ER)
    állapotfelmérését a tegnapi (label_broker_reaction.py) Célváltozókkal (TARGET=1).
    """
    def __init__(self, window_size=15):
        self.window_size = window_size
        self.price_buffer = NumpyRingBuffer(window_size)
        self.spread_buffer = NumpyRingBuffer(window_size)
        self.time_buffer = NumpyRingBuffer(window_size)

        self.observation_space = []

        if HMMLEARN_INSTALLED:
            self.model = hmm.GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42, init_params="")
        else:
            self.model = None

        self.is_fitted = False
        self.state_map = {"Calm": 0, "ImpulsiveUp": 1, "ImpulsiveDown": 2}

    def extract_features(self, df):
        """A CSV bejárása (Generator-like loop) a 3D ortogonális vektor felépítéséhez."""
        logger.info(f"O(1) Vektorizált Feature Extraction indítása a {len(df)} ticken...")

        features = []
        for i in range(len(df)):
            bid = df.loc[i, 'Bid'] if 'Bid' in df.columns else df.iloc[i, 1]
            spread = df.loc[i, 'Spread'] if 'Spread' in df.columns else 1.0

            # Find time column
            t_col = next((c for c in df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc']), None)
            t_ms = df.loc[i, t_col] if t_col else i * 100.0

            self.price_buffer.append(bid)
            self.spread_buffer.append(spread)
            self.time_buffer.append(t_ms)

            if i >= self.window_size:
                prices = self.price_buffer.get_data()
                spreads = self.spread_buffer.get_data()
                times = self.time_buffer.get_data()

                # 1. Log Return proxy
                net_change = prices[-1] - prices[0]
                gross_move = np.sum(np.abs(np.diff(prices)))
                log_return = net_change / gross_move if gross_move > 0 else 0.0

                # 2. Spread Elasticity
                avg_spread = np.mean(spreads)

                # 3. Tick Density
                time_diff = max(1.0, times[-1] - times[0])
                tick_density = len(times) / (time_diff / 1000.0)

                features.append([log_return, avg_spread, tick_density])
            else:
                features.append([0.0, 0.0, 0.0])

        self.observation_space = np.array(features)
        logger.info(f"Feature matrix kész: {self.observation_space.shape}")

    def fit_and_map_states(self):
        """HMM betanítása és a Semantic Mapping."""
        if not HMMLEARN_INSTALLED or len(self.observation_space) < 100:
            logger.warning("Nincs elég adat a HMM betanításához vagy nincs hmmlearn telepítve!")
            return

        logger.info("Vaku 3.0 (GaussianHMM) betanítása...")
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            self.model.fit(self.observation_space)

        self.is_fitted = True

        means = self.model.means_
        er_idx = 0

        er_means = means[:, er_idx]

        # Calm state has the lowest absolute ER (prices going nowhere)
        calm_state = int(np.argmin(np.abs(er_means)))

        remaining_states = list(set([0, 1, 2]) - {calm_state})

        if len(remaining_states) == 2:
            if er_means[remaining_states[0]] > er_means[remaining_states[1]]:
                impulsive_up_state = int(remaining_states[0])
                impulsive_down_state = int(remaining_states[1])
            else:
                impulsive_up_state = int(remaining_states[1])
                impulsive_down_state = int(remaining_states[0])
        else:
            impulsive_up_state = 1
            impulsive_down_state = 2

        self.state_map = {
            "Calm": calm_state,
            "ImpulsiveUp": impulsive_up_state,
            "ImpulsiveDown": impulsive_down_state
        }
        logger.info(f"Szemantikus térképezés kész: {self.state_map}")

    def run_smoking_gun_validation(self, df):
        """Offline validációs riport a 3 állapottal."""
        report_lines = []
        report_lines.append("=========================================================================")
        report_lines.append("🔍 VAKU 3.0 OFFLINE VALIDÁTOR (HMM) RIPORT")
        report_lines.append("=========================================================================\n")

        if not self.is_fitted:
            self.fit_and_map_states()

        if not self.is_fitted:
             return df, ["HMM nem lett betanítva."]

        report_lines.append(f"Felismerési térkép: {self.state_map}\n")

        logger.info("HMM Állapotok visszafejtése a teljes adatsoron (Viterbi dekódolás)...")
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            hidden_states = self.model.predict(self.observation_space)

        df['Vaku3_HMM_State'] = hidden_states

        state_names = {v: k for k, v in self.state_map.items()}
        df['Vaku3_State_Name'] = df['Vaku3_HMM_State'].map(state_names)

        if 'Broker_Reaction_Target' not in df.columns:
            logger.warning("A fájl nincs felcímkézve! Futtasd a label_broker_reaction.py-t először!")
            return df, report_lines

        manipulated_entries = df[df['Broker_Reaction_Target'] == 1].index.tolist()
        total_manipulations = len(manipulated_entries)

        if total_manipulations == 0:
            logger.warning("Nincs Target=1 esemény a fájlban. A validáció skippelve.")
            return df, report_lines

        state_hits = {0: 0, 1: 0, 2: 0, np.nan: 0}

        for idx in manipulated_entries:
            hmm_state_at_trade = df.loc[idx, 'Vaku3_HMM_State']
            state_hits[hmm_state_at_trade] += 1

        report_lines.append("--- SMOKING GUN BIZONYÍTÉK (Offline Causal Validation) ---")
        report_lines.append(f"Összes megjelölt Brókeri Reakció (Target=1): {total_manipulations} db")

        for state_id, hits in state_hits.items():
            hit_rate = (hits / total_manipulations) * 100
            state_name = state_names.get(state_id, "Unknown")
            is_calm = " <--- (Veszélyes 'Calm' / Oldalazó állapot)" if state_name == "Calm" else ""

            line = f"  -> {state_name} (Állapot ID: {state_id}) találati aránya a trükkök előtt: {hits} db ({hit_rate:.1f}%){is_calm}"
            report_lines.append(line)

        return df, report_lines

def run_validator():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    labeled_dir = os.path.join(base_dir, 'data', 'labeled')

    csv_files = glob.glob(os.path.join(labeled_dir, 'LABELED_*.csv'))

    if not csv_files:
        logger.warning(f"Nincsenek LABELED_ fájlok a {labeled_dir} mappában! Futtasd a címkézőt!")
        return

    for file in csv_files:
        file_name = os.path.basename(file)
        logger.info(f"\n[VAKU 3.0] Offline Kályha Validáció indítása: {file_name}")

        df = pd.read_csv(file)
        validator = Vaku3OfflineValidator(window_size=15)

        validator.extract_features(df)
        df_validated, report_lines = validator.run_smoking_gun_validation(df)

        output_file = os.path.join(labeled_dir, f"VAKU3_VALIDATED_{file_name}")
        df_validated.to_csv(output_file, index=False)

        report_dir = os.path.join(base_dir, 'reports_tmp')
        os.makedirs(report_dir, exist_ok=True)
        report_file = os.path.join(report_dir, f"VAKU3_REPORT_{file_name.replace('.csv', '')}.txt")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write("\n".join(report_lines))

if __name__ == '__main__':
    run_validator()
