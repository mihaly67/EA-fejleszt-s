import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
import json
import os
from sklearn.model_selection import GroupKFold

DATA_PATH = "data/labeled_dollar_bars_3MTF_v2.csv"
OUTPUT_DIR = "models"
N_TRIALS = 30
N_SPLITS = 3
EMBARGO_PCT = 0.01

def load_and_prepare_data(filepath):
    print(f"Adatok betöltése: {filepath}")
    # Fix oszlopok, kiküszöbölve a data leakage-et
    df = pd.read_csv(filepath)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    # Fontos: A trend meghatározásához kell a makro indikátor
    df['Macro_Trend'] = 'Sideways'
    df.loc[df['M15_RSI_14'] > 55, 'Macro_Trend'] = 'Uptrend'
    df.loc[df['M15_RSI_14'] < 45, 'Macro_Trend'] = 'Downtrend'

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

def objective(trial, df, X, y, splits):
    # Modell paraméterek
    params = {
        'objective': 'multiclass',
        'num_class': 3,
        'metric': 'multi_logloss',
        'boosting_type': 'gbdt',
        'learning_rate': trial.suggest_float('learning_rate', 0.005, 0.05, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 20, 100),
        'max_depth': trial.suggest_int('max_depth', 3, 10),
        'min_data_in_leaf': trial.suggest_int('min_data_in_leaf', 50, 400),
        'feature_fraction': trial.suggest_float('feature_fraction', 0.5, 0.9),
        'seed': 42,
        'verbose': -1,
        'n_jobs': -1
    }

    # 9 Dimenziós Dinamikus Rezsim Küszöbök
    # Uptrend (Longot szeretnénk, Shortot büntetjük)
    up_thr_long = trial.suggest_float('up_thr_long', 0.33, 0.50)
    up_thr_short = trial.suggest_float('up_thr_short', 0.45, 0.65) # Szigorú short
    up_max_noise = trial.suggest_float('up_max_noise', 0.20, 0.45)

    # Downtrend (Shortot szeretnénk, Longot büntetjük)
    down_thr_long = trial.suggest_float('down_thr_long', 0.45, 0.65) # Szigorú long
    down_thr_short = trial.suggest_float('down_thr_short', 0.33, 0.50)
    down_max_noise = trial.suggest_float('down_max_noise', 0.20, 0.45)

    # Sideways (Semleges, kiegyensúlyozott)
    side_thr_long = trial.suggest_float('side_thr_long', 0.35, 0.55)
    side_thr_short = trial.suggest_float('side_thr_short', 0.35, 0.55)
    side_max_noise = trial.suggest_float('side_max_noise', 0.20, 0.45)

    fold_scores = []

    for train_idx, val_idx in splits:
        X_train, y_train = X.iloc[train_idx], y.iloc[train_idx]
        X_val, y_val = X.iloc[val_idx], y.iloc[val_idx]
        df_val = df.iloc[val_idx]

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

        preds = np.ones_like(y_val) # Noise by default

        trends = df_val['Macro_Trend'].values

        # Maszkok generálása
        up_mask = (trends == 'Uptrend')
        down_mask = (trends == 'Downtrend')
        side_mask = (trends == 'Sideways')

        # Uptrend kiértékelés
        preds[up_mask & (p_long > up_thr_long) & (p_long > p_short) & (p_noise < up_max_noise)] = 2
        preds[up_mask & (p_short > up_thr_short) & (p_short > p_long) & (p_noise < up_max_noise)] = 0

        # Downtrend kiértékelés
        preds[down_mask & (p_long > down_thr_long) & (p_long > p_short) & (p_noise < down_max_noise)] = 2
        preds[down_mask & (p_short > down_thr_short) & (p_short > p_long) & (p_noise < down_max_noise)] = 0

        # Sideways kiértékelés
        preds[side_mask & (p_long > side_thr_long) & (p_long > p_short) & (p_noise < side_max_noise)] = 2
        preds[side_mask & (p_short > side_thr_short) & (p_short > p_long) & (p_noise < side_max_noise)] = 0

        active_idx = np.where((preds == 0) | (preds == 2))[0]
        total_active = len(active_idx)

        if total_active < 50:
            fold_scores.append(-1000)
            continue

        y_test_active = y_val.values[active_idx]
        preds_active = preds[active_idx]

        correct = np.sum(preds_active == y_test_active)
        win_rate = correct / total_active

        if win_rate < 0.43:
            trading_score = -500
        else:
            # Jutalmazzuk a nyerő arányt és a volument
            trading_score = (win_rate ** 3) * np.log(total_active)

        fold_scores.append(trading_score)

    return np.mean(fold_scores)

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df, X, y, features = load_and_prepare_data(DATA_PATH)
    splits = purged_group_kfold(df, n_splits=N_SPLITS, embargo_pct=EMBARGO_PCT)

    print(f"Rezsim-Függő Optuna optimalizáció indítása {N_TRIALS} triallel...")
    study = optuna.create_study(direction="maximize", study_name="LGBM_Regime_Thresholds")
    study.optimize(lambda trial: objective(trial, df, X, y, splits), n_trials=N_TRIALS)

    print("\n=== Optuna Optimalizáció Befejezve ===")
    print(f"Legjobb trial: {study.best_trial.number}")
    print(f"Legjobb érték (Trading Score): {study.best_value:.4f}")

    output_file = os.path.join(OUTPUT_DIR, "optuna_regime_params_3MTF_v3.json")
    with open(output_file, 'w') as f:
        json.dump(study.best_params, f, indent=4)
    print(f"\nParaméterek kimentve: {output_file}")
