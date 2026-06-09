from hmmlearn.hmm import GaussianHMM
import numpy as np
import warnings
from sklearn.preprocessing import StandardScaler
import logging

warnings.filterwarnings('ignore')
logging.getLogger('hmmlearn').setLevel(logging.CRITICAL)

class HMMCoreEngine:
    def __init__(self):
        self.hmm_m5 = GaussianHMM(n_components=2, covariance_type='full', n_iter=100, random_state=42)
        self.hmm_m1 = GaussianHMM(n_components=3, covariance_type='full', n_iter=100, random_state=42)
        self.hmm_s5 = GaussianHMM(n_components=3, covariance_type='full', n_iter=100, random_state=42)

        self.window_m5 = []
        self.window_m1 = []
        self.window_s5 = []

        self.max_window_m5 = 200
        self.max_window_m1 = 120
        self.max_window_s5 = 60

        self.scaler_m5 = StandardScaler()
        self.scaler_m1 = StandardScaler()
        self.scaler_s5 = StandardScaler()

        self.last_m1_time = None
        self.last_m5_time = None

        self.last_m1_state, self.last_m1_probs = None, None
        self.last_m5_state, self.last_m5_probs = None, None

        # Mapped states (0=Sideways/Noise, 1=Bullish, -1=Bearish)
        self.mapped_m1_state = None
        self.mapped_m5_state = None

    def map_states(self, hmm_model, num_states):
        # Maps the random HMM states to logical market conditions based on the mean of the LogReturns (feature 0)
        means = hmm_model.means_[:, 0]

        if num_states == 2:
            # 2 states: Assume the one with higher absolute return/volatility is 'Trending' (1), lower is 'Ranging' (0)
            # Simplification: we map based on variance if means are close, but here let's just do a basic separation
            # For this simple demo, we will just use 0=ranging, 1=trending based on means amplitude
            idx = np.argsort(np.abs(means))
            mapping = {idx[0]: 0, idx[1]: 1} # 0 is ranging, 1 is trending
            return mapping

        elif num_states == 3:
            # 3 states: lowest mean = Bearish (-1), middle = Ranging (0), highest = Bullish (1)
            idx = np.argsort(means)
            mapping = {idx[0]: -1, idx[1]: 0, idx[2]: 1}
            return mapping

        return {}

    def process_tick(self, s5_row, m1_time, m1_row, m5_time, m5_row):
        s5_state, s5_probs = None, None
        mapped_s5_state = None

        if s5_row is not None:
            features_s5 = [s5_row['LogReturn'], s5_row['ATR_Proxy']]
            self.window_s5.append(features_s5)
            if len(self.window_s5) > self.max_window_s5:
                self.window_s5.pop(0)

            if len(self.window_s5) >= 30:
                X_s5 = np.array(self.window_s5)
                if np.std(X_s5) > 0:
                    X_s5_scaled = self.scaler_s5.fit_transform(X_s5)
                    try:
                        self.hmm_s5.fit(X_s5_scaled)
                        raw_state = self.hmm_s5.predict(X_s5_scaled)[-1]
                        s5_probs = self.hmm_s5.predict_proba(X_s5_scaled)[-1]
                        mapping = self.map_states(self.hmm_s5, 3)
                        mapped_s5_state = mapping.get(raw_state, 0)
                    except Exception:
                        pass

        # M1 számítás
        if m1_row is not None and m1_time != self.last_m1_time:
            self.last_m1_time = m1_time
            features_m1 = [m1_row['LogReturn'], m1_row['ATR_Proxy']]
            self.window_m1.append(features_m1)
            if len(self.window_m1) > self.max_window_m1:
                self.window_m1.pop(0)

            if len(self.window_m1) >= 30:
                X_m1 = np.array(self.window_m1)
                if np.std(X_m1) > 0:
                    X_m1_scaled = self.scaler_m1.fit_transform(X_m1)
                    try:
                        self.hmm_m1.fit(X_m1_scaled)
                        raw_state = self.hmm_m1.predict(X_m1_scaled)[-1]
                        self.last_m1_probs = self.hmm_m1.predict_proba(X_m1_scaled)[-1]
                        mapping = self.map_states(self.hmm_m1, 3)
                        self.mapped_m1_state = mapping.get(raw_state, 0)
                    except Exception:
                        pass

        # M5 számítás
        if m5_row is not None and m5_time != self.last_m5_time:
            self.last_m5_time = m5_time
            features_m5 = [m5_row['LogReturn'], m5_row['ATR_Proxy']]
            self.window_m5.append(features_m5)
            if len(self.window_m5) > self.max_window_m5:
                self.window_m5.pop(0)

            if len(self.window_m5) >= 30:
                X_m5 = np.array(self.window_m5)
                if np.std(X_m5) > 0:
                    X_m5_scaled = self.scaler_m5.fit_transform(X_m5)
                    try:
                        self.hmm_m5.fit(X_m5_scaled)
                        raw_state = self.hmm_m5.predict(X_m5_scaled)[-1]
                        self.last_m5_probs = self.hmm_m5.predict_proba(X_m5_scaled)[-1]
                        mapping = self.map_states(self.hmm_m5, 2)
                        self.mapped_m5_state = mapping.get(raw_state, 0)
                    except Exception:
                        pass

        return self._generate_advice(mapped_s5_state, s5_probs, self.mapped_m1_state, self.last_m1_probs, self.mapped_m5_state, self.last_m5_probs)

    def _generate_advice(self, s5_state, s5_probs, m1_state, m1_probs, m5_state, m5_probs):
        if m1_state is None or m5_state is None or s5_state is None:
            return '⚪ INICIALIZÁLÁS: Adatgyűjtés folyamatban...'

        s5_conf = np.max(s5_probs) if s5_probs is not None else 0
        m1_conf = np.max(m1_probs) if m1_probs is not None else 0
        m5_conf = np.max(m5_probs) if m5_probs is not None else 0

        # M5: 0 = Sávos, 1 = Trendelő
        # M1: 0 = Oldalazó, 1 = Bika, -1 = Medve
        # S5: 0 = Zaj, 1 = Bika Mikrotendencia, -1 = Medve Mikrotendencia

        if m5_conf > 0.8 and m1_conf > 0.85:
            if m1_state == 1 and s5_state == 1:
                return f'🟩 ERŐS LONG (S5 Bika is!): Csak vételi skalp ajánlott. Magas momentum.'
            elif m1_state == -1 and s5_state == -1:
                return f'🟥 ERŐS SHORT (S5 Medve is!): Csak eladási skalp ajánlott. Magas momentum.'
            elif m1_state == 1 and s5_state == -1:
                return f'🟨 LONG GYENGÜL: Lokális momentum megfordult (S5 Medve), zárd a profitot!'
            elif m1_state == -1 and s5_state == 1:
                return f'🟨 SHORT GYENGÜL: Lokális momentum megfordult (S5 Bika), zárd a profitot!'

        if m1_state == 0 and m5_state == 0:
            if s5_state == 1 or s5_state == -1:
                return '🟥 PIROSSKALP TILTVA: Álkitörés veszélye! M1/M5 oldalazik, de S5 ugrik. Ne ugorj be!'
            return '🟦 SÁVOS PIAC: Trendkövető skalp TILOS.'

        return '⬜ SEMLEGES: Várj a tiszta állapotváltásra.'
