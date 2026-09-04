import torch
import torch.nn as nn
import torch.optim as optim
import zmq
import json
import numpy as np
from datetime import datetime

# 1. Define the Neural Network Architecture (Meta-Learner)
# It takes 3 inputs (P_Long, P_Short, P_Noise from LGBM)
# and outputs 3 logits (0 = Hold, 1 = Buy, 2 = Sell)
class MetaAdvisorNN(nn.Module):
    def __init__(self):
        super(MetaAdvisorNN, self).__init__()
        self.fc1 = nn.Linear(3, 16)
        self.relu1 = nn.ReLU()
        self.fc2 = nn.Linear(16, 8)
        self.relu2 = nn.ReLU()
        self.out = nn.Linear(8, 3)  # 3 output classes

    def forward(self, x):
        x = self.fc1(x)
        x = self.relu1(x)
        x = self.fc2(x)
        x = self.relu2(x)
        x = self.out(x)
        return x

def main():
    print("==================================================")
    print("🚀 STARTING NN META-ADVISOR (LGBM SUPERVISOR) 🚀")
    print("==================================================")

    # Update for LSTM:
    # Instead of an MLP, we use the MetaAdvisorLSTM which expects sequential data.
    from nn_meta_model import MetaAdvisorLSTM
    import os

    # Needs to match the training configuration
    lstm_features = [
        'Open', 'High', 'Low', 'Close', 'Total_Volume',
        'M5_RSI_14', 'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed'
    ]
    SEQ_LENGTH = 20

    model = MetaAdvisorLSTM(input_dim=len(lstm_features))
    model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    if os.path.exists(model_path):
        model.load_state_dict(torch.load(model_path, map_location=torch.device('cpu')))
        print(f"[INFO] Loaded trained LSTM weights from {model_path}")
    else:
        print("[WARNING] Untrained LSTM initialized. No weights found.")

    model.eval()

    # We need a buffer to store the last N dollar bars
    from collections import deque
    sequence_buffer = deque(maxlen=SEQ_LENGTH)

    # 2. Connect to the LGBM Copilot's ZMQ Publisher
    context = zmq.Context()
    subscriber = context.socket(zmq.SUB)
    subscriber.connect("tcp://127.0.0.1:5557")
    subscriber.setsockopt_string(zmq.SUBSCRIBE, "")

    # 3. ZMQ Publisher to send verdicts back to HUD/EA on port 5558
    publisher = context.socket(zmq.PUB)
    publisher.bind("tcp://0.0.0.0:5558")

    print("[INFO] ZMQ Subscriber connected to 127.0.0.1:5557")
    print("[INFO] ZMQ Publisher bound to 0.0.0.0:5558")
    print("[INFO] Waiting for LGBM probabilities...\n")

    while True:
        try:
            message = subscriber.recv_string()

            # The publisher sends: "HUD {"p_long": ...}" -> Strip the first 4 chars
            if message.startswith("HUD "):
                json_str = message[4:]
            else:
                json_str = message

            payload = json.loads(json_str)

            # To feed the LSTM, we need to extract the raw features from the HUD payload
            if 'close' in payload and 'open' in payload:
                # Build the current feature vector for the LSTM
                # Note: the HUD publisher in mt5_live_copilot doesn't publish M5_RSI_14 etc directly.
                # In a full production setup, the publisher must be updated to send all `lstm_features`.
                # For this baseline implementation, we use safe gets to prevent crashes.
                current_features = [
                    payload.get('open', 0.0),
                    payload.get('high', 0.0),
                    payload.get('low', 0.0),
                    payload.get('close', 0.0),
                    payload.get('Total_Volume', 0.0), # Assuming this gets added
                    payload.get('M5_RSI_14', 50.0),
                    payload.get('M15_RSI_14', 50.0),
                    payload.get('M30_RSI_14', 50.0),
                    payload.get('Price_Velocity', 0.0),
                    payload.get('Tick_Speed', 0.0)
                ]

                sequence_buffer.append(current_features)

                if len(sequence_buffer) == SEQ_LENGTH and 'p_long' in payload:
                    p_long = payload.get('p_long', 0.0)
                    p_short = payload.get('p_short', 0.0)
                    p_noise = payload.get('p_noise', 1.0)
                    lgbm_signal = payload.get('signal', 0)

                    # Convert sequence to tensor: Shape (Batch=1, Seq=20, Features=10)
                    seq_array = np.array(sequence_buffer)
                    # Normalize (Optional: apply same normalization as training)
                    seq_mean = np.mean(seq_array, axis=0)
                    seq_std = np.std(seq_array, axis=0)
                    seq_norm = (seq_array - seq_mean) / (seq_std + 1e-8)

                    inputs = torch.tensor([seq_norm], dtype=torch.float32)

                    # Run LSTM Inference
                    with torch.no_grad():
                        out_prob = model(inputs).item()

                        # 0.0 = False Signal (Reject), 1.0 = True Signal (Accept)
                        if out_prob > 0.5:
                            meta_signal = "VERIFIED (True)"
                            color = "🟢"
                        else:
                            meta_signal = "REJECTED (False)"
                            color = "🔴"

                    # Map LGBM int signal to text for display
                    lgbm_str = "HOLD"
                    if lgbm_signal == 1: lgbm_str = "BUY"
                    if lgbm_signal == -1: lgbm_str = "SELL"

                    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{current_time}]")
                    print(f"  > LGBM Base Probabilities : L: {p_long*100:.1f}% | S: {p_short*100:.1f}% | N: {p_noise*100:.1f}%")
                    print(f"  > LGBM Base Decision      : {lgbm_str}")
                    if lgbm_str != "HOLD":
                        print(f"  > LSTM Meta-Verdict       : {color} {meta_signal} (Confidence: {out_prob*100:.1f}%)")
                        # Broadcast to HUD/EA
                        verdict_payload = {
                            "type": "meta_advisor",
                            "meta_verdict": f"{color} {meta_signal}",
                            "meta_prob": float(out_prob)
                        }
                        publisher.send_string(f"META {json.dumps(verdict_payload)}")
                    else:
                        print(f"  > LSTM Meta-Verdict       : WAITING (No LGBM signal to verify)")
                        verdict_payload = {
                            "type": "meta_advisor",
                            "meta_verdict": "WAITING",
                            "meta_prob": 0.0
                        }
                        publisher.send_string(f"META {json.dumps(verdict_payload)}")

                    print("-" * 50)

        except json.JSONDecodeError:
            pass
        except KeyboardInterrupt:
            print("\n[INFO] Exiting...")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()
