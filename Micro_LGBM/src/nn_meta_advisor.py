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

    # In a real scenario, you would load pre-trained weights.
    # For now, we initialize an untrained model (random weights) just to establish the pipeline.
    model = MetaAdvisorNN()
    model.eval()

    # 2. Connect to the LGBM Copilot's ZMQ Publisher
    context = zmq.Context()
    subscriber = context.socket(zmq.SUB)
    subscriber.connect("tcp://127.0.0.1:5557")
    subscriber.setsockopt_string(zmq.SUBSCRIBE, "")

    print("[INFO] ZMQ Subscriber connected to 127.0.0.1:5557")
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

            # Check if this payload contains prediction probabilities
            if 'p_long' in payload and 'p_short' in payload:
                p_long = payload.get('p_long', 0.0)
                p_short = payload.get('p_short', 0.0)
                p_noise = payload.get('p_noise', 1.0)
                lgbm_signal = payload.get('signal', 0)

                # Format inputs for NN (Batch size 1, Features 3)
                inputs = torch.tensor([[p_long, p_short, p_noise]], dtype=torch.float32)

                # Run inference
                with torch.no_grad():
                    logits = model(inputs)
                    probabilities = torch.softmax(logits, dim=1).numpy()[0]

                    # Output classes: 0=Hold, 1=Buy, 2=Sell
                    meta_pred_idx = np.argmax(probabilities)

                    if meta_pred_idx == 0:
                        meta_signal = "HOLD"
                    elif meta_pred_idx == 1:
                        meta_signal = "BUY"
                    else:
                        meta_signal = "SELL"

                # Map LGBM int signal to text for display
                lgbm_str = "HOLD"
                if lgbm_signal == 1: lgbm_str = "BUY"
                if lgbm_signal == -1: lgbm_str = "SELL"

                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{current_time}]")
                print(f"  > LGBM Base Probabilities : L: {p_long*100:.1f}% | S: {p_short*100:.1f}% | N: {p_noise*100:.1f}%")
                print(f"  > LGBM Base Decision      : {lgbm_str}")
                print(f"  > NN Meta-Advisor Decision: {meta_signal} (Confidence: {probabilities[meta_pred_idx]*100:.1f}%)")
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
