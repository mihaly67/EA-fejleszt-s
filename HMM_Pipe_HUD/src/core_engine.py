from hmmlearn.hmm import GaussianHMM
import numpy as np
import warnings
from sklearn.preprocessing import StandardScaler
import logging

warnings.filterwarnings('ignore')
logging.getLogger('hmmlearn').setLevel(logging.CRITICAL)

class HMMCoreEngine:
    def __init__(self):
        # M15 (Layer 3 - Regime) - 2 states (Ranging / Trending)
        self.hmm_m15 = GaussianHMM(n_components=2, covariance_type='full', n_iter=100, random_state=42)
        # M5 (Layer 2 - Swing) - 3 states (Bearish, Ranging, Bullish)
        self.hmm_m5 = GaussianHMM(n_components=3, covariance_type='full', n_iter=100, random_state=42)
        # M1 (Layer 1 - Scalp/Entry) - 3 states
        self.hmm_m1 = GaussianHMM(n_components=3, covariance_type='full', n_iter=100, random_state=42)

        self.window_m15 = []
        self.window_m5 = []
        self.window_m1 = []

        # Nagyobb ablakok az új idősíkokhoz, hogy elég minta legyen (a github repóból véve a logikát, 200/120 bar okés)
        self.max_window_m15 = 200
        self.max_window_m5 = 120
        self.max_window_m1 = 60

        self.scaler_m15 = StandardScaler()
        self.scaler_m5 = StandardScaler()
        self.scaler_m1 = StandardScaler()

        self.last_m5_time = None
        self.last_m15_time = None

        self.last_m5_state, self.last_m5_probs = None, None
        self.last_m15_state, self.last_m15_probs = None, None

        self.mapped_m5_state = None
        self.mapped_m15_state = None

    def map_states(self, hmm_model, num_states):
        # Maps the random HMM states to logical market conditions based on the mean of the LogReturns (feature 0)
        means = hmm_model.means_[:, 0]

        if num_states == 2:
            # 2 states: 0 = Ranging, 1 = Trending
            idx = np.argsort(np.abs(means))
            mapping = {idx[0]: 0, idx[1]: 1}
            return mapping

        elif num_states == 3:
            # 3 states: lowest mean = Bearish (-1), middle = Ranging (0), highest = Bullish (1)
            idx = np.argsort(means)
            mapping = {idx[0]: -1, idx[1]: 0, idx[2]: 1}
            return mapping

        return {}

    def process_tick(self, m1_row, m5_time, m5_row, m15_time, m15_row):
        m1_state, m1_probs = None, None
        mapped_m1_state = None

        # M1 számítás
        if m1_row is not None:
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
                        m1_probs = self.hmm_m1.predict_proba(X_m1_scaled)[-1]
                        mapping = self.map_states(self.hmm_m1, 3)
                        mapped_m1_state = mapping.get(raw_state, 0)
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
                        mapping = self.map_states(self.hmm_m5, 3)
                        self.mapped_m5_state = mapping.get(raw_state, 0)
                    except Exception:
                        pass

        # M15 számítás
        if m15_row is not None and m15_time != self.last_m15_time:
            self.last_m15_time = m15_time
            features_m15 = [m15_row['LogReturn'], m15_row['ATR_Proxy']]
            self.window_m15.append(features_m15)
            if len(self.window_m15) > self.max_window_m15:
                self.window_m15.pop(0)

            if len(self.window_m15) >= 30:
                X_m15 = np.array(self.window_m15)
                if np.std(X_m15) > 0:
                    X_m15_scaled = self.scaler_m15.fit_transform(X_m15)
                    try:
                        self.hmm_m15.fit(X_m15_scaled)
                        raw_state = self.hmm_m15.predict(X_m15_scaled)[-1]
                        self.last_m15_probs = self.hmm_m15.predict_proba(X_m15_scaled)[-1]
                        mapping = self.map_states(self.hmm_m15, 2)
                        self.mapped_m15_state = mapping.get(raw_state, 0)
                    except Exception:
                        pass

        return self._generate_advice(mapped_m1_state, m1_probs, self.mapped_m5_state, self.last_m5_probs, self.mapped_m15_state, self.last_m15_probs)

    def _generate_advice(self, m1_state, m1_probs, m5_state, m5_probs, m15_state, m15_probs):
        if m5_state is None or m15_state is None or m1_state is None:
            return '⚪ INICIALIZÁLÁS: Adatgyűjtés folyamatban...'

        m1_conf = np.max(m1_probs) if m1_probs is not None else 0
        m5_conf = np.max(m5_probs) if m5_probs is not None else 0
        m15_conf = np.max(m15_probs) if m15_probs is not None else 0

        # M15: 0 = Sávos (Ranging), 1 = Trendelő (Trending)
        # M5: 0 = Oldalazó, 1 = Bika, -1 = Medve
        # M1: 0 = Zaj/Oldalazó, 1 = Bika, -1 = Medve

        # A Github Repo (H1 Swing/TrendFollow) alapján: Ha a nagy trend (Regime) beáll, és a lokális idősík egyetért, BELÉPÉS.
        # Lazítunk a küszöbön, >0.6 már megbízhatónak számít trend esetén.

        if m15_state == 1 and m15_conf > 0.6:  # Trendelő Regime
            if m5_state == 1 and m1_state == 1:
                return f'🟩 VÉTEL (BUY) JELZÉS: M15 Trend, M5/M1 Bullish. Csatlakozás a trendhez!'
            elif m5_state == -1 and m1_state == -1:
                return f'🟥 ELADÁS (SELL) JELZÉS: M15 Trend, M5/M1 Bearish. Csatlakozás a trendhez!'
            elif m5_state == 1 and m1_state == -1:
                return f'🟨 PULLBACK LONG: M5 Bika, de M1 korrigál (Várd meg a M1 fordulást vételhez!)'
            elif m5_state == -1 and m1_state == 1:
                return f'🟨 PULLBACK SHORT: M5 Medve, de M1 korrigál (Várd meg a M1 fordulást eladáshoz!)'

        # Ha a Regime oldalazik (Sávos piac):
        if m15_state == 0:
            if m5_state == 1 and m1_state == 1:
                return '🟦 LOKÁLIS KITÖRÉS LONG: M15 Oldalazik, de lokális M5/M1 Bika. (Kockázatos skalp!)'
            if m5_state == -1 and m1_state == -1:
                return '🟦 LOKÁLIS KITÖRÉS SHORT: M15 Oldalazik, de lokális M5/M1 Medve. (Kockázatos skalp!)'
            return '⬜ SÁVOS PIAC (RANGING): Várj tiszta M15 Trendre a biztonságos beszállóhoz.'

        return '⬜ SEMLEGES: Várj a tiszta állapotváltásra.'
