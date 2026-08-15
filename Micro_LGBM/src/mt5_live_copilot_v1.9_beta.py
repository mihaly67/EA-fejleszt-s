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
import zmq
import json

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

zmq_context = zmq.Context()
zmq_publisher = zmq_context.socket(zmq.PUB)
zmq_publisher.bind("tcp://0.0.0.0:5557")

signal_history = collections.deque(maxlen=3)

# Globals for Dollar Bars
DOLLAR_BAR_THRESHOLD = 444000.0 # Match exactly with Prado logic!
latest_prob = {'p_long': 0.0, 'p_short': 0.0, 'p_noise': 0.0, 'signal': 0, 'stable': False}
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
        'Tick_Speed', 'Dist_Micro_R', 'Dist_Micro_S',
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

    P_LONG_MIN = 0.350
    P_NOISE_MAX_LONG = 0.470
    P_SHORT_MIN = 0.360
    P_NOISE_MAX_SHORT = 0.470

    signal = 0
    signal_str = "HOLD (NOISE)"

    if p_long > P_LONG_MIN and p_noise < P_NOISE_MAX_LONG and p_long > p_short:
        signal = 1
        signal_str = "🟢 BUY (UPTREND)"
    elif p_short > P_SHORT_MIN and p_noise < P_NOISE_MAX_SHORT and p_short > p_long:
        signal = -1
        signal_str = "🔴 SELL (DOWNTREND)"

    # --- STOCHASTIC HARD FILTER ENFORCEMENT ---
    # The model ignores Stoch_K internally, so we enforce it here as an overriding physical rule
    # to filter out false breakouts based on momentum.
    stoch_state = current_features_dict.get('Stoch_State_M1', 0.0)
    # Stoch_State_M1 is normalized [-1, 1], where 0 is the 50 line.

    if signal == 1 and stoch_state < 0.0:
        signal = 0
        signal_str = "HOLD (STOCH BLOCKED LONG)"
    elif signal == -1 and stoch_state > 0.0:
        signal = 0
        signal_str = "HOLD (STOCH BLOCKED SHORT)"

    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{current_time}] | SIGNAL: {signal_str:<18} | P_Long: {p_long*100:.1f}% | P_Short: {p_short*100:.1f}% | P_Noise: {p_noise*100:.1f}%")

    print(f"RAW PROBS -> Long: {p_long:.4f} Short: {p_short:.4f} Noise: {p_noise:.4f}")
    # Stability Calculation
    signal_history.append(signal)
    is_stable = (len(signal_history) == 3 and len(set(signal_history)) == 1)

    # Broadcast to HUD via ZMQ
    with macro_lock:
        current_price = macro_cache.get('Current_Macro_Price', 0.0)

    # Fetch correct tick time if available
    tick_time = current_features_dict.get('Time', time.time())

    hud_data = {
        "timestamp": tick_time, # Send actual MT5 server time
        "price": current_price,
        "open": current_features_dict.get('Open', current_price),
        "high": current_features_dict.get('High', current_price),
        "low": current_features_dict.get('Low', current_price),
        "close": current_features_dict.get('Close', current_price),
        "bid": current_features_dict.get('Bid', current_price),
        "ask": current_features_dict.get('Ask', current_price),
        "stoch_k": current_features_dict.get('Raw_Stoch_K', 0.5) * 100.0,
        "signal": signal,
        "p_long": float(p_long),
        "p_short": float(p_short),
        "p_noise": float(p_noise),
        "is_stable": bool(is_stable)
    }
    try:
        zmq_publisher.send_string(f"HUD {json.dumps(hud_data)}")
    except Exception as e:
        print(f"[ZMQ] Error publishing HUD data: {e}")

    return signal, p_long, p_short, p_noise


class FullZigZagEngine:
    def __init__(self, depth=12, deviation=5, backstep=3):
        self.depth = depth
        self.deviation = deviation
        self.backstep = backstep

    def calculate(self, highs, lows, point_size=0.1):
        n = len(highs)
        zigzag = np.zeros(n)
        high_map = np.zeros(n)
        low_map = np.zeros(n)
        if n < self.depth: return zigzag, high_map, low_map
        for i in range(self.depth, n):
            start_idx = max(0, i - self.depth + 1)
            w_high = highs[start_idx:i+1]
            if len(w_high) > 0:
                max_val = np.max(w_high)
                if max_val == highs[i]: high_map[i] = highs[i]
                else: high_map[i] = 0.0
            w_low = lows[start_idx:i+1]
            if len(w_low) > 0:
                min_val = np.min(w_low)
                if min_val == lows[i]: low_map[i] = lows[i]
                else: low_map[i] = 0.0
        last_high = 0.0
        last_low = 0.0
        for i in range(self.depth, n):
            if low_map[i] != 0:
                if last_low == 0.0 or low_map[i] < last_low:
                    last_low = low_map[i]
                    zigzag[i] = -1
                elif low_map[i] > last_low + (self.deviation * point_size):
                    last_low = low_map[i]
                    zigzag[i] = -1
            if high_map[i] != 0:
                if last_high == 0.0 or high_map[i] > last_high:
                    last_high = high_map[i]
                    zigzag[i] = 1
                elif high_map[i] < last_high - (self.deviation * point_size):
                    last_high = high_map[i]
                    zigzag[i] = 1
        rolling_r = np.zeros(n)
        rolling_s = np.zeros(n)
        cur_r = highs[0]
        cur_s = lows[0]
        for i in range(n):
            if zigzag[i] == 1: cur_r = highs[i]
            if zigzag[i] == -1: cur_s = lows[i]
            rolling_r[i] = cur_r
            rolling_s[i] = cur_s
        return rolling_r, rolling_s

