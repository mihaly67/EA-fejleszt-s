import pandas as pd
import numpy as np
import logging
import time
import os

from utils.ring_buffer import O1RingBuffer
from utils.log_er_scaler import LogERScaler

# Add try-except for hmmlearn to gracefully handle if it's not installed in other environments.
try:
    from hmmlearn.hmm import GaussianHMM
    HMMLEARN_INSTALLED = True
except ImportError:
    HMMLEARN_INSTALLED = False

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class HybridStreamingEngine:
    def __init__(self, macro_window_minutes=5, micro_window_ticks=15):
        # Mikro Bufferek
        self.micro_window = micro_window_ticks
        self.price_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.time_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.spread_buffer = O1RingBuffer(capacity=1000, dimensions=1)
        self.scaler = LogERScaler(base_n=15, max_n=1000)
        
        if not HMMLEARN_INSTALLED:
             logger.warning("hmmlearn package not installed. Running in dummy mode.")
             
        # HMM model (3 állapotú: Calm, Impulsive Up, Impulsive Down)
        if HMMLEARN_INSTALLED:
            self.hmm_model = GaussianHMM(n_components=3, covariance_type="diag", n_iter=100, random_state=42, init_params="")
        else:
            self.hmm_model = None
            
        # State mapping based on blueprint
        self.state_map = {"Calm": 0, "ImpulsiveUp": 1, "ImpulsiveDown": 2}
        self.is_hmm_trained = False
        self.training_buffer = []

    def get_micro_features(self):
        prices = self.price_buffer.get_slice(self.micro_window)
        if len(prices) < 2:
            return 0.0, 0.0, 0.0
            
        net_move = prices[-1] - prices[0] # Directional log return proxy
        gross_move = np.sum(np.abs(np.diff(prices)))
        log_return = net_move / gross_move if gross_move > 0 else 0.0
        
        spreads = self.spread_buffer.get_slice(self.micro_window)
        avg_spread = np.mean(spreads) if len(spreads) > 0 else 0.0
        
        times = self.time_buffer.get_slice(self.micro_window)
        tick_density = 0.0
        if len(times) > 1:
            time_diff = max(1.0, times[-1] - times[0])
            tick_density = len(times) / (time_diff / 1000.0) # ticks per second
            
        return log_return, avg_spread, tick_density

    def fit_and_map_hmm(self, observations):
        if not HMMLEARN_INSTALLED or len(observations) < 100:
            return False

        try:
            import warnings

            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                self.hmm_model.fit(observations)
                sys.stderr = sys.__stderr__
            means = self.hmm_model.means_
            
            # Semantic mapping
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
            self.is_hmm_trained = True
            return True
        except Exception as e:
            # logger.error(f"HMM Training failed: {e}")
            return False

    def predict_future_state(self, obs_sequence):
        """Predicts the future state probability based on the transition matrix"""
        if not self.is_hmm_trained or not HMMLEARN_INSTALLED:
            return 0, 0.0, 0.0
            
        try:
            import warnings

            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                posterior_probs = self.hmm_model.predict_proba(obs_sequence)[-1]
                
            trans_mat = self.hmm_model.transmat_
            future_probs = np.dot(posterior_probs, trans_mat)
            
            calm_state_id = self.state_map["Calm"]
            calm_risk = future_probs[calm_state_id] * 100.0
            
            # Find the best impulsive state if applicable
            current_state = future_probs.argmax()
            confidence = future_probs[current_state] * 100.0
            
            return current_state, calm_risk, confidence
        except Exception:
            return 0, 0.0, 0.0

    def run_stream(self, file_path):
        logger.info(f"▶️ HIBRID ONLINE ENGINE INDÍTÁSA: {os.path.basename(file_path)}")
        
        total_ticks = 0
        decisions = {'GREEN': 0, 'YELLOW': 0, 'RED': 0, 'NO_TRADE': 0}
        
        start_time = time.perf_counter()
        
        try:
            chunk_iter = pd.read_csv(file_path, chunksize=20000)
            for chunk in chunk_iter:
                time_cols = [c for c in chunk.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc', 'time']]
                if not time_cols:
                    logger.warning("No time column found in CSV")
                    return
                t_col = time_cols[0]
                
                for _, row in chunk.iterrows():
                    try:
                        t_ms = float(row[t_col])
                    except ValueError:
                        # Ha datetime formátum, próbáljuk parse-olni (timestamp milliszekundumban)
                        t_ms = pd.to_datetime(row[t_col]).timestamp() * 1000.0
                    price = (row['Ask'] + row['Bid']) / 2.0 if 'Ask' in row and 'Bid' in row else row.iloc[1]
                    spread = row['Ask'] - row['Bid'] if 'Ask' in row else 0.0
                    
                    # O(1) frissítés
                    self.time_buffer.push(t_ms)
                    self.price_buffer.push(price)
                    self.spread_buffer.push(spread)
                    total_ticks += 1
                    
                    if total_ticks < self.micro_window:
                        continue
                        
                    log_return, avg_spread, tick_density = self.get_micro_features()
                    obs = [log_return, avg_spread, tick_density]
                    self.training_buffer.append(obs)
                    
                    # Keep sliding window to 300
                    if len(self.training_buffer) > 300:
                        self.training_buffer.pop(0)

                    # Train every 50 ticks
                    if total_ticks % 50 == 0 and len(self.training_buffer) == 300:
                        self.fit_and_map_hmm(np.array(self.training_buffer))
                    
                    if not self.is_hmm_trained:
                        continue
                        
                    current_state, calm_risk, confidence = self.predict_future_state(np.array(self.training_buffer))
                    
                    # Confidence rule
                    if confidence < 80.0:
                        decisions['NO_TRADE'] += 1
                        continue
                        
                    # Decision logic
                    if current_state in [self.state_map["ImpulsiveUp"], self.state_map["ImpulsiveDown"]]:
                        if calm_risk < 20.0:
                            decisions['GREEN'] += 1
                        else:
                            decisions['YELLOW'] += 1
                    else:
                        decisions['RED'] += 1
        except FileNotFoundError:
            logger.error(f"File not found: {file_path}")
            return
                    
        end_time = time.perf_counter()
        
        logger.info(f"✅ VÉGE. Feldolgozott Tickek: {total_ticks:,}")
        if end_time - start_time > 0:
            logger.info(f"⏱️ Sebesség: {(end_time - start_time):.2f} másodperc ({(total_ticks / (end_time - start_time)):,.0f} tick/sec)")
        logger.info(f"📊 EA Döntések: 🟢 ZÖLD: {decisions['GREEN']:,} | 🟡 SÁRGA (Veszély): {decisions['YELLOW']:,} | 🔴 PIROS (Tiltott): {decisions['RED']:,} | ⚪ NO TRADE (Bizonytalan): {decisions['NO_TRADE']:,}")

if __name__ == "__main__":
    engine = HybridStreamingEngine()
    engine.run_stream("data/Merkava_XAUUSD_v1.10_20260408_025931.csv")
