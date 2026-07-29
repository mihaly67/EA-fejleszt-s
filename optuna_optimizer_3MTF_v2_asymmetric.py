import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
import json
import os
from sklearn.model_selection import GroupKFold

DATA_PATH = "data/labeled_dollar_bars_3MTF.csv"
OUTPUT_DIR = "models"
N_TRIALS = 30
N_SPLITS = 3
EMBARGO_PCT = 0.01

def load_and_prepare_data(filepath):
    print(f"Adatok betöltése: {filepath}")
    df = pd.read_csv(filepath)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Open', 'High', 'Low', 'Close', '5m_Close', '15m_Close', '30m_Close', 'Target_Label', 'Bar_Time_Seconds', 'Total_Dollar_Value', 'Bid_Volume', 'Ask_Volume', 'Total_Volume']
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
    # Modellezési paraméterek
    params = {
        'objective': 'multiclass',
        'num_class': 3,
        'metric': 'multi_logloss',
        'boosting_type': 'gbdt',
        'learning_rate': trial.suggest_float('learning_rate', 0.005, 0.05, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 20, 128),
        'max_depth': trial.suggest_int('max_depth', 3, 12),
        'min_data_in_leaf': trial.suggest_int('min_data_in_leaf', 50, 400),
        'feature_fraction': trial.suggest_float('feature_fraction', 0.5, 0.9),
        'seed': 42,
        'verbose': -1,
        'n_jobs': -1
    }

    # Aszimmetrikus küszöbök keresési tere
    # 0 = Short, 1 = Noise, 2 = Long
    threshold_short = trial.suggest_float('threshold_short', 0.33, 0.60)
    threshold_long = trial.suggest_float('threshold_long', 0.33, 0.60)
    max_noise = trial.suggest_float('max_noise', 0.20, 0.45)

    fold_scores = []

    for train_idx, val_idx in splits:
        X_train, y_train = X.iloc[train_idx], y.iloc[train_idx]
        X_val, y_val = X.iloc[val_idx], y.iloc[val_idx]

        dtrain = lgb.Dataset(X_train, label=y_train)
        dval = lgb.Dataset(X_val, label=y_val, reference=dtrain)

        model = lgb.train(
            params, dtrain, num_boost_round=300, valid_sets=[dval],
            callbacks=[lgb.early_stopping(stopping_rounds=20, verbose=False)]
        )

        probs = model.predict(X_val, num_iteration=model.best_iteration)

        p_short = probs[:, 0]
        p_noise = probs[:, 1]
        p_long = probs[:, 2]

        # Aszimmetrikus kereskedési logika:
        # Ha a Noise elfogadható, és az adott irány átlépi a KÜLÖNÁLLÓ küszöbét
        preds = np.ones_like(y_val) # Alapértelmezett: Noise (1)

        # Long jel feltételei
        long_cond = (p_long > threshold_long) & (p_long > p_short) & (p_noise < max_noise)
        # Short jel feltételei
        short_cond = (p_short > threshold_short) & (p_short > p_long) & (p_noise < max_noise)

        preds[long_cond] = 2
        preds[short_cond] = 0

        # Eredmények kiértékelése
        active_idx = np.where((preds == 0) | (preds == 2))[0]
        total_active = len(active_idx)

        if total_active < 100: # Büntetés ha a küszöb túl szigorú és a modell nem csinál semmit
            fold_scores.append(-1000)
            continue

        y_test_active = y_val.values[active_idx]
        preds_active = preds[active_idx]

        correct = np.sum(preds_active == y_test_active)
        win_rate = correct / total_active

        # A Trading Score az irányított nyereség és a gyakoriság ötvözete
        # Keresünk egy 50% feletti win rate-et, de jutalmazzuk, ha többet köt.
        # Ha WR < 0.45, erős büntetés.
        if win_rate < 0.43:
            trading_score = -500
        else:
            trading_score = (win_rate ** 2) * np.log(total_active)

        fold_scores.append(trading_score)

    return np.mean(fold_scores)

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    df, X, y, features = load_and_prepare_data(DATA_PATH)
    splits = purged_group_kfold(df, n_splits=N_SPLITS, embargo_pct=EMBARGO_PCT)

    print(f"Aszimmetrikus Küszöb Optuna optimalizáció indítása {N_TRIALS} triallel...")
    study = optuna.create_study(direction="maximize", study_name="LGBM_Asymmetric_Thresholds")

    study.optimize(lambda trial: objective(trial, X, y, splits), n_trials=N_TRIALS)

    print("\n=== Optuna Optimalizáció Befejezve ===")
    print(f"Legjobb trial: {study.best_trial.number}")
    print(f"Legjobb érték (Trading Score): {study.best_value:.4f}")
    print("Legjobb paraméterek:")
    for key, value in study.best_params.items():
        print(f"    {key}: {value}")

    output_file = os.path.join(OUTPUT_DIR, "optuna_asymmetric_params_3MTF_v2.json")
    with open(output_file, 'w') as f:
        json.dump(study.best_params, f, indent=4)
    print(f"\nParaméterek kimentve: {output_file}")
