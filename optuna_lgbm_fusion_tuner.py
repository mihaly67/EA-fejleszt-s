import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import f1_score
import warnings

warnings.filterwarnings("ignore")

DF_FUSED = None
DF_LABELS = None
X = None
y_shifted = None
EXISTING_FEATURES = []

def objective(trial):
    """
    Optuna objective function for tuning the LightGBM Fusion Copilot.
    """
    global X, y_shifted

    # 1. LightGBM Hyperparameters
    params = {
        'n_estimators': trial.suggest_int('n_estimators', 200, 1500),
        'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.1, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 15, 127),
        'max_depth': trial.suggest_int('max_depth', 3, 12),
        'min_child_samples': trial.suggest_int('min_child_samples', 20, 500),
        'colsample_bytree': trial.suggest_float('colsample_bytree', 0.3, 1.0),
        'class_weight': 'balanced',
        'objective': 'multiclass',
        'random_state': 42,
        'n_jobs': -1,
        'verbose': -1
    }

    # Time-Series Validation (3 splits)
    tscv = TimeSeriesSplit(n_splits=3)
    f1_scores = []

    # We want to penalize models that just predict 1 (Noise) all the time.
    # We will measure the Macro F1 score specifically on the ACTIVE classes (0 and 2).

    for train_index, test_index in tscv.split(X):
        X_train, X_test = X.iloc[train_index], X.iloc[test_index]
        y_train, y_test = y_shifted.iloc[train_index], y_shifted.iloc[test_index]

        clf = lgb.LGBMClassifier(**params)
        clf.fit(X_train, y_train)

        y_pred = clf.predict(X_test)

        # Calculate F1 score for Uptrend (2) and Downtrend (0) only
        f1_down = f1_score(y_test, y_pred, labels=[0], average='macro', zero_division=0)
        f1_up = f1_score(y_test, y_pred, labels=[2], average='macro', zero_division=0)

        active_f1 = (f1_down + f1_up) / 2.0
        f1_scores.append(active_f1)

    return np.mean(f1_scores)

def main():
    print("=== 🤖 LIGHTGBM FUSION OPTUNA TUNER ===")
    global DF_FUSED, DF_LABELS, X, y_shifted, EXISTING_FEATURES

    print("Loading datasets...")
    data_path = "../data/fused_features_dollar_bars.csv"
    DF_FUSED = pd.read_csv(data_path)

    label_path = "../data/labeled_dollar_bars_v4_5bar.csv"
    DF_LABELS = pd.read_csv(label_path)

    df = pd.merge(DF_FUSED, DF_LABELS[['Target_Label']], left_index=True, right_index=True)

    # We will exclude classical indicators like M15_RSI and M5_RSI here because they are known to lag.
    features = [
        'Tick_Speed', 'Imbalance_L1', 'Imbalance_L2',
        'Imbalance_L3', 'Imbalance_L4', 'Imbalance_L5', 'Imbalance_L6',
        'Imbalance_L7', 'Imbalance_L8', 'Imbalance_L9', 'Imbalance_L10',
        'CVD_Raw', 'CVD_Rolling_10', 'Cancel_Rate_Rolling_10',
        'Trade_Size_Imbalance', 'Spread_ZScore',
        'ATR_Micro', 'Velocity_Micro',
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1'
    ]

    EXISTING_FEATURES = [f for f in features if f in df.columns]
    X = df[EXISTING_FEATURES]
    y_shifted = df['Target_Label'] + 1

    print(f"Dataset shape: {X.shape}. Starting Optimization focusing on ACTIVE trades...")

    study = optuna.create_study(direction='maximize', study_name="LGBM_Fusion_Tuner")
    study.optimize(objective, n_trials=30)

    print("\n" + "="*50)
    print("🏆 LGBM OPTIMIZATION COMPLETE 🏆")
    print("="*50)
    print(f"Best Active Trade F1 Score: {study.best_value:.4f}")
    print("Best Parameters:")
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    main()
