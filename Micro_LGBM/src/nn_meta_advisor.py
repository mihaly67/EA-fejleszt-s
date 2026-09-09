import zmq
import json
import torch
import numpy as np
import collections
import time
import os

# Instead of an MLP, we use the MetaAdvisorLSTM which expects sequential data.
from nn_meta_model import MetaAdvisorLSTM

def start_meta_advisor_service():
    print("==========================================")
    print("🤖 STARTING LSTM META-ADVISOR SERVICE 🤖")
    print("==========================================")

    # LSTM specific settings
    SEQ_LENGTH = 20
    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'P_Long', 'P_Short', 'P_Noise',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    # Initialize the model
    model = MetaAdvisorLSTM(input_dim=len(lstm_features))
    model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    try:
        model.load_state_dict(torch.load(model_path, map_location=torch.device('cpu')))
        print(f"[INFO] Loaded trained LSTM weights from {model_path}")
    except FileNotFoundError:
        print(f"[ERROR] Could not find {model_path}. Please train it first.")
        return

    model.eval()

    # Load scaling parameters generated during training
    scaler_mean_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_mean.npy"
    scaler_std_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_std.npy"
    try:
        X_lstm_mean = np.load(scaler_mean_path)
        X_lstm_std = np.load(scaler_std_path)
        print("[INFO] Loaded global LSTM scalers for live sequence normalization.")
    except FileNotFoundError:
        print("[WARNING] Missing global scalers! Falling back to 0 mean / 1 std. Inference will be inaccurate.")
        X_lstm_mean = np.zeros(len(lstm_features))
        X_lstm_std = np.ones(len(lstm_features))

    # We need a rolling buffer to build sequences
    feature_buffer = collections.deque(maxlen=SEQ_LENGTH)

    context = zmq.Context()

    # Subscribe to the tick publisher from the live copilot (Port 5557)
    sub_socket = context.socket(zmq.SUB)
    sub_socket.connect("tcp://127.0.0.1:5557")
    sub_socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

    # Publish verdicts (Port 5558)
    pub_socket = context.socket(zmq.PUB)
    pub_socket.bind("tcp://0.0.0.0:5558")

    print(f"[INFO] LSTM Meta-Advisor listening on 5557 (SUB) and publishing on 5558 (PUB)...\n")

    while True:
        try:
            message = sub_socket.recv_string()
            payload = message[4:] # Strip "HUD "
            data = json.loads(payload)

            f_dict = data.get("features", {})
            current_bar_time = f_dict.get("Bar_Time_Seconds", None)

            if current_bar_time is None:
                continue

            current_total_volume = f_dict.get('Total_Volume', 0)

            if not hasattr(start_meta_advisor_service, "prev_vol"):
                start_meta_advisor_service.prev_vol = -1

            is_new_bar = False
            if current_total_volume < start_meta_advisor_service.prev_vol:
                is_new_bar = True

            # Inject LGBM's current probabilities and signals into the feature vector!
            # The HUD payload includes signal and probabilities from LightGBM
            f_dict['LGBM_Signal'] = data.get('signal', 0)
            f_dict['P_Long'] = data.get('p_long', 0.0)
            f_dict['P_Short'] = data.get('p_short', 0.0)
            f_dict['P_Noise'] = data.get('p_noise', 0.0)

            current_vector = []
            for f in lstm_features:
                current_vector.append(f_dict.get(f, 0.0))

            if is_new_bar or len(feature_buffer) == 0:
                feature_buffer.append(current_vector)
            else:
                feature_buffer[-1] = current_vector

            start_meta_advisor_service.prev_vol = current_total_volume

            meta_signal = "WAITING"
            out_prob = 0.0

            lgbm_signal = data.get('signal', 0)

            if len(feature_buffer) == SEQ_LENGTH:
                if lgbm_signal != 0:
                    seq_array = np.array(feature_buffer)
                    seq_norm = (seq_array - X_lstm_mean) / (X_lstm_std + 1e-8)
                    seq_tensor = torch.tensor(seq_norm, dtype=torch.float32).unsqueeze(0)

                    with torch.no_grad():
                        out_prob = model(seq_tensor).item()

                    meta_signal = "Verified" if out_prob > 0.5 else "Rejected"

                    color = "\033[92m" if meta_signal == "Verified" else "\033[91m"
                    print(f"[{time.strftime('%H:%M:%S')}] LGBM Signal: {lgbm_signal}")
                    print(f"  > LSTM Meta-Verdict       : {color} {meta_signal} (Confidence: {out_prob*100:.1f}%)\033[0m")
                else:
                    meta_signal = "None"
            else:
                if lgbm_signal != 0:
                    print(f"[{time.strftime('%H:%M:%S')}] LGBM Signal: {lgbm_signal}")
                    print(f"  > LSTM Meta-Verdict       : WAITING (Buffering: {len(feature_buffer)}/{SEQ_LENGTH})")

            # Broadcast Verdict to GUI
            meta_payload = {
                "lgbm_signal": lgbm_signal,
                "meta_verdict": meta_signal, # "Verified", "Rejected", "None", or "WAITING"
                "meta_confidence": out_prob
            }
            pub_socket.send_string(f"META {json.dumps(meta_payload)}")

        except json.JSONDecodeError:
            print("[ERROR] Failed to parse JSON from Copilot.")
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(1)

if __name__ == "__main__":
    start_meta_advisor_service()
