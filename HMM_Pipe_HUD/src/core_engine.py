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

    def process_tick(self, s5_row, m1_time, m1_row, m5_time, m5_row):
        # S5 ablak frissítése és MINTAVÉTEL
        s5_state, s5_probs = None, None
        if s5_row is not None:
            features_s5 = [s5_row['LogReturn'], s5_row['ATR_Proxy']]
            self.window_s5.append(features_s5)
            if len(self.window_s5) > self.max_window_s5:
                self.window_s5.pop(0)

            if len(self.window_s5) >= 30:
                X_s5 = np.array(self.window_s5)
                # Adatbiztonság: ne fitteljünk csak 0-ákból álló adatra
                if np.std(X_s5) > 0:
                    X_s5_scaled = self.scaler_s5.fit_transform(X_s5)
                    try:
                        self.hmm_s5.fit(X_s5_scaled)
                        s5_state = self.hmm_s5.predict(X_s5_scaled)[-1]
                        s5_probs = self.hmm_s5.predict_proba(X_s5_scaled)[-1]
                    except Exception:
                        pass

        # M1 számítás (csak ha új M1 gyertya érkezik)
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
                        self.last_m1_state = self.hmm_m1.predict(X_m1_scaled)[-1]
                        self.last_m1_probs = self.hmm_m1.predict_proba(X_m1_scaled)[-1]
                    except Exception:
                        pass

        # M5 számítás (csak ha új M5 gyertya érkezik)
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
                        self.last_m5_state = self.hmm_m5.predict(X_m5_scaled)[-1]
                        self.last_m5_probs = self.hmm_m5.predict_proba(X_m5_scaled)[-1]
                    except Exception:
                        pass

        return self._generate_advice(s5_state, s5_probs, self.last_m1_state, self.last_m1_probs, self.last_m5_state, self.last_m5_probs)

    def _generate_advice(self, s5_state, s5_probs, m1_state, m1_probs, m5_state, m5_probs):
        if m1_state is None or m5_state is None or s5_state is None:
            return '⚪ INICIALIZÁLÁS: Adatgyűjtés folyamatban...'

        s5_conf = np.max(s5_probs) if s5_probs is not None else 0
        m1_conf = np.max(m1_probs) if m1_probs is not None else 0
        m5_conf = np.max(m5_probs) if m5_probs is not None else 0

        # Ez egy demó leképezés a 3 állapotra, melyik micsoda véletlen a kezdőpont miatt,
        # de bemutatja a hibrid skálázást a három idősík alapján.
        if m5_conf > 0.8 and m1_conf > 0.85:
            if m1_state == 1 and s5_state == 1:
                return f'🟩 ERŐS LONG (S5 Bika is!): Csak vételi skalp ajánlott. Magas momentum.'
            elif m1_state == 2 and s5_state == 2:
                return f'🟥 ERŐS SHORT (S5 Medve is!): Csak eladási skalp ajánlott. Magas momentum.'
            elif m1_state == 1 and s5_state == 2:
                return f'🟨 LONG GYENGÜL: Lokális momentum megfordult (S5 Medve), zárd a profitot!'
            elif m1_state == 2 and s5_state == 1:
                return f'🟨 SHORT GYENGÜL: Lokális momentum megfordult (S5 Bika), zárd a profitot!'

        if m1_state == 0 and m5_state == 0:
            if s5_state == 1 or s5_state == 2:
                return '🟥 PIROSSKALP TILTVA: Álkitörés veszélye! M1/M5 oldalazik, de S5 ugrik. Ne ugorj be!'
            return '🟦 SÁVOS PIAC: Trendkövető skalp TILOS.'

        return '⬜ SEMLEGES: Várj a tiszta állapotváltásra.'
