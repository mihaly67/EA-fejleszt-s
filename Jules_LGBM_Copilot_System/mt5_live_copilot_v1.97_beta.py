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
    'Stoch_State_M1': 0.0,
    'pos_types': [0],
    'pos_prices': [0.0]
}
macro_lock = threading.Lock()

zmq_context = zmq.Context()
zmq_publisher = zmq_context.socket(zmq.PUB)
zmq_publisher.bind("tcp://0.0.0.0:5557")

signal_history = collections.deque(maxlen=3)

# Globals for Dollar Bars
DOLLAR_BAR_THRESHOLD = 444000.0 # Match exactly with Prado logic!
latest_prob = {'p_long': 0.0, 'p_short': 0.0, 'p_noise': 0.0, 'signal': 0, 'stable': False}
prob_lock = threading.Lock() # Thread safety for latest_prob
current_dollar_volume = 0.0
current_bar_ticks = []

# Persistent High/Low/Open for O(1) tick aggregation
bar_open = 0.0
bar_high = 0.0
bar_low = 0.0

def initialize_copilot():
    print("=== 🟢 STARTING MT5 ONLINE COPILOT ===")
    print("Loading Pre-Trained V5 Fusion Model...")
    try:
        # Load the model from the adjacent 'models' directory
        current_dir = os.path.dirname(os.path.abspath(__file__))
        model_path = os.path.join(current_dir, 'models', 'lgbm_model_fusion_v5_tuned.pkl')
        print(f"Looking for model at: {model_path}")
        clf = joblib.load(model_path)
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

    # Fast Inference without Pandas Overhead
    feature_values = []
    for f in features:
        feature_values.append(current_features_dict.get(f, 0.0))

    X_eval = np.array([feature_values])
    probs = clf.predict_proba(X_eval)[0]

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
        "pos_types": current_features_dict.get('pos_types', [0]),
        "pos_prices": current_features_dict.get('pos_prices', [0.0]),
        "res_micro": macro_cache.get('Raw_Mic_R', current_price),
        "sup_micro": macro_cache.get('Raw_Mic_S', current_price),
        "res_sec": macro_cache.get('Raw_Sec_R', current_price),
        "sup_sec": macro_cache.get('Raw_Sec_S', current_price),
        "res_ter": macro_cache.get('Raw_Ter_R', current_price),
        "sup_ter": macro_cache.get('Raw_Ter_S', current_price),
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


