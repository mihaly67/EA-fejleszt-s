import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
from sklearn.model_selection import TimeSeriesSplit
import warnings

warnings.filterwarnings("ignore")

DF_FUSED = None
DF_LABELS = None
X = None
y_shifted = None
EXISTING_FEATURES = []

def objective(trial):
    """
    Deep 2D Optuna Tuner.
    Simultaneously optimizes the LGBM tree parameters AND the 2D signal threshold
    (Min Signal Confidence vs Max Noise Confidence).
    """
    global X, y_shifted

    # 1. LightGBM Hyperparameters
    params = {
        'n_estimators': trial.suggest_int('n_estimators', 200, 1000),
        'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.1, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 15, 63),
        'max_depth': trial.suggest_int('max_depth', 3, 10),
        'min_child_samples': trial.suggest_int('min_child_samples', 20, 200),
        'colsample_bytree': trial.suggest_float('colsample_bytree', 0.3, 1.0),
        'class_weight': 'balanced',
        'objective': 'multiclass',
        'random_state': 42,
        'n_jobs': -1,
        'verbose': -1
    }

    # 2. 2D Thresholding Parameters
    p_signal_min = trial.suggest_float('p_signal_min', 0.40, 0.70)
    p_noise_max = trial.suggest_float('p_noise_max', 0.10, 0.40)

    tscv = TimeSeriesSplit(n_splits=3)
    precision_scores = []

    for train_index, test_index in tscv.split(X):
        X_train, X_test = X.iloc[train_index], X.iloc[test_index]
        y_train, y_test = y_shifted.iloc[train_index], y_shifted.iloc[test_index]

        clf = lgb.LGBMClassifier(**params)
        clf.fit(X_train, y_train)

        probs = clf.predict_proba(X_test)

        P_Short = probs[:, 0]
        P_Noise = probs[:, 1]
        P_Long = probs[:, 2]

        # Apply 2D Threshold Logic
        valid_long_signals = 0
        correct_long_signals = 0

        valid_short_signals = 0
        correct_short_signals = 0

        y_test_vals = y_test.values

        for i in range(len(probs)):
            actual = y_test_vals[i]

            # Long Logic
            if P_Long[i] > p_signal_min and P_Noise[i] < p_noise_max and P_Long[i] > P_Short[i]:
                valid_long_signals += 1
                if actual == 2:
                    correct_long_signals += 1

            # Short Logic
            elif P_Short[i] > p_signal_min and P_Noise[i] < p_noise_max and P_Short[i] > P_Long[i]:
                valid_short_signals += 1
                if actual == 0:
                    correct_short_signals += 1

        total_valid = valid_long_signals + valid_short_signals
        total_correct = correct_long_signals + correct_short_signals

        if total_valid < 10:
            # Penalize the model if it's too scared to take trades
            precision_scores.append(0.0)
        else:
            win_rate = total_correct / total_valid
            # We want high win rate AND decent frequency.
            # E.g., WinRate * log(Total_Valid)
            score = win_rate * np.log1p(total_valid)
            precision_scores.append(score)

    return np.mean(precision_scores)

def main():
    print("=== 🤖 2D THRESHOLD & LGBM FUSION TUNER (WICK AWARE) ===")
    global DF_FUSED, DF_LABELS, X, y_shifted, EXISTING_FEATURES

    print("Loading datasets...")
    # Load historical fused
    DF_FUSED = pd.read_csv("../data/fused_features_dollar_bars.csv")
    DF_LABELS = pd.read_csv("../data/labeled_dollar_bars_v5_strict.csv")

    df = pd.merge(DF_FUSED, DF_LABELS[['Target_Label']], left_index=True, right_index=True)

    # NEW WICK FEATURES INCLUDED
    features = [
        'Tick_Speed', 'Micro_Trend', 'Macro_Trend', 'Imbalance_L1', 'Imbalance_L2',
        'Imbalance_L3', 'Imbalance_L4', 'Imbalance_L5', 'Imbalance_L6',
        'Imbalance_L7', 'Imbalance_L8', 'Imbalance_L9', 'Imbalance_L10',
        'CVD_Raw', 'CVD_Rolling_10', 'Cancel_Rate_Rolling_10',
        'Trade_Size_Imbalance', 'Spread_ZScore',
        'ATR_Micro', 'Velocity_Micro',
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1',
        'Upper_Wick_ATR', 'Lower_Wick_ATR'
    ]

    EXISTING_FEATURES = [f for f in features if f in df.columns]
    X = df[EXISTING_FEATURES]
    y_shifted = df['Target_Label'] + 1

    print(f"Dataset shape: {X.shape}. Starting 2D Optimization...")

    study = optuna.create_study(direction='maximize', study_name="LGBM_Deep_2D_Tuner")
    study.optimize(objective, n_trials=30)

    print("\n" + "="*50)
    print("🏆 2D LGBM OPTIMIZATION COMPLETE 🏆")
    print(f"Best Objective Score (WinRate * log(Freq)): {study.best_value:.4f}")
    print("Best Parameters:")
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    main()
