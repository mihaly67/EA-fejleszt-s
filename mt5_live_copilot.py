import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import time
import os
import socket
import threading
from datetime import datetime
import collections

# Globals for Macro Cache
macro_cache = {
    'Dist_Micro_R': 0.0,
    'Dist_Micro_S': 0.0,
    'Dist_Sec_R': 0.0,
    'Dist_Sec_S': 0.0,
    'Dist_Ter_R': 0.0,
    'Dist_Ter_S': 0.0,
    'Stoch_State_M1': 0.0
}
macro_lock = threading.Lock()

# Globals for Dollar Bars
DOLLAR_BAR_THRESHOLD = 444000.0 # for MGC
current_dollar_volume = 0.0
current_bar_ticks = []

def initialize_copilot():
    print("=== 🟢 STARTING MT5 ONLINE COPILOT ===")
    print("Loading Pre-Trained V5 Fusion Model...")
    try:
        clf = joblib.load('../models/lgbm_model_fusion_v5_tuned.pkl')
    except Exception as e:
        print(f"Error loading model: {e}")
        # Return a dummy model if file doesn't exist to allow testing
        print("Using dummy fallback for testing!")
        class DummyClf:
            def predict_proba(self, X):
                return np.array([[0.33, 0.34, 0.33]])
        return DummyClf()
    print("Copilot Engine Armed and Ready.")
    return clf

def evaluate_tick_state(clf, current_features_dict):
    features = [
        'Tick_Speed', 'Micro_Trend', 'Macro_Trend', 'Imbalance_L1', 'Imbalance_L2',
        'Imbalance_L3', 'Imbalance_L4', 'Imbalance_L5', 'Imbalance_L6',
        'Imbalance_L7', 'Imbalance_L8', 'Imbalance_L9', 'Imbalance_L10',
        'CVD_Raw', 'CVD_Rolling_10', 'Cancel_Rate_Rolling_10',
        'Trade_Size_Imbalance', 'Spread_ZScore',
        'ATR_Micro', 'Velocity_Micro',
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1',
        'Upper_Wick_ATR', 'Lower_Wick_ATR'
    ]

    # Fill missing with 0 for robustness
    for f in features:
        if f not in current_features_dict:
            current_features_dict[f] = 0.0

    df_eval = pd.DataFrame([current_features_dict])[features]
    probs = clf.predict_proba(df_eval)[0]

    p_short = probs[0]
    p_noise = probs[1]
    p_long  = probs[2]

    P_LONG_MIN = 0.49
    P_NOISE_MAX_LONG = 0.35
    P_SHORT_MIN = 0.45
    P_NOISE_MAX_SHORT = 0.35

    signal = 0
    signal_str = "HOLD (NOISE)"

    if p_long > P_LONG_MIN and p_noise < P_NOISE_MAX_LONG and p_long > p_short:
        signal = 1
        signal_str = "🟢 BUY (UPTREND)"
    elif p_short > P_SHORT_MIN and p_noise < P_NOISE_MAX_SHORT and p_short > p_long:
        signal = -1
        signal_str = "🔴 SELL (DOWNTREND)"

    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{current_time}] | SIGNAL: {signal_str:<18} | P_Long: {p_long*100:.1f}% | P_Short: {p_short*100:.1f}% | P_Noise: {p_noise*100:.1f}%")

    return signal, p_long, p_short, p_noise

