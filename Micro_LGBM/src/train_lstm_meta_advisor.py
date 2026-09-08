import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import os
from nn_meta_model import MetaAdvisorLSTM

def create_sequences(data, labels, seq_length):
    xs = []
    ys = []
    for i in range(len(data) - seq_length):
        x = data[i + 1 : i + seq_length + 1].copy()
        y = labels[i + seq_length]
        if y != -1:
            xs.append(x)
            ys.append(y)
    return np.array(xs), np.array(ys)

def train_standalone_lstm():
    # Use the strict dataset containing raw features and the Triple Barrier Target_Label
    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/labeled_dollar_bars_v5_strict.csv"
    print(f"Loading strict dollar bars from {data_path}...")
    df = pd.read_csv(data_path).dropna().reset_index(drop=True)

    # Define an independent set of features for the LSTM (No LightGBM probabilities)
    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    # Ensure features exist
    for f in lstm_features:
        if f not in df.columns:
            df[f] = 0.0

    X_lstm_raw = df[lstm_features].fillna(0).values
    X_lstm_mean = np.mean(X_lstm_raw, axis=0)
    X_lstm_std = np.std(X_lstm_raw, axis=0)

    # Save the independent scaler
    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_mean.npy", X_lstm_mean)
    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_std.npy", X_lstm_std)

    X_lstm_norm = (X_lstm_raw - X_lstm_mean) / (X_lstm_std + 1e-8)

    # Extract original targets: -1 (Short), 0 (Noise), 1 (Long)
    # Shift them to 0, 1, 2 for PyTorch CrossEntropyLoss
    original_targets = df['Target_Label'].values
    shifted_targets = original_targets + 1

    SEQ_LENGTH = 20
    X_seq, y_seq = create_sequences(X_lstm_norm, shifted_targets, SEQ_LENGTH)

    print("Class balance in sequences:")
    unique, counts = np.unique(y_seq, return_counts=True)
    class_counts = dict(zip(unique, counts))
    print(class_counts)

    # Calculate Class Weights for CrossEntropyLoss
    total = sum(counts)
    # weights = total / (num_classes * count)
    class_weights = [total / (3.0 * class_counts.get(i, 1)) for i in range(3)]
    print(f"Class Weights -> Short (0): {class_weights[0]:.4f}, Noise (1): {class_weights[1]:.4f}, Long (2): {class_weights[2]:.4f}")

    X_tensor = torch.tensor(X_seq, dtype=torch.float32)
    y_tensor = torch.tensor(y_seq, dtype=torch.long)

    dataset = TensorDataset(X_tensor, y_tensor)

    train_size = int(0.8 * len(dataset))
    val_size = len(dataset) - train_size
    train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

    train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\n🚀 INITIALIZING STANDALONE LSTM TRAINING ON: {device} 🚀")

    model = MetaAdvisorLSTM(input_dim=len(lstm_features), output_dim=3).to(device)

    # CrossEntropyLoss automatically applies Softmax and handles integer targets
    weight_tensor = torch.tensor(class_weights, dtype=torch.float32).to(device)
    criterion = nn.CrossEntropyLoss(weight=weight_tensor)
    optimizer = optim.Adam(model.parameters(), lr=0.00118)

    EPOCHS = 15

    for epoch in range(EPOCHS):
        model.train()
        train_loss = 0.0
        for batch_X, batch_y in train_loader:
            batch_X, batch_y = batch_X.to(device), batch_y.to(device)
            optimizer.zero_grad()

            outputs = model(batch_X) # Logits shape: (batch, 3)
            loss = criterion(outputs, batch_y)

            loss.backward()
            optimizer.step()
            train_loss += loss.item() * batch_X.size(0)

        train_loss /= len(train_loader.dataset)

        model.eval()
        val_loss = 0.0
        correct = 0
        total_val = 0
        with torch.no_grad():
            for batch_X, batch_y in val_loader:
                batch_X, batch_y = batch_X.to(device), batch_y.to(device)
                outputs = model(batch_X)
                loss = criterion(outputs, batch_y)
                val_loss += loss.item() * batch_X.size(0)

                # Prediction is the class with highest logit
                _, predicted = torch.max(outputs.data, 1)
                total_val += batch_y.size(0)
                correct += (predicted == batch_y).sum().item()

        val_loss /= len(val_loader.dataset)
        accuracy = 100 * correct / total_val
        print(f"Epoch {epoch+1}/{EPOCHS} | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val Acc: {accuracy:.2f}%")

    save_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_advisor.pth"
    torch.save(model.state_dict(), save_path)
    print(f"\n✅ Standalone LSTM successfully trained and saved to {save_path}")

if __name__ == "__main__":
    train_standalone_lstm()
