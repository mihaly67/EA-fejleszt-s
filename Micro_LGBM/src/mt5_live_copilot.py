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
DOLLAR_BAR_THRESHOLD = 4440000.0 # for MGC
current_dollar_volume = 0.0
current_bar_ticks = []

def initialize_copilot():
    print("=== 🟢 STARTING MT5 ONLINE COPILOT ===")
    print("Loading Pre-Trained V5 Fusion Model...")
    try:
        clf = joblib.load('/home/misi/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl')
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
        self.running = True

    def run(self):
        import glob
        import time
        import os

        print("[MACRO] Starting background task to read MT5 CSV for macro state...")
        # Path to MT5 Files directory
        mt5_dir = '/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/'

        last_file = ""
        last_mtime = 0

        while self.running:
            try:
                # Find the most recently updated Merkava_MGCV26_v1.10_*.csv file
                files = glob.glob(mt5_dir + "Merkava_MGCV26_v1.10_*.csv")
                if not files:
                    time.sleep(2)
                    continue

                latest_file = max(files, key=os.path.getmtime)

                # We simply read the last line of the file to get the most up-to-date state
                with open(latest_file, "r") as f:
                    f.seek(0, 2)
                    size = f.tell()
                    # Go back a bit to grab the last line
                    f.seek(max(size - 1024, 0))
                    lines = f.readlines()
                    if len(lines) > 1:
                        last_line = lines[-1]
                        parts = last_line.split(",")

                        # Headers: Time,TickMSC,...,Mic_P,Mic_R,Mic_S,Sec_P,Sec_R,Sec_S,Ter_P,Ter_R,Ter_S,...,Stoch_K
                        # Indices (0-based):
                        # 23 = Mic_R, 24 = Mic_S
                        # 26 = Sec_R, 27 = Sec_S
                        # 29 = Ter_R, 30 = Ter_S
                        # 36 = Stoch_K

                        if len(parts) > 40:
                            try:
                                mic_r = float(parts[23])
                                mic_s = float(parts[24])
                                sec_r = float(parts[26])
                                sec_s = float(parts[27])
                                ter_r = float(parts[29])
                                ter_s = float(parts[30])
                                stoch_k = float(parts[36])

                                # Convert to Distances and Stoch State (as done in offline feature fusion)
                                # The current price for distance can be the Bid price from the same line (Index 5)
                                current_price = float(parts[5])

                                # Need an ATR proxy. We will just use the ATR from the tick receiver for now or approximate.
                                # Actually, distance is usually normalized by ATR. We can leave it un-normalized here and let the tick receiver normalize it before passing to the model, OR we normalize here if we have ATR.
                                # The offline script: df['Dist_Micro_R'] = (df['Micro_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
                                # Let's store raw values in cache and let TickReceiver normalize them when it evaluates the tick state, since TickReceiver calculates ATR_Micro!

                                with macro_lock:
                                    macro_cache['Raw_Mic_R'] = mic_r
                                    macro_cache['Raw_Mic_S'] = mic_s
                                    macro_cache['Raw_Sec_R'] = sec_r
                                    macro_cache['Raw_Sec_S'] = sec_s
                                    macro_cache['Raw_Ter_R'] = ter_r
                                    macro_cache['Raw_Ter_S'] = ter_s
                                    macro_cache['Current_Macro_Price'] = current_price

                                    # Stoch_State_M1 = (stoch_k - 50.0) / 50.0
                                    macro_cache['Stoch_State_M1'] = (stoch_k - 50.0) / 50.0
                            except ValueError:
                                pass
            except Exception as e:
                pass

            time.sleep(1.0) # Check every 1 second


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
            tick_vol = 1.0 # 1 tick = 1 volume unit to prevent instant threshold overflow from resting DOM sizes
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
                    data = client.recv(65536)
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

                                # Predict

                                sig, pl, ps, pn = evaluate_tick_state(self.clf, f_dict)

                                # Send back to EA
                                msg = f"PRED|{sig}|{pl:.4f}|{ps:.4f}|{pn:.4f}\n"
                                try:
                                    client.sendall(msg.encode('utf-8'))
                                except Exception as e:
                                    print(f"[TICK] Error sending prediction: {e}")
                                    self.running = False

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
