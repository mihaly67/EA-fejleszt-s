import pandas as pd
import numpy as np
import lightgbm as lgb
import optuna
from sklearn.model_selection import train_test_split
from sklearn.metrics import f1_score
import warnings

warnings.filterwarnings("ignore")

def objective(trial):
    # Reduced dataset for fast tuning just to get tree parameters
    data_path = "../data/fused_features_dollar_bars.csv"
    DF_FUSED = pd.read_csv(data_path)
    label_path = "../data/labeled_dollar_bars_v4_5bar.csv"
    DF_LABELS = pd.read_csv(label_path)
    df = pd.merge(DF_FUSED, DF_LABELS[['Target_Label']], left_index=True, right_index=True)

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
        'Stoch_State_M1'
    ]

    existing_features = [f for f in features if f in df.columns]
    X = df[existing_features]
    y_shifted = df['Target_Label'] + 1

    # Single 80/20 split for speed
    X_train, X_test, y_train, y_test = train_test_split(X, y_shifted, test_size=0.2, shuffle=False)

    params = {
        'n_estimators': trial.suggest_int('n_estimators', 200, 1000),
        'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.1, log=True),
        'num_leaves': trial.suggest_int('num_leaves', 15, 63),
        'max_depth': trial.suggest_int('max_depth', 3, 8),
        'min_child_samples': trial.suggest_int('min_child_samples', 20, 200),
        'class_weight': 'balanced',
        'objective': 'multiclass',
        'random_state': 42,
        'n_jobs': -1,
        'verbose': -1
    }

    clf = lgb.LGBMClassifier(**params)
    clf.fit(X_train, y_train)
    y_pred = clf.predict(X_test)

    # Maximize ACTIVE trade accuracy
    f1_down = f1_score(y_test, y_pred, labels=[0], average='macro', zero_division=0)
    f1_up = f1_score(y_test, y_pred, labels=[2], average='macro', zero_division=0)

    return (f1_down + f1_up) / 2.0

def main():
    print("=== 🤖 FAST LGBM FUSION OPTUNA TUNER ===")
    study = optuna.create_study(direction='maximize', study_name="LGBM_Fusion_Fast")
    study.optimize(objective, n_trials=15)

    print("\n" + "="*50)
    print("🏆 LGBM OPTIMIZATION COMPLETE 🏆")
    print(f"Best Active Trade F1 Score: {study.best_value:.4f}")
    print("Best Parameters:")
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    main()
