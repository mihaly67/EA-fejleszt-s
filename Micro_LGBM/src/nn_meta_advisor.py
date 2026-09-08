import zmq
import json
import torch
import numpy as np
import collections
import time
import os

from nn_meta_model import MetaAdvisorLSTM

def start_standalone_advisor_service():
    print("==========================================")
    print("🤖 STARTING STANDALONE LSTM SERVICE 🤖")
    print("==========================================")

    # Same independent feature set used in training
    SEQ_LENGTH = 20
    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    model = MetaAdvisorLSTM(input_dim=len(lstm_features), output_dim=3)
    model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_advisor.pth"
    try:
        model.load_state_dict(torch.load(model_path, map_location=torch.device('cpu')))
        print(f"[INFO] Loaded trained LSTM weights from {model_path}")
    except FileNotFoundError:
        print(f"[ERROR] Could not find {model_path}. Please train it first.")
        return

    model.eval()

    scaler_mean_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_mean.npy"
    scaler_std_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_std.npy"
    try:
        X_lstm_mean = np.load(scaler_mean_path)
        X_lstm_std = np.load(scaler_std_path)
        print("[INFO] Loaded LSTM standalone scalers.")
    except FileNotFoundError:
        print("[WARNING] Missing global scalers! Falling back to 0 mean / 1 std. Inference will be inaccurate.")
        X_lstm_mean = np.zeros(len(lstm_features))
        X_lstm_std = np.ones(len(lstm_features))

    feature_buffer = collections.deque(maxlen=SEQ_LENGTH)

    context = zmq.Context()

    # Subscribe to the tick publisher from the live copilot (Port 5557)
    sub_socket = context.socket(zmq.SUB)
    sub_socket.connect("tcp://127.0.0.1:5557")
    sub_socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

    # Publish standalone LSTM signals (Port 5558)
    pub_socket = context.socket(zmq.PUB)
    pub_socket.bind("tcp://0.0.0.0:5558")

    print(f"[INFO] LSTM Standalone Advisor listening on 5557 (SUB) and publishing on 5558 (PUB)...\n")

    # Track the last bar time to avoid tick flooding
    last_bar_time = None

    while True:
        try:
            message = sub_socket.recv_string()
            payload = message[4:] # Strip "HUD "
            data = json.loads(payload)

            f_dict = data.get("features", {})
            current_bar_time = f_dict.get("Bar_Time_Seconds", None)

            if current_bar_time is None:
                continue

            # Only advance the LSTM sequence if a new dollar bar has fully formed
            # We track the 'Total_Volume' to identify unique bars, or bar_time_seconds
            # Since dollar bars are volume/dollar based, their "Bar_Time_Seconds" resets.
            current_total_volume = f_dict.get('Total_Volume', 0)

            # Simple heuristic: If Total_Volume drops, it means a new bar just started
            # OR if it's the very first tick.
            if not hasattr(start_standalone_advisor_service, "prev_vol"):
                start_standalone_advisor_service.prev_vol = -1

            is_new_bar = False
            if current_total_volume < start_standalone_advisor_service.prev_vol:
                is_new_bar = True

            # We update the *current* active bar in the buffer dynamically without advancing,
            # UNLESS a new bar has definitively started.

            current_vector = []
            for f in lstm_features:
                current_vector.append(f_dict.get(f, 0.0))

            if is_new_bar or len(feature_buffer) == 0:
                feature_buffer.append(current_vector)
            else:
                # Update the last element in the buffer with the live tick
                feature_buffer[-1] = current_vector

            start_standalone_advisor_service.prev_vol = current_total_volume

            lstm_signal = 0
            p_short = 0.0
            p_noise = 0.0
            p_long = 0.0

            if len(feature_buffer) == SEQ_LENGTH:
                seq_array = np.array(feature_buffer)
                seq_norm = (seq_array - X_lstm_mean) / (X_lstm_std + 1e-8)

                seq_tensor = torch.tensor(seq_norm, dtype=torch.float32).unsqueeze(0)

                with torch.no_grad():
                    out_logits = model(seq_tensor)
                    probs = torch.softmax(out_logits, dim=1).numpy()[0]

                p_short = float(probs[0])
                p_noise = float(probs[1])
                p_long = float(probs[2])

                # Standalone classification
                pred_idx = np.argmax(probs)
                if pred_idx == 0:
                    lstm_signal = -1
                elif pred_idx == 2:
                    lstm_signal = 1
                else:
                    lstm_signal = 0

                color = "\033[92m" if lstm_signal == 1 else ("\033[91m" if lstm_signal == -1 else "\033[90m")
                print(f"[{time.strftime('%H:%M:%S')}] LSTM Standalone Signal: {color}{lstm_signal}\033[0m | P_Long: {p_long*100:.1f}%, P_Short: {p_short*100:.1f}%, P_Noise: {p_noise*100:.1f}%")            # Broadcast Verdict to GUI (Decoupled completely from LGBM)
            # The HUD expects 'meta_verdict' and prefix 'META'
            meta_signal = "Verified" if lstm_signal == 1 else ("Rejected" if lstm_signal == -1 else "None")
            meta_payload = {
                "lgbm_signal": lstm_signal, # Fallback to satisfy HUD logic
                "meta_verdict": meta_signal,
                "meta_confidence": p_long if lstm_signal == 1 else p_short,
                "lstm_signal": lstm_signal,
                "lstm_p_long": p_long,
                "lstm_p_short": p_short,
                "lstm_p_noise": p_noise
            }
            pub_socket.send_string(f"META {json.dumps(meta_payload)}")

        except json.JSONDecodeError:
            print("[ERROR] Failed to parse JSON from Copilot.")
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(1)

if __name__ == "__main__":
    start_standalone_advisor_service()
