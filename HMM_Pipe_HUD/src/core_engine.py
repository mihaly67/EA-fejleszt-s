from hmmlearn.hmm import GaussianHMM
import numpy as np
import warnings
from sklearn.preprocessing import StandardScaler
import logging
from collections import deque
import pandas as pd

warnings.filterwarnings('ignore')
logging.getLogger('hmmlearn').setLevel(logging.CRITICAL)

class SimpleRingBuffer:
    def __init__(self, size):
        self.size = size
        self.data = deque(maxlen=size)

    def append(self, x):
        self.data.append(x)

    def is_full(self):
        return len(self.data) == self.size

    def get_array(self):
        return np.array(self.data)

class HMMCoreEngine:
    def __init__(self):
        # Ultra-lightweight configuration
        # Buffer needs only 30 elements to initialize the model.
        # After initialization, we ONLY predict().
        self.models = {
            'm15': {'hmm': None, 'scaler': StandardScaler(), 'fitted': False, 'states': 2, 'window': SimpleRingBuffer(30)},
            'm5':  {'hmm': None, 'scaler': StandardScaler(), 'fitted': False, 'states': 3, 'window': SimpleRingBuffer(30)},
            'm1':  {'hmm': None, 'scaler': StandardScaler(), 'fitted': False, 'states': 3, 'window': SimpleRingBuffer(30)}
        }

        self.last_times = {'m5': None, 'm15': None}
        self.last_states = {'m1': None, 'm5': None, 'm15': None}
        self.last_probs = {'m1': None, 'm5': None, 'm15': None}

    def _train_model(self, tf_key, data_array):
        scaler = self.models[tf_key]['scaler']
        scaled_data = scaler.fit_transform(data_array)
        n_states = self.models[tf_key]['states']

        model = GaussianHMM(n_components=n_states, covariance_type='full', n_iter=10, random_state=42, init_params="smc")

        off_diag = 0.1 / (n_states - 1) if n_states > 1 else 0
        transmat = np.full((n_states, n_states), off_diag)
        np.fill_diagonal(transmat, 0.9)
        model.transmat_ = transmat

        model.fit(scaled_data)

        self.models[tf_key]['hmm'] = model
        self.models[tf_key]['fitted'] = True

    def _predict_state(self, tf_key, features):
        scaler = self.models[tf_key]['scaler']
        model = self.models[tf_key]['hmm']
        n_states = self.models[tf_key]['states']

        # Predict on a single tick! No buffer needed for predict if we treat it as an independent observation
        # or we just pass the last N elements. For pure O(1) CPU speed, we pass just the buffer's contents.
        data_array = self.models[tf_key]['window'].get_array()
        scaled_data = scaler.transform(data_array)

        # Predict returns the state sequence, we take the last one
        raw_state = model.predict(scaled_data)[-1]
        probs = model.predict_proba(scaled_data)[-1]

        means = model.means_[:, 0]
        if n_states == 2:
            idx = np.argsort(np.abs(means))
            mapping = {idx[0]: 0, idx[1]: 1}
        else:
            idx = np.argsort(means)
            mapping = {idx[0]: -1, idx[1]: 0, idx[2]: 1}

        mapped_state = mapping.get(raw_state, 0)

        # Smoothing (Mode of last 3 states) to prevent flickering (like github repo)
        if not hasattr(self, 'history'):
            self.history = {'m1': deque(maxlen=3), 'm5': deque(maxlen=3), 'm15': deque(maxlen=3)}
        self.history[tf_key].append(mapped_state)
        smoothed_state = int(pd.Series(self.history[tf_key]).mode()[0])

        return smoothed_state, probs

    def process_tick(self, m1_row, m5_time, m5_row, m15_time, m15_row):
        # M1
        if m1_row is not None:
            self.models['m1']['window'].append([m1_row['LogReturn'], m1_row['ATR_Proxy']])
            if self.models['m1']['window'].is_full():
                if not self.models['m1']['fitted']:
                    self._train_model('m1', self.models['m1']['window'].get_array())
                self.last_states['m1'], self.last_probs['m1'] = self._predict_state('m1', None)

        # M5
        if m5_row is not None and m5_time != self.last_times['m5']:
            self.last_times['m5'] = m5_time
            self.models['m5']['window'].append([m5_row['LogReturn'], m5_row['ATR_Proxy']])
            if self.models['m5']['window'].is_full():
                if not self.models['m5']['fitted']:
                    self._train_model('m5', self.models['m5']['window'].get_array())
                self.last_states['m5'], self.last_probs['m5'] = self._predict_state('m5', None)

        # M15
        if m15_row is not None and m15_time != self.last_times['m15']:
            self.last_times['m15'] = m15_time
            self.models['m15']['window'].append([m15_row['LogReturn'], m15_row['ATR_Proxy']])
            if self.models['m15']['window'].is_full():
                if not self.models['m15']['fitted']:
                    self._train_model('m15', self.models['m15']['window'].get_array())
                self.last_states['m15'], self.last_probs['m15'] = self._predict_state('m15', None)

        return self._generate_advice()

    def _generate_advice(self):
        s1 = self.last_states['m1']
        s5 = self.last_states['m5']
        s15 = self.last_states['m15']

        if s1 is None or s5 is None or s15 is None:
            return '⚪ INICIALIZÁLÁS: Adatgyűjtés folyamatban...'

        m15_conf = np.max(self.last_probs['m15'])

        if s15 == 1 and m15_conf > 0.4:
            if s5 == 1 and s1 == 1:
                return '🟩 VÉTEL (BUY) JELZÉS: M15 Trend, M5/M1 Bullish.'
            elif s5 == -1 and s1 == -1:
                return '🟥 ELADÁS (SELL) JELZÉS: M15 Trend, M5/M1 Bearish.'
            elif s5 == 1 and s1 == -1:
                return '🟨 PULLBACK LONG: M5 Bika, de M1 korrigál.'
            elif s5 == -1 and s1 == 1:
                return '🟨 PULLBACK SHORT: M5 Medve, de M1 korrigál.'

        if s15 == 0:
            if s5 == 1 and s1 == 1:
                return '🟦 LOKÁLIS KITÖRÉS LONG: M15 Oldalazik, de lokális Bika.'
            if s5 == -1 and s1 == -1:
                return '🟦 LOKÁLIS KITÖRÉS SHORT: M15 Oldalazik, de lokális Medve.'
            return '⬜ SÁVOS PIAC (RANGING): Várj tiszta M15 Trendre.'

        return '⬜ SEMLEGES: Várj a tiszta állapotváltásra.'
