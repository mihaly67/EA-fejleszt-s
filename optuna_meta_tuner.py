import sys
sys.path.append("/home/Jules/LGBM_mlops/Micro_LGBM/src")
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import optuna
import os

# Create sequences logic
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

# A configurable LSTM for Optuna
class ConfigurableLSTM(nn.Module):
    def __init__(self, input_dim, hidden_dim, num_layers, dropout_rate):
        super(ConfigurableLSTM, self).__init__()
        self.lstm = nn.LSTM(input_dim, hidden_dim, num_layers, batch_first=True, dropout=dropout_rate if num_layers > 1 else 0.0)
        self.fc1 = nn.Linear(hidden_dim, hidden_dim // 2)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(dropout_rate)
        self.fc2 = nn.Linear(hidden_dim // 2, 1)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        out, _ = self.lstm(x)
        out = out[:, -1, :]
        out = self.fc1(out)
        out = self.relu(out)
        out = self.dropout(out)
        out = self.fc2(out)
        return self.sigmoid(out)

# We load data ONCE globally for Optuna
print("Loading data for Optuna...")
data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/meta_labeled_fused_v5_mom.csv"
df = pd.read_csv(data_path)

# Based on SHAP, we DROP the noise features: Open, High, Low, Close, M5_RSI_14
lstm_features = [
    'Total_Volume', 'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
    'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
    'P_Long', 'P_Short', 'P_Noise', 'LGBM_Signal',
    'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
]

# We don't have OHLC anymore, so no local min-max scaling needed in this specific run.
# Wait, create_sequences hardcodes indices 0:4 as OHLC. We must fix that since we dropped OHLC.
def create_sequences_no_ohlc(data, labels, seq_length):
    xs = []
    ys = []
    for i in range(len(data) - seq_length):
        x = data[i + 1 : i + seq_length + 1]
        y = labels[i + seq_length]
        if y != -1:
            xs.append(x)
            ys.append(y)
    return np.array(xs), np.array(ys)

for f in lstm_features:
    if f not in df.columns:
        df[f] = 0.0

X_lstm_raw = df[lstm_features].fillna(0).values
X_lstm_mean = np.mean(X_lstm_raw, axis=0)
X_lstm_std = np.std(X_lstm_raw, axis=0)
X_lstm_norm = (X_lstm_raw - X_lstm_mean) / (X_lstm_std + 1e-8)
meta_labels = df['Meta_Label'].values

SEQ_LENGTH = 20
X_seq, y_seq = create_sequences_no_ohlc(X_lstm_norm, meta_labels, SEQ_LENGTH)

X_tensor = torch.tensor(X_seq, dtype=torch.float32)
y_tensor = torch.tensor(y_seq, dtype=torch.float32).unsqueeze(1)
dataset = TensorDataset(X_tensor, y_tensor)
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = torch.utils.data.random_split(dataset, [train_size, val_size])

# Keep loaders global to save memory
train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

def objective(trial):
    # Hyperparameters
    hidden_dim = trial.suggest_categorical("hidden_dim", [32, 64, 128])
    num_layers = trial.suggest_int("num_layers", 1, 3)
    dropout_rate = trial.suggest_float("dropout_rate", 0.1, 0.5)
    lr = trial.suggest_loguniform("lr", 1e-4, 1e-2)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = ConfigurableLSTM(len(lstm_features), hidden_dim, num_layers, dropout_rate).to(device)
    criterion = nn.BCELoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)

    EPOCHS = 10 # Keep short for tuning
    best_val_acc = 0.0

    for epoch in range(EPOCHS):
        model.train()
        for batch_X, batch_y in train_loader:
            batch_X, batch_y = batch_X.to(device), batch_y.to(device)
            optimizer.zero_grad()
            outputs = model(batch_X)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()

        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for batch_X, batch_y in val_loader:
                batch_X, batch_y = batch_X.to(device), batch_y.to(device)
                outputs = model(batch_X)
                predicted = (outputs > 0.5).float()
                total += batch_y.size(0)
                correct += (predicted == batch_y).sum().item()

        accuracy = correct / total
        best_val_acc = max(best_val_acc, accuracy)

        # Pruning
        trial.report(accuracy, epoch)
        if trial.should_prune():
            raise optuna.exceptions.TrialPruned()

    return best_val_acc

if __name__ == "__main__":
    print("==================================================")
    print("🧠 LSTM META-ADVISOR OPTUNA TUNER 🧠")
    print("==================================================")

    study = optuna.create_study(direction="maximize")
    study.optimize(objective, n_trials=30)

    print("\n✅ OPTUNA TUNING COMPLETE")
    print("Best Trial:")
    print("  Value (Accuracy): ", study.best_trial.value)
    print("  Params: ")
    for key, value in study.best_trial.params.items():
        print(f"    {key}: {value}")
