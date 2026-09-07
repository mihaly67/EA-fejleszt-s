import sys
sys.path.append("/home/Jules/LGBM_mlops/Micro_LGBM/src")
import pandas as pd
import numpy as np
import torch
import os
from nn_meta_model import MetaAdvisorLSTM
import matplotlib.pyplot as plt

def create_sequences(data, labels, seq_length):
    xs = []
    ys = []
    for i in range(len(data) - seq_length):
        x = data[i + 1 : i + seq_length + 1].copy()
        y = labels[i + seq_length]
        if y != -1:
            seq_min = np.min(x[:, 0:4])
            seq_max = np.max(x[:, 0:4])
            if seq_max > seq_min:
                x[:, 0:4] = (x[:, 0:4] - seq_min) / (seq_max - seq_min)
            else:
                x[:, 0:4] = 0.0
            xs.append(x)
            ys.append(y)
    return np.array(xs), np.array(ys)

def get_feature_importance():
    print("==================================================")
    print("🧠 LSTM META-ADVISOR PERMUTATION IMPORTANCE 🧠")
    print("==================================================")

    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/meta_labeled_fused_v5_mom.csv"
    print(f"Loading dataset from {data_path}...")
    df = pd.read_csv(data_path)

    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'P_Long', 'P_Short', 'P_Noise',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    for f in lstm_features:
        if f not in df.columns:
            df[f] = 0.0

    X_lstm_raw = df[lstm_features].fillna(0).values

    scaler_mean_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_mean.npy"
    scaler_std_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_std.npy"

    X_lstm_mean = np.load(scaler_mean_path)
    X_lstm_std = np.load(scaler_std_path)

    X_lstm_norm = (X_lstm_raw - X_lstm_mean) / (X_lstm_std + 1e-8)

    meta_labels = df['Meta_Label'].values

    SEQ_LENGTH = 20
    X_seq, y_seq = create_sequences(X_lstm_norm, meta_labels, SEQ_LENGTH)

    device = torch.device("cpu")
    model = MetaAdvisorLSTM(input_dim=len(lstm_features)).to(device)
    model.load_state_dict(torch.load("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth", map_location=device))
    model.eval()

    # Calculate baseline accuracy
    X_tensor = torch.tensor(X_seq, dtype=torch.float32)
    y_tensor = torch.tensor(y_seq, dtype=torch.float32).unsqueeze(1)

    with torch.no_grad():
        outputs = model(X_tensor)
        predicted = (outputs > 0.5).float()
        baseline_correct = (predicted == y_tensor).sum().item()
        baseline_acc = baseline_correct / len(y_tensor)

    print(f"\nBaseline Accuracy on dataset: {baseline_acc*100:.2f}%\n")

    # Perform Permutation Importance
    # For each feature, we randomly shuffle it across all sequences and see how much the accuracy drops.
    importance_scores = {}

    print("Calculating feature importance (Permutation Method)...")
    for i, feature_name in enumerate(lstm_features):
        X_shuffled = X_seq.copy()

        # Shuffle just this feature's column across all sequences and timesteps
        # We flatten, shuffle, and reshape
        feat_vals = X_shuffled[:, :, i].flatten()
        np.random.shuffle(feat_vals)
        X_shuffled[:, :, i] = feat_vals.reshape((X_shuffled.shape[0], X_shuffled.shape[1]))

        X_shuffled_tensor = torch.tensor(X_shuffled, dtype=torch.float32)

        with torch.no_grad():
            outputs = model(X_shuffled_tensor)
            predicted = (outputs > 0.5).float()
            shuffled_correct = (predicted == y_tensor).sum().item()
            shuffled_acc = shuffled_correct / len(y_tensor)

        drop = baseline_acc - shuffled_acc
        importance_scores[feature_name] = drop
        print(f"Feature: {feature_name:<20} | Acc Drop: {drop*100:+.2f}%")

    # Sort and plot
    importances = pd.Series(importance_scores).sort_values(ascending=True)

    # Save to CSV for text output
    importances.to_csv("/home/Jules/LGBM_mlops/Micro_LGBM/src/lstm_feature_importance.csv")

    plt.figure(figsize=(12, 10))
    # Colors: Green for important (positive drop), Red for useless/harmful (negative drop)
    colors = ['red' if val < 0 else 'forestgreen' for val in importances.values]
    importances.plot(kind='barh', color=colors)
    plt.title("LSTM Meta-Advisor Permutation Importance\n(Drop in Accuracy when feature is scrambled)")
    plt.xlabel("Accuracy Drop (Higher = More Important)")
    plt.tight_layout()
    plt.savefig("/home/Jules/LGBM_mlops/Micro_LGBM/src/lstm_importance_heatmap.png")
    print("\n✅ Importance analysis saved to lstm_feature_importance.csv and lstm_importance_heatmap.png")

if __name__ == "__main__":
    get_feature_importance()
