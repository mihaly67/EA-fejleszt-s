import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_class_weight
import os
import sys

# Készítünk egy egyszerű Feed-Forward Neural Network architektúrát (CPU-barát)
class CopilotMLP(nn.Module):
    def __init__(self, input_size, num_classes=3):
        super(CopilotMLP, self).__init__()
        self.network = nn.Sequential(
            nn.Linear(input_size, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.Dropout(0.2), # 20% dropout a túltanulás ellen

            nn.Linear(64, 32),
            nn.BatchNorm1d(32),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(32, num_classes)
        )

    def forward(self, x):
        return self.network(x)

def get_purged_kfold_splits(df, n_splits=5, embargo_pct=0.01):
    kf = KFold(n_splits=n_splits, shuffle=False)
    embargo_size = int(len(df) * embargo_pct)

    splits = []
    for train_idx, test_idx in kf.split(df):
        test_start = test_idx[0]
        test_end = test_idx[-1]

        train_idx_purged = [i for i in train_idx if i < (test_start - embargo_size) or i > (test_end + embargo_size)]
        splits.append((np.array(train_idx_purged), test_idx))

    return splits

def train_pytorch_model(data_path, model_out_dir):
    log_file = os.path.join(model_out_dir, 'pytorch_training_log.txt')
    def log(msg):
        print(msg)
        with open(log_file, 'a') as f:
            f.write(msg + "\n")

    if os.path.exists(log_file): os.remove(log_file)

    log(f"🚀 PyTorch MLP Tanítás indítása (Purged K-Fold & Embargo): {data_path}")

    df = pd.read_csv(data_path).dropna()
    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)

    # Hold-out halmaz az igazi OOS teszthez (80%)
    holdout_idx = int(len(df) * 0.8)
    df_cv = df.iloc[:holdout_idx].copy()

    X_raw = df_cv[features].values
    y_raw = df_cv['Target_Label'].values
    y = y_raw + 1  # -1, 0, 1 -> 0, 1, 2

    # Kiszámoljuk az osztálysúlyokat a Loss függvényhez (kiegyensúlyozás)
    classes = np.unique(y)
    class_weights = compute_class_weight(class_weight='balanced', classes=classes, y=y)
    class_weights_tensor = torch.FloatTensor(class_weights)
    log(f"⚖️ Osztály súlyok a CrossEntropyLoss-hoz: {class_weights}")

    splits = get_purged_kfold_splits(df_cv, n_splits=5, embargo_pct=0.01)

    best_model_state = None
    best_scaler = None
    best_score = 0
    fold_scores = []

    os.makedirs(model_out_dir, exist_ok=True)

    # Hyperparaméterek
    epochs = 150
    batch_size = 256
    learning_rate = 0.001
    patience = 15 # Early stopping

    log("\n🌲 K-Fold Keresztvalidáció indítása (PyTorch CPU):")
    for fold, (train_idx, test_idx) in enumerate(splits):
        if len(train_idx) == 0: continue

        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_raw[train_idx])
        X_test_scaled = scaler.transform(X_raw[test_idx])

        X_train_t = torch.FloatTensor(X_train_scaled)
        y_train_t = torch.LongTensor(y[train_idx])
        X_test_t = torch.FloatTensor(X_test_scaled)
        y_test_t = torch.LongTensor(y[test_idx])

        train_dataset = TensorDataset(X_train_t, y_train_t)
        train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)

        model = CopilotMLP(input_size=len(features), num_classes=3)
        criterion = nn.CrossEntropyLoss(weight=class_weights_tensor)
        optimizer = optim.Adam(model.parameters(), lr=learning_rate, weight_decay=1e-4)

        best_fold_score = 0
        best_fold_model = None
        no_improve_epochs = 0

        log(f"  ⏳ Fold {fold+1} tanítása folyamatban... (Tanító méret: {len(train_idx)})")

        for epoch in range(epochs):
            model.train()
            for batch_X, batch_y in train_loader:
                optimizer.zero_grad()
                outputs = model(batch_X)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()

            # Validáció
            model.eval()
            with torch.no_grad():
                test_outputs = model(X_test_t)
                _, predicted = torch.max(test_outputs.data, 1)
                current_score = accuracy_score(y_test_t.numpy(), predicted.numpy())

            if current_score > best_fold_score:
                best_fold_score = current_score
                best_fold_model = {k: v.cpu().clone() for k, v in model.state_dict().items()}
                no_improve_epochs = 0
            else:
                no_improve_epochs += 1

            if no_improve_epochs >= patience:
                break

        fold_scores.append(best_fold_score)
        log(f"  ✅ Fold {fold+1}: Legjobb Accuracy = {best_fold_score:.4f} (Teszt méret: {len(test_idx)}, Epochs futott: {epoch+1})")

        if best_fold_score > best_score:
            best_score = best_fold_score
            best_model_state = best_fold_model
            best_scaler = scaler

    avg_score = np.mean(fold_scores)
    log(f"\n📊 Átlagos CV (K-Fold) Accuracy: {avg_score:.4f}")

    if best_model_state is not None:
        model_path = os.path.join(model_out_dir, 'pytorch_copilot_model.pt')
        scaler_path = os.path.join(model_out_dir, 'pytorch_scaler.pt') # Csak a nevénél fogva, a formátum joblib lesz
        torch.save(best_model_state, model_path)
        import joblib
        joblib.dump(best_scaler, scaler_path)
        log(f"💾 A legjobb modell elmentve: {model_path}")
        log(f"💾 A hozzá tartozó Scaler elmentve: {scaler_path}")

    return best_model_state

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    model_out_dir = '/home/misi/Merkava_ML_Ops/models/'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    train_pytorch_model(data_path, model_out_dir)
