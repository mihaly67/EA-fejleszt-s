import pandas as pd
import numpy as np
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib

def main():
    print("=== 🌲 LIGHTGBM FUSION COPILOT V5 (WICK-AWARE) ===")

    data_path = "../data/fused_features_dollar_bars.csv"
    print(f"Loading fused data from: {data_path}")
    df = pd.read_csv(data_path)

    label_path = "../data/labeled_dollar_bars_v5_strict.csv"
    print(f"Loading Strict V5 Labels from: {label_path}")
    df_labels = pd.read_csv(label_path)

    df = pd.merge(df, df_labels[['Target_Label']], left_index=True, right_index=True)

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

    existing_features = [f for f in features if f in df.columns]
    X = df[existing_features]
    y = df['Target_Label']
    y_shifted = y + 1

    X_train, X_test, y_train, y_test = train_test_split(X, y_shifted, test_size=0.2, shuffle=False)

    print("\nTraining Tuned LightGBM Copilot V5...")

    clf = lgb.LGBMClassifier(
        n_estimators=781,
        learning_rate=0.0142,
        num_leaves=57,
        max_depth=6,
        min_child_samples=24,
        colsample_bytree=0.566,
        class_weight='balanced',
        objective='multiclass',
        random_state=42,
        n_jobs=-1
    )

    clf.fit(X_train, y_train, eval_set=[(X_test, y_test)])

    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (FUSION LGBM V5) ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report (0=Downtrend, 1=Range, 2=Uptrend):")
    print(classification_report(y_test, y_pred, zero_division=0))

    joblib.dump(clf, '../models/lgbm_model_fusion_v5_tuned.pkl')
    print("\n✅ V5 Fusion Model saved to Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl")

if __name__ == "__main__":
    main()
