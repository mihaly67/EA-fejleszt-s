import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
import json
import os
from sklearn.model_selection import GroupKFold
from sklearn.metrics import accuracy_score

DATA_PATH = "data/labeled_dollar_bars_3MTF.csv"
OUTPUT_DIR = "models"
N_TRIALS = 30
N_SPLITS = 3
EMBARGO_PCT = 0.01

def load_and_prepare_data(filepath):
    print(f"Adatok betöltése: {filepath}")
    df = pd.read_csv(filepath)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X = df[features]
    y = df['Target_Label']

    if y.min() == -1:
        y = y + 1

    return df, X, y, features

def purged_group_kfold(df, n_splits=3, embargo_pct=0.01):
    group_size = len(df) // 20
    groups = (df.index // group_size).values

    gkf = GroupKFold(n_splits=n_splits)
    splits = []

    for train_idx, val_idx in gkf.split(df, groups=groups):
        embargo_size = int(len(df) * embargo_pct)
        val_min = val_idx.min()
        val_max = val_idx.max()

        train_idx_purged = train_idx[
            (train_idx < val_min - embargo_size) | (train_idx > val_max + embargo_size)
        ]
        splits.append((train_idx_purged, val_idx))
    return splits

def objective(trial, X, y, splits):
    # A felhasználó által kért specifikus architekturális paraméterek
    params = {
        'objective': 'multiclass',
        'num_class': 3,
        'metric': 'multi_error',
        'boosting_type': 'gbdt',
        'learning_rate': trial.suggest_float('learning_rate', 0.001, 0.1, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 16, 256),
        'max_depth': trial.suggest_int('max_depth', 3, 15),
        'min_child_samples': trial.suggest_int('min_child_samples', 20, 500), # LGBM megfelelője a min_data_in_leaf-nek
        'feature_fraction': trial.suggest_float('feature_fraction', 0.4, 0.9),
        'seed': 42,
        'verbose': -1,
        'n_jobs': -1
    }

    # A felhasználó külön kérte az n_estimators-t is (LGBM-ben num_boost_round)
    n_estimators = trial.suggest_int('n_estimators', 100, 1500)

    fold_scores = []

    for train_idx, val_idx in splits:
        X_train, y_train = X.iloc[train_idx], y.iloc[train_idx]
        X_val, y_val = X.iloc[val_idx], y.iloc[val_idx]

        dtrain = lgb.Dataset(X_train, label=y_train)
        dval = lgb.Dataset(X_val, label=y_val, reference=dtrain)

        # Train without early stopping to explicitly evaluate the suggested n_estimators
        model = lgb.train(
            params, dtrain, num_boost_round=n_estimators, valid_sets=[dval],
            callbacks=[lgb.early_stopping(stopping_rounds=100, verbose=False)]
        )

        probs = model.predict(X_val)
        preds = np.argmax(probs, axis=1)

        # Csak a Long/Short (0 vagy 2) pontosságát maximalizáljuk (a 'Noise' pontosság kevésbé érdekes most)
        active_mask = (preds == 0) | (preds == 2)
        if active_mask.sum() < 50:
            fold_scores.append(-1) # Büntetés passzivitásért
            continue

        correct = np.sum(preds[active_mask] == y_val.values[active_mask])
        score = correct / active_mask.sum()
        fold_scores.append(score)

    return np.mean(fold_scores)

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df, X, y, features = load_and_prepare_data(DATA_PATH)
    splits = purged_group_kfold(df, n_splits=N_SPLITS, embargo_pct=EMBARGO_PCT)

    print(f"Architektúra Optuna optimalizáció indítása {N_TRIALS} triallel...")
    study = optuna.create_study(direction="maximize", study_name="LGBM_Architecture")
    study.optimize(lambda trial: objective(trial, X, y, splits), n_trials=N_TRIALS)

    print("\n=== Optuna Optimalizáció Befejezve ===")
    print(f"Legjobb trial: {study.best_trial.number}")
    print(f"Legjobb érték (Active Win Rate): {study.best_value:.4f}")

    output_file = os.path.join(OUTPUT_DIR, "optuna_architecture_params.json")
    with open(output_file, 'w') as f:
        json.dump(study.best_params, f, indent=4)
    print(f"\nParaméterek kimentve: {output_file}")
