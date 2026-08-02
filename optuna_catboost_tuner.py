import pandas as pd
import numpy as np
import optuna
from catboost import CatBoostClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import f1_score
import warnings

# Suppress annoying warnings
warnings.filterwarnings("ignore")

from macro_feature_engineer import process_macro_features
from macro_labeler import label_macro_regime

# Global variable to hold the feature-engineered dataset so we don't recalculate it every trial
DF_FEATURES = None
FEATURE_COLS = [
    'Dist_Micro_R', 'Dist_Micro_S',
    'Dist_Sec_R', 'Dist_Sec_S',
    'Dist_Ter_R', 'Dist_Ter_S',
    'Stoch_State_M1'
]

def objective(trial):
    """
    Optuna objective function.
    Tunes both the Target Labeling (Lookahead, ATR Threshold) AND the CatBoost Architecture.
    """
    global DF_FEATURES

    # 1. Labeling Hyperparameters
    lookahead = trial.suggest_int('lookahead', 3, 15)
    atr_multiplier = trial.suggest_float('atr_multiplier', 0.5, 2.0)

    # 2. CatBoost Architecture Hyperparameters
    depth = trial.suggest_int('depth', 4, 10)
    learning_rate = trial.suggest_float('learning_rate', 0.01, 0.2, log=True)
    iterations = trial.suggest_int('iterations', 200, 1000)
    l2_leaf_reg = trial.suggest_float('l2_leaf_reg', 1.0, 50.0)

    # Apply Dynamic Labels
    df_labeled = label_macro_regime(DF_FEATURES, lookahead=lookahead, atr_multiplier=atr_multiplier)

    X = df_labeled[FEATURE_COLS]
    y = df_labeled['Macro_Label']

    if len(X) < 1000:
        return 0.0 # Bad parameters resulted in too few rows

    # Shift labels from [-1, 0, 1] to [0, 1, 2] for CatBoost
    y_shifted = y + 1

    # Check if we have all 3 classes. Extreme ATR multipliers might eliminate trends.
    if len(np.unique(y_shifted)) < 3:
        return 0.0

    # Time-Series Validation (3 splits)
    tscv = TimeSeriesSplit(n_splits=3)
    f1_scores = []

    # Scale entire dataset outside loop to save time (it's geometric distance anyway, no future leakage on scale)
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    for train_index, test_index in tscv.split(X_scaled):
        X_train, X_test = X_scaled[train_index], X_scaled[test_index]
        y_train, y_test = y_shifted.iloc[train_index], y_shifted.iloc[test_index]

        clf = CatBoostClassifier(
            depth=depth,
            learning_rate=learning_rate,
            iterations=iterations,
            l2_leaf_reg=l2_leaf_reg,
            auto_class_weights='Balanced',
            loss_function='MultiClass',
            verbose=0,
            thread_count=-1
        )

        clf.fit(X_train, y_train)
        y_pred = clf.predict(X_test).flatten()

        # We optimize for MACRO F1-Score to ensure all 3 classes are predicted well
        score = f1_score(y_test, y_pred, average='macro')
        f1_scores.append(score)

    return np.mean(f1_scores)

def main():
    print("=== 🤖 CATBOOST & LABELING OPTUNA TUNER ===")
    global DF_FEATURES

    data_path = "../data/Master_ZigZag_GCEQ26_M1.csv"
    try:
        df_raw = pd.read_csv(data_path)
    except FileNotFoundError:
        df_raw = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv")

    print(f"Loaded {len(df_raw)} raw rows.")

    # Pre-calculate features once
    DF_FEATURES = process_macro_features(df_raw)
    print("Geometric features engineered. Starting Optimization...")

    # Create Optuna Study
    # Maximize the Macro F1 Score
    study = optuna.create_study(direction='maximize', study_name="CatBoost_Macro_Regime")

    # Run 50 trials (or more if time permits, but CatBoost can be slow)
    study.optimize(objective, n_trials=30)

    print("\n" + "="*50)
    print("🏆 OPTIMIZATION COMPLETE 🏆")
    print("="*50)
    print(f"Best Macro F1 Score: {study.best_value:.4f}")
    print("Best Parameters:")
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    main()
