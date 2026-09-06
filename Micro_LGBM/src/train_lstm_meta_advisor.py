import sys
sys.path.append("/home/Jules/LGBM_mlops/Micro_LGBM/src")
import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
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
        x = data[i + 1 : i + seq_length + 1]
        y = labels[i + seq_length]
        if y != -1:
            xs.append(x)
            ys.append(y)
    return np.array(xs), np.array(ys)

def generate_meta_dataset_and_train():
    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/meta_labeled_fused_v5.csv"
    print(f"Loading realistically labeled dollar bars from {data_path}...")
    df = pd.read_csv(data_path)

    lstm_features = [
        'Open', 'High', 'Low', 'Close', 'Total_Volume',
        'M5_RSI_14', 'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed'
    ]

    existing_lstm_features = lstm_features
    for f in existing_lstm_features:
        if f not in df.columns:
            df[f] = 0.0

    X_lstm_raw = df[existing_lstm_features].fillna(0).values
    X_lstm_mean = np.mean(X_lstm_raw, axis=0)
    X_lstm_std = np.std(X_lstm_raw, axis=0)

    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_mean.npy", X_lstm_mean)
    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_std.npy", X_lstm_std)

    X_lstm_norm = (X_lstm_raw - X_lstm_mean) / (X_lstm_std + 1e-8)
    meta_labels = df['Meta_Label'].values

    SEQ_LENGTH = 20
    X_seq, y_seq = create_sequences(X_lstm_norm, meta_labels, SEQ_LENGTH)

    # Check class balance
    print("Class balance in sequences:")
    unique, counts = np.unique(y_seq, return_counts=True)
    print(dict(zip(unique, counts)))

    X_tensor = torch.tensor(X_seq, dtype=torch.float32)
    y_tensor = torch.tensor(y_seq, dtype=torch.float32).unsqueeze(1)

    dataset = TensorDataset(X_tensor, y_tensor)

    train_size = int(0.8 * len(dataset))
    val_size = len(dataset) - train_size
    train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

    train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\n🚀 INITIALIZING LSTM TRAINING ON: {device} 🚀")

    model = MetaAdvisorLSTM(input_dim=len(existing_lstm_features)).to(device)
    criterion = nn.BCELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    EPOCHS = 10

    for epoch in range(EPOCHS):
        model.train()
        train_loss = 0.0
        for batch_X, batch_y in train_loader:
            batch_X, batch_y = batch_X.to(device), batch_y.to(device)
            optimizer.zero_grad()
            outputs = model(batch_X)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * batch_X.size(0)
        train_loss /= len(train_loader.dataset)

        model.eval()
        val_loss = 0.0
        correct = 0
        total = 0
        with torch.no_grad():
            for batch_X, batch_y in val_loader:
                batch_X, batch_y = batch_X.to(device), batch_y.to(device)
                outputs = model(batch_X)
                loss = criterion(outputs, batch_y)
                val_loss += loss.item() * batch_X.size(0)
                predicted = (outputs > 0.5).float()
                total += batch_y.size(0)
                correct += (predicted == batch_y).sum().item()

        val_loss /= len(val_loader.dataset)
        accuracy = 100 * correct / total
        print(f"Epoch {epoch+1}/{EPOCHS} | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val Acc: {accuracy:.2f}%")

    save_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    torch.save(model.state_dict(), save_path)
    print(f"\n✅ Model successfully trained and saved to {save_path}")

if __name__ == "__main__":
    generate_meta_dataset_and_train()