class MacroReceiver(threading.Thread):
    def __init__(self, host='0.0.0.0', port=5555):
        super().__init__()
        self.host = host
        self.port = port
        self.running = True

    def run(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(1)
        print(f"[MACRO] Server listening on {self.host}:{self.port}")

        while self.running:
            try:
                server.settimeout(2.0)
                client, addr = server.accept()
                client.settimeout(None)
                print(f"[MACRO] EA Connected from {addr}")
                buffer = ""
                while self.running:
                    data = client.recv(4096)
                    if not data:
                        break
                    buffer += data.decode('utf-8', errors='ignore')
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line.startswith("MACRO|"):
                            # If EA starts sending macro payload: MACRO|Dist_Micro_R|...
                            parts = line.split("|")
                            if len(parts) >= 8:
                                with macro_lock:
                                    try:
                                        macro_cache['Dist_Micro_R'] = float(parts[1])
                                        macro_cache['Dist_Micro_S'] = float(parts[2])
                                        macro_cache['Dist_Sec_R'] = float(parts[3])
                                        macro_cache['Dist_Sec_S'] = float(parts[4])
                                        macro_cache['Dist_Ter_R'] = float(parts[5])
                                        macro_cache['Dist_Ter_S'] = float(parts[6])
                                        macro_cache['Stoch_State_M1'] = float(parts[7])
                                    except ValueError:
                                        pass
                client.close()
            except socket.timeout:
                continue
            except Exception as e:
                print(f"[MACRO] Error: {e}")

class TickReceiver(threading.Thread):
    def __init__(self, clf, host='0.0.0.0', port=5556):
        super().__init__()
        self.clf = clf
        self.host = host
        self.port = port
        self.running = True

    def extract_dom_features(self, parts):
        # Parts: TICK|time_msc|bid|ask|pos_type|pos_price|pos_profit|av1|av2|bv1|bv2|ap1|ap2|bp1|bp2
        try:
            bid = float(parts[2])
            ask = float(parts[3])
            av1 = float(parts[7]) if len(parts) > 7 else 0.0
            bv1 = float(parts[9]) if len(parts) > 9 else 0.0

            # Simplified features for the tick
            mid_price = (bid + ask) / 2.0
            tick_vol = av1 + bv1 # approx
            dollar_vol = tick_vol * mid_price

            imb_l1 = (av1 - bv1) / (av1 + bv1 + 1e-9)

            return {
                'mid_price': mid_price,
                'dollar_vol': dollar_vol,
                'imb_l1': imb_l1,
                'bid': bid,
                'ask': ask
            }
        except Exception:
            return None

    def run(self):
        global current_dollar_volume, current_bar_ticks

        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(1)
        print(f"[TICK] Server listening on {self.host}:{self.port}")

        while self.running:
            try:
                server.settimeout(2.0)
                client, addr = server.accept()
                client.settimeout(None)
                print(f"[TICK] EA Connected from {addr}")
                buffer = ""

                # We need to compute simple moving features across closed bars
                bar_closes = collections.deque(maxlen=15)

                while self.running:
                    data = client.recv(4096)
                    if not data:
                        break
                    buffer += data.decode('utf-8', errors='ignore')

                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line.startswith("TICK|"):
                            parts = line.split("|")
                            tick_data = self.extract_dom_features(parts)

                            if not tick_data:
                                continue

                            current_bar_ticks.append(tick_data)
                            current_dollar_volume += tick_data['dollar_vol']

                            if current_dollar_volume >= DOLLAR_BAR_THRESHOLD:
                                # Bar Closed!
                                df_bar = pd.DataFrame(current_bar_ticks)
                                open_p = df_bar['mid_price'].iloc[0]
                                high_p = df_bar['mid_price'].max()
                                low_p = df_bar['mid_price'].min()
                                close_p = df_bar['mid_price'].iloc[-1]

                                bar_closes.append(close_p)

                                # Calc features
                                atr = (high_p - low_p) if len(bar_closes) < 2 else np.mean([abs(bar_closes[i] - bar_closes[i-1]) for i in range(1, len(bar_closes))])
                                if atr == 0: atr = 0.001

                                upper_wick = high_p - max(open_p, close_p)
                                lower_wick = min(open_p, close_p) - low_p

                                f_dict = {
                                    'Tick_Speed': len(current_bar_ticks), # Proxy
                                    'Imbalance_L1': tick_data['imb_l1'],
                                    'Velocity_Micro': (close_p - open_p),
                                    'ATR_Micro': atr,
                                    'Upper_Wick_ATR': upper_wick / atr,
                                    'Lower_Wick_ATR': lower_wick / atr,
                                }

                                # Fuse Macro State (O(1) Memory Lookup)
                                with macro_lock:
                                    for k, v in macro_cache.items():
                                        f_dict[k] = v

                                # Predict
                                sig, pl, ps, pn = evaluate_tick_state(self.clf, f_dict)

                                # Send back to EA
                                msg = f"PRED|{sig}|{pl:.4f}|{ps:.4f}|{pn:.4f}\n"
                                client.send(msg.encode('utf-8'))

                                # Reset bar
                                current_dollar_volume = 0.0
                                current_bar_ticks = []

                client.close()
            except socket.timeout:
                continue
            except Exception as e:
                print(f"[TICK] Error: {e}")

def main():
    clf = initialize_copilot()
    if not clf: return

    macro_thread = MacroReceiver(port=5555)
    tick_thread = TickReceiver(clf, port=5556)

    macro_thread.start()
    tick_thread.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down...")
        macro_thread.running = False
        tick_thread.running = False
        macro_thread.join()
        tick_thread.join()

if __name__ == "__main__":
    main()