class MacroReceiver(threading.Thread):
    def __init__(self, host='0.0.0.0', port=5555):
        super().__init__()
        self.host = host
        self.port = port
        self.running = True

        # New Optimal ZigZag Parameters
        self.mic_zz = FullZigZagEngine(depth=12, deviation=5)
        self.sec_zz = FullZigZagEngine(depth=20, deviation=22) # Optuna Optimized
        self.ter_zz = FullZigZagEngine(depth=36, deviation=40) # Closer tertiary

        self.m1_times = []
        self.m1_opens = []
        self.m1_highs = []
        self.m1_lows = []
        self.m1_closes = []

    def update_macro_cache(self, current_price):
        if len(self.m1_highs) < 50: return
        h = np.array(self.m1_highs)
        l = np.array(self.m1_lows)

        mic_r, mic_s = self.mic_zz.calculate(h, l)
        sec_r, sec_s = self.sec_zz.calculate(h, l)
        ter_r, ter_s = self.ter_zz.calculate(h, l)

        with macro_lock:
            macro_cache['Raw_Mic_R'] = mic_r[-1]
            macro_cache['Raw_Mic_S'] = mic_s[-1]
            macro_cache['Raw_Sec_R'] = sec_r[-1]
            macro_cache['Raw_Sec_S'] = sec_s[-1]
            macro_cache['Raw_Ter_R'] = ter_r[-1]
            macro_cache['Raw_Ter_S'] = ter_s[-1]
            macro_cache['Current_Macro_Price'] = current_price

    def run(self):
        print(f"[MACRO v1.9 BETA] Server listening on {self.host}:{self.port}")
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(1)

        while self.running:
            try:
                server.settimeout(2.0)
                client, addr = server.accept()
                client.settimeout(None)
                print(f"[MACRO] EA Connected from {addr}")
                buffer = ""

                while self.running:
                    try:
                        data = client.recv(65536)
                        if not data:
                            print("[MACRO] Connection closed by EA.")
                            break

                        buffer += data.decode('utf-8', errors='ignore')

                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            line = line.strip()
                            if not line: continue

                            try:
                                payload = json.loads(line)
                                msg_type = payload.get('type', 'update')

                                if msg_type == 'init':
                                    self.m1_times = payload.get('times', [])
                                    self.m1_opens = payload.get('opens', [])
                                    self.m1_highs = payload.get('highs', [])
                                    self.m1_lows = payload.get('lows', [])
                                    self.m1_closes = payload.get('closes', [])
                                    print(f"[MACRO] Received init buffer with {len(self.m1_highs)} candles.")
                                    self.update_macro_cache(self.m1_highs[-1])

                                    # Send the entire history immediately to the HUD
                                    with macro_lock:
                                        history_data = {
                                            "type": "history",
                                            "times": self.m1_times[-100:],
                                            "opens": self.m1_opens[-100:],
                                            "highs": self.m1_highs[-100:],
                                            "lows": self.m1_lows[-100:],
                                            "closes": self.m1_closes[-100:]
                                        }
                                        try:
                                            import json
                                            zmq_publisher.send_string(f"HUD {json.dumps(history_data)}")
                                        except Exception as e:
                                            print("HUD history send err:", e)

                                elif msg_type == 'update':
                                    t = payload.get('time')
                                    o = payload.get('open', payload.get('high'))
                                    h = payload.get('high')
                                    l = payload.get('low')
                                    c = payload.get('close', payload.get('high'))
                                    price = payload.get('price', h)
                                    stoch_k = payload.get('stoch_k', 50.0)

                                    # Update rolling M1 cache
                                    if len(self.m1_times) > 0 and self.m1_times[-1] == t:
                                        self.m1_opens[-1] = o
                                        self.m1_highs[-1] = h
                                        self.m1_lows[-1] = l
                                        self.m1_closes[-1] = c
                                    else:
                                        self.m1_times.append(t)
                                        self.m1_opens.append(o)
                                        self.m1_highs.append(h)
                                        self.m1_lows.append(l)
                                        self.m1_closes.append(c)
                                        if len(self.m1_times) > 200:
                                            self.m1_times.pop(0)
                                            self.m1_opens.pop(0)
                                            self.m1_highs.pop(0)
                                            self.m1_lows.pop(0)
                                            self.m1_closes.pop(0)

                                    with macro_lock:
                                        macro_cache['Stoch_State_M1'] = (stoch_k - 50.0) / 50.0
                                        macro_cache['Raw_Stoch_K'] = stoch_k / 100.0 # Standard 0.0-1.0 scale

                                    self.update_macro_cache(price)

                                    # Continuous HUD Broadcast (M1 Data)
                                    with macro_lock:
                                        hud_data = {
                                            "type": "update",
                                            "timestamp": t,
                                            "price": price,
                                            "open": o,
                                            "high": h,
                                            "low": l,
                                            "close": c,
                                            "bid": price,
                                            "ask": price,
                                            "stoch_k": stoch_k,
                                            "signal": latest_prob['signal'],
                                            "p_long": latest_prob['p_long'],
                                            "p_short": latest_prob['p_short'],
                                            "p_noise": latest_prob['p_noise'],
                                            "is_stable": latest_prob['stable']
                                        }
                                    try:
                                        zmq_publisher.send_string(f"HUD {json.dumps(hud_data)}")
                                    except: pass

                            except json.JSONDecodeError:
                                print(f"[MACRO] Failed to parse JSON: {line}")

                    except Exception as inner_e:
                        print(f"[MACRO] Read error: {inner_e}")
                        break

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
            time_msc = float(parts[1]) / 1000.0 if len(parts) > 1 else time.time()
            bid = float(parts[2])
            ask = float(parts[3])
            av1 = float(parts[7]) if len(parts) > 7 else 0.0
            bv1 = float(parts[9]) if len(parts) > 9 else 0.0

            # Simplified features for the tick
            mid_price = (bid + ask) / 2.0
            tick_vol = 1.0 # 1 tick = 1 volume unit to prevent instant threshold overflow from resting DOM sizes
            dollar_vol = tick_vol * mid_price

            imb_l1 = (av1 - bv1) / (av1 + bv1 + 1e-9)

            return {
                'mid_price': mid_price,
                'dollar_vol': dollar_vol,
                'imb_l1': imb_l1,
                'bid': bid,
                'ask': ask,
                'time': time_msc
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
                    try:
                        data = client.recv(65536)
                        if not data:
                            print("[TICK] Connection closed by EA.")
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
                                        'Upper_Wick_ATR': upper_wick / atr,
                                        'Lower_Wick_ATR': lower_wick / atr,
                                    }

                                    # Fuse Macro State (O(1) Memory Lookup)
                                    with macro_lock:
                                        # Normalize distances with ATR
                                        mic_r = macro_cache.get('Raw_Mic_R', close_p)
                                        mic_s = macro_cache.get('Raw_Mic_S', close_p)
                                        sec_r = macro_cache.get('Raw_Sec_R', close_p)
                                        sec_s = macro_cache.get('Raw_Sec_S', close_p)
                                        ter_r = macro_cache.get('Raw_Ter_R', close_p)
                                        ter_s = macro_cache.get('Raw_Ter_S', close_p)

                                        f_dict['Dist_Micro_R'] = (mic_r - close_p) / atr
                                        f_dict['Dist_Micro_S'] = (close_p - mic_s) / atr
                                        f_dict['Dist_Sec_R'] = (sec_r - close_p) / atr
                                        f_dict['Dist_Sec_S'] = (close_p - sec_s) / atr
                                        f_dict['Dist_Ter_R'] = (ter_r - close_p) / atr
                                        f_dict['Dist_Ter_S'] = (close_p - ter_s) / atr
                                        f_dict['Stoch_State_M1'] = macro_cache.get('Stoch_State_M1', 0.0)
                                        f_dict['Raw_Stoch_K'] = macro_cache.get('Raw_Stoch_K', 0.5)

                                    # Predict

                                    f_dict['Open'] = open_p
                                    f_dict['High'] = high_p
                                    f_dict['Low'] = low_p
                                    f_dict['Close'] = close_p
                                    f_dict['Bid'] = tick_data.get('bid', close_p)
                                    f_dict['Ask'] = tick_data.get('ask', close_p)
                                    # Extract time from the last tick in the bar
                                    f_dict['Time'] = current_bar_ticks[-1].get('time', time.time())
                                    sig, pl, ps, pn = evaluate_tick_state(self.clf, f_dict)

                                    # Send back to EA
                                    msg = f"PRED|{sig}|{pl:.4f}|{ps:.4f}|{pn:.4f}\n"
                                    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 🔥 DOLLAR BAR PREDICTION GENERATED! {msg}")
                                    try:
                                        client.sendall(msg.encode('utf-8'))
                                    except Exception as e:
                                        print(f"[TICK] Error sending prediction: {e}")
                                        break

                                    # Reset bar
                                    current_dollar_volume = 0.0
                                    current_bar_ticks = []
                                else:
                                    # Throttle the PING to prevent overwhelming EA buffer
                                    if len(current_bar_ticks) % 10 == 0:
                                        try:
                                            client.sendall("PING|0|0.0|0.0|0.0\n".encode('utf-8'))
                                        except:
                                            pass
                    except Exception as inner_e:
                        print(f"[TICK] Read error: {inner_e}")
                        break

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