class MacroReceiver(threading.Thread):
    def __init__(self, host='0.0.0.0', port=5555):
        super().__init__()
        self.host = host
        self.port = port
        self.running = True

        # Note: The Python FullZigZagEngine has been removed.
        # The Copilot now uses the 100% accurate MT5 Pivot levels sent via JSON.

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

                        # Buffer overflow protection
                        if len(buffer) > 1048576: # 1MB limit
                            print("[MACRO] Buffer overflow detected! Truncating.")
                            buffer = buffer[-500000:]

                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            line = line.strip()
                            if not line: continue

                            try:
                                payload = json.loads(line)
                                msg_type = payload.get('type', 'update')

                                if msg_type == 'init':
                                    # Initialization logic handled primarily by the EA sending the pivot data.
                                    # Since Python no longer calculates ZigZag, we just acknowledge connection.
                                    print(f"[MACRO] Received init signal from EA.")

                                elif msg_type == 'update':
                                    t = payload.get('time')
                                    h = payload.get('high')
                                    l = payload.get('low')
                                    price = payload.get('price', h)
                                    stoch_k = payload.get('stoch_k', 50.0)

                                    # Extract real MT5 ZigZag Pivots sent by the EA (v2.2)
                                    mic_r = payload.get('mic_r', price)
                                    mic_s = payload.get('mic_s', price)
                                    sec_r = payload.get('sec_r', price)
                                    sec_s = payload.get('sec_s', price)
                                    ter_r = payload.get('ter_r', price)
                                    ter_s = payload.get('ter_s', price)

                                    with macro_lock:
                                        macro_cache['Stoch_State_M1'] = (stoch_k - 50.0) / 50.0
                                        macro_cache['Raw_Stoch_K'] = stoch_k / 100.0 # Standard 0.0-1.0 scale
                                        macro_cache['Raw_Mic_R'] = mic_r
                                        macro_cache['Raw_Mic_S'] = mic_s
                                        macro_cache['Raw_Sec_R'] = sec_r
                                        macro_cache['Raw_Sec_S'] = sec_s
                                        macro_cache['Raw_Ter_R'] = ter_r
                                        macro_cache['Raw_Ter_S'] = ter_s
                                        macro_cache['Current_Macro_Price'] = price

                                    # Continuous HUD Broadcast (M1 Data)
                                    with macro_lock:
                                        current_pos_types = macro_cache.get('pos_types', [0])
                                        current_pos_prices = macro_cache.get('pos_prices', [0.0])

                                    with prob_lock:
                                        current_signal = latest_prob['signal']
                                        current_plong = latest_prob['p_long']
                                        current_pshort = latest_prob['p_short']
                                        current_pnoise = latest_prob['p_noise']
                                        current_stable = latest_prob['stable']

                                    hud_data = {
                                        "timestamp": t,
                                        "price": price,
                                        "open": price, # Approximate Open for smooth UI
                                        "high": h,
                                        "low": l,
                                        "close": price,
                                        "bid": price,
                                        "ask": price,
                                        "pos_types": current_pos_types,
                                        "pos_prices": current_pos_prices,
                                        "stoch_k": stoch_k,
                                        "signal": current_signal,
                                        "p_long": current_plong,
                                        "p_short": current_pshort,
                                        "p_noise": current_pnoise,
                                        "is_stable": current_stable
                                    }
                                    try:
                                        zmq_publisher.send_string(f"HUD {json.dumps(hud_data)}")
                                    except Exception as e:
                                        print(f"[ZMQ] Error sending MACRO hud data: {e}")

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

            # EA sends comma separated strings for multiple positions: "1,-1" and "77100.5,77150.0"
            if len(parts) > 4 and parts[4] != "" and parts[4] != "0":
                pos_types = [int(x) for x in parts[4].split(',')]
            else:
                pos_types = [0]

            if len(parts) > 5 and parts[5] != "" and parts[5] != "0.0":
                pos_prices = [float(x) for x in parts[5].split(',')]
            else:
                pos_prices = [0.0]

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
                'pos_types': pos_types,
                'pos_prices': pos_prices,
                'time': time_msc
            }
        except Exception as e:
            print(f"Error parsing tick parts: {e}")
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
                last_hud_send = time.time()

                # We need to compute simple moving features across closed bars
                bar_closes = collections.deque(maxlen=15)

                while self.running:
                    try:
                        data = client.recv(65536)
                        if not data:
                            print("[TICK] Connection closed by EA.")
                            break
                        buffer += data.decode('utf-8', errors='ignore')

                        # Buffer overflow protection
                        if len(buffer) > 1048576: # 1MB limit
                            print("[TICK] Buffer overflow detected! Truncating.")
                            buffer = buffer[-500000:]

                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)

                            if line.startswith("TICK|"):
                                parts = line.split("|")
                                tick_data = self.extract_dom_features(parts)

                                if not tick_data:
                                    continue

                                # Globally cache the latest position state so other threads (MacroReceiver) can send it
                                with macro_lock:
                                    macro_cache['pos_types'] = tick_data.get('pos_types', [0])
                                    macro_cache['pos_prices'] = tick_data.get('pos_prices', [0.0])

                                # O(1) Streaming bar aggregation without Pandas
                                global bar_open, bar_high, bar_low

                                if not current_bar_ticks:
                                    # Start new bar
                                    bar_open = tick_data['mid_price']
                                    bar_high = tick_data['mid_price']
                                    bar_low = tick_data['mid_price']
                                else:
                                    # Update existing bar
                                    p = tick_data['mid_price']
                                    if p > bar_high: bar_high = p
                                    if p < bar_low: bar_low = p

                                current_bar_ticks.append(tick_data)
                                current_dollar_volume += tick_data['dollar_vol']

                                if current_dollar_volume >= DOLLAR_BAR_THRESHOLD:
                                    # Bar Closed!
                                    open_p = bar_open
                                    high_p = bar_high
                                    low_p = bar_low
                                    close_p = tick_data['mid_price']

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
                                    f_dict['pos_types'] = tick_data.get('pos_types', [0])
                                    f_dict['pos_prices'] = tick_data.get('pos_prices', [0.0])
                                    # Extract time from the last tick in the bar
                                    f_dict['Time'] = current_bar_ticks[-1].get('time', time.time())
                                    sig, pl, ps, pn = evaluate_tick_state(self.clf, f_dict)
                                    global latest_prob
                                    with prob_lock:
                                        latest_prob['signal'] = sig
                                        latest_prob['p_long'] = float(pl)
                                        latest_prob['p_short'] = float(ps)
                                        latest_prob['p_noise'] = float(pn)
                                        latest_prob['stable'] = (len(signal_history) == 3 and len(set(signal_history)) == 1)

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
                                    # Throttled HUD Update (Targeting ~60 FPS / 0.016s) to prevent UI/ZMQ freezing
                                    now = time.time()
                                    if now - last_hud_send >= 0.016:
                                        # Send real-time TICK updates to HUD to build the current candle dynamically
                                        open_p_tmp = bar_open
                                        high_p_tmp = bar_high
                                        low_p_tmp = bar_low
                                        close_p_tmp = tick_data['mid_price']

                                        with prob_lock:
                                            current_signal = latest_prob['signal']
                                            current_plong = latest_prob['p_long']
                                            current_pshort = latest_prob['p_short']
                                            current_pnoise = latest_prob['p_noise']
                                            current_stable = latest_prob['stable']

                                        hud_data = {
                                            "timestamp": tick_data.get('time', time.time()),
                                            "price": close_p_tmp,
                                            "open": open_p_tmp,
                                            "high": high_p_tmp,
                                            "low": low_p_tmp,
                                            "close": close_p_tmp,
                                            "bid": tick_data.get('bid', close_p_tmp),
                                            "ask": tick_data.get('ask', close_p_tmp),
                                            "pos_types": tick_data.get('pos_types', [0]),
                                            "pos_prices": tick_data.get('pos_prices', [0.0]),
                                            "res_micro": macro_cache.get('Raw_Mic_R', close_p_tmp),
                                            "sup_micro": macro_cache.get('Raw_Mic_S', close_p_tmp),
                                            "res_sec": macro_cache.get('Raw_Sec_R', close_p_tmp),
                                            "sup_sec": macro_cache.get('Raw_Sec_S', close_p_tmp),
                                            "res_ter": macro_cache.get('Raw_Ter_R', close_p_tmp),
                                            "sup_ter": macro_cache.get('Raw_Ter_S', close_p_tmp),
                                            "stoch_k": macro_cache.get('Raw_Stoch_K', 0.5) * 100.0,
                                            "signal": current_signal,
                                            "p_long": current_plong,
                                            "p_short": current_pshort,
                                            "p_noise": current_pnoise,
                                            "is_stable": current_stable
                                        }
                                        try:
                                            zmq_publisher.send_string(f"HUD {json.dumps(hud_data)}")
                                            last_hud_send = now
                                        except Exception as e:
                                            print(f"[ZMQ] Error sending TICK HUD data: {e}")

                                    # Throttle the PING to prevent overwhelming EA buffer
                                    if len(current_bar_ticks) % 10 == 0:
                                        try:
                                            client.sendall("PING|0|0.0|0.0|0.0\n".encode('utf-8'))
                                        except Exception as e:
                                            print(f"[TICK] PING transmission error: {e}")
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
