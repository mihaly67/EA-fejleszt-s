import pandas as pd
import numpy as np
from sklearn.neural_network import MLPClassifier
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import StandardScaler
import joblib
import os
import sys

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

def compute_sample_weights(df):
    """
    Kiszámítja a sample weight-eket.
    (Az sklearn MLPClassifier hivatalosan nem támogatja a sample_weight-et a fit-ben,
    így ha kiegyensúlyozást akarunk, SMOTE-ot vagy oversampling-et kellene használni,
    de a baseline méréshez most ez kimarad)
    """
    pass

def train_mlp_model(data_path, model_out_dir):
    log_file = os.path.join(model_out_dir, 'mlp_training_log.txt')

    def log(msg):
        print(msg)
        with open(log_file, 'a') as f:
            f.write(msg + "\n")

    # Töröljük a korábbi logot
    if os.path.exists(log_file):
        os.remove(log_file)

    log(f"🚀 scikit-learn MLPClassifier Tanítás indítása (Purged K-Fold & Embargo): {data_path}")

    df = pd.read_csv(data_path)
    df = df.dropna()

    features = ['OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_1m', 'Dist_5m', 'Dist_15m', 'ATR_Proxy']
    target = 'Target_Label'

    X_raw = df[features].values
    y = df[target].values # Itt hagyhatjuk a -1, 0, 1 osztályokat

    # MLP esetén kötelező a Standard Scaling (Z-Score)
    scaler = StandardScaler()
    X = scaler.fit_transform(X_raw)

    splits = get_purged_kfold_splits(df, n_splits=5, embargo_pct=0.01)

    best_model = None
    best_score = 0
    fold_scores = []

    os.makedirs(model_out_dir, exist_ok=True)

    log("\n🌲 K-Fold Keresztvalidáció indítása (MLP CPU):")
    for fold, (train_idx, test_idx) in enumerate(splits):
        if len(train_idx) == 0:
            continue

        X_train, y_train = X[train_idx], y[train_idx]
        X_test, y_test = X[test_idx], y[test_idx]

        # Egyszerű sekély háló (pl. két rejtett réteg)
        # Az MLPClassifier önmagában tudja kezelni a többmagos CPU-t a BLAS/LAPACK (numpy) hívásokon keresztül
        model = MLPClassifier(
            hidden_layer_sizes=(64, 32),
            activation='relu',
            solver='adam',
            alpha=0.001,
            batch_size=256,
            learning_rate='adaptive',
            max_iter=300,
            early_stopping=True,
            validation_fraction=0.1,
            n_iter_no_change=15,
            random_state=42
        )

        log(f"  ⏳ Fold {fold+1} tanítása folyamatban... (Tanító: {len(train_idx)} minta)")
        model.fit(X_train, y_train)

        preds = model.predict(X_test)
        score = accuracy_score(y_test, preds)
        fold_scores.append(score)

        log(f"  ✅ Fold {fold+1}: Accuracy = {score:.4f} (Teszt méret: {len(test_idx)})")

        if score > best_score:
            best_score = score
            best_model = model

    avg_score = np.mean(fold_scores)
    log(f"\n📊 Átlagos OOS (Out-of-Sample) Accuracy: {avg_score:.4f}")

    if best_model is not None:
        model_path = os.path.join(model_out_dir, 'mlp_copilot_model.pkl')
        scaler_path = os.path.join(model_out_dir, 'mlp_scaler.pkl')
        joblib.dump(best_model, model_path)
        joblib.dump(scaler, scaler_path)
        log(f"💾 A legjobb modell elmentve: {model_path}")
        log(f"💾 A hozzá tartozó Scaler elmentve: {scaler_path}")
        # MLP esetében nincs közvetlen feature importance érték.
        log("Megjegyzés: MLP esetén nincs közvetlen Feature Importance leolvasási lehetőség SHAP nélkül.")

    return best_model

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    model_out_dir = '/home/misi/Merkava_ML_Ops/models/'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    train_mlp_model(data_path, model_out_dir)
