import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import os
import argparse
from nn_meta_model import MetaAdvisorLSTM
from datetime import datetime

def create_sequences(data, labels, seq_length):
    xs = []
    ys = []
    # Ignore the first seq_length rows as we can't form a full sequence for them
    for i in range(len(data) - seq_length):
        x = data[i:(i + seq_length)]
        # The label corresponds to the prediction at the END of the sequence
        y = labels[i + seq_length]

        # We only want to train on rows where the LGBM actually made a signal (Meta_Label != -1)
        if y != -1:
            xs.append(x)
            ys.append(y)

    return np.array(xs), np.array(ys)

def generate_meta_dataset_and_train():
    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/labeled_dollar_bars_v5_strict.csv"
    model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl"

    print(f"Loading raw dollar bars from {data_path}...")
    df = pd.read_csv(data_path)

    # In a real scenario, this df MUST contain the exact 10 features the model was trained on.
    # If the fusion script hasn't run, we have to mock it or assume the features exist.
    # For this architecture proof-of-concept, we will isolate whatever numeric features exist
    # to feed the LSTM, but for LGBM we assume it has its 10 features.

    # (Simplified fallback logic since fusion dataset is missing)
    # We will simulate the meta-labels for the sake of the NN pipeline
    print("WARNING: Using simulated LGBM output for LSTM architecture test due to missing fusion dataset.")

    # We need a numeric matrix for the LSTM. Let's pick continuous features available in labeled_dollar_bars_v5_strict.csv.
    lstm_features = [
        'Open', 'High', 'Low', 'Close', 'Total_Volume',
        'M5_RSI_14', 'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed'
    ]

    # Verify these features exist, filter if not
    existing_lstm_features = [f for f in lstm_features if f in df.columns]

    X_lstm_raw = df[existing_lstm_features].fillna(0).values

    # Normalize features (StandardScaler logic)
    X_lstm_mean = np.mean(X_lstm_raw, axis=0)
    X_lstm_std = np.std(X_lstm_raw, axis=0)

    # Save the scaler values for live inference!!!
    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_mean.npy", X_lstm_mean)
    np.save("/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_std.npy", X_lstm_std)
    print("✅ Saved global X_lstm_mean and X_lstm_std for inference normalization.")

    X_lstm_norm = (X_lstm_raw - X_lstm_mean) / (X_lstm_std + 1e-8)

    # Simulate Meta Labels (1 = LGBM was right, 0 = LGBM was wrong, -1 = No signal)
    # 20% True Positive, 10% False Positive, 70% No Signal
    np.random.seed(42)
    rand_vals = np.random.rand(len(df))
    meta_labels = np.full(len(df), -1)
    meta_labels[rand_vals < 0.2] = 1
    meta_labels[(rand_vals >= 0.2) & (rand_vals < 0.3)] = 0

    SEQ_LENGTH = 20
    print(f"Creating sequences of length {SEQ_LENGTH}...")
    X_seq, y_seq = create_sequences(X_lstm_norm, meta_labels, SEQ_LENGTH)

    print(f"Sequence dataset shape: X={X_seq.shape}, y={y_seq.shape}")

    # Convert to PyTorch tensors
    X_tensor = torch.tensor(X_seq, dtype=torch.float32)
    y_tensor = torch.tensor(y_seq, dtype=torch.float32).unsqueeze(1)

    dataset = TensorDataset(X_tensor, y_tensor)

    # 80/20 split
    train_size = int(0.8 * len(dataset))
    val_size = len(dataset) - train_size
    train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

    train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

    # Initialize Model (CPU ONLY for compatibility test)
    # Train on GPU if available (PyTorch downgraded to 2.1.2+cu118 for P2000 support)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\n==========================================")
    print(f"🚀 INITIALIZING LSTM TRAINING ON: {device} 🚀")
    print(f"==========================================\n")

    model = MetaAdvisorLSTM(input_dim=len(existing_lstm_features)).to(device)
    criterion = nn.BCELoss() # Binary Cross Entropy for 0/1 meta-label
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

        # Validation
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

                # Accuracy: > 0.5 is predicted as 1 (True Positive expected)
                predicted = (outputs > 0.5).float()
                total += batch_y.size(0)
                correct += (predicted == batch_y).sum().item()

        val_loss /= len(val_loader.dataset)
        accuracy = 100 * correct / total

        print(f"Epoch {epoch+1}/{EPOCHS} | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val Accuracy: {accuracy:.2f}%")

    # Save the model
    os.makedirs("/home/Jules/LGBM_mlops/Micro_LGBM/models", exist_ok=True)
    save_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    torch.save(model.state_dict(), save_path)
    print(f"\n✅ Model successfully trained and saved to {save_path}")

if __name__ == "__main__":
    generate_meta_dataset_and_train()
