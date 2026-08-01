import pandas as pd
import numpy as np
from sklearn.linear_model import RidgeClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

from macro_feature_engineer import process_macro_features
from macro_labeler import label_macro_regime

def main():
    print("=== 🏗️ STRUCTURAL MACRO REGIME MODEL (ZIGZAG GEOMETRY) ===")

    # Load Real Data from the new MQL5 ZigZag Miner V5
    data_path = "../data/Master_ZigZag_GCEQ26_M1.csv"
    print(f"Waiting for new ZigZag format from miner: {data_path}")

    try:
        df = pd.read_csv(data_path)
        print(f"Loaded {len(df)} rows.")
    except FileNotFoundError:
        print("MQL5 V5 CSV not found yet. Please run 'Merkava_Master_Data_Miner_v5.mq5' in MT5 and upload the CSV to Macro_Regime/data/.")
        return

    df_features = process_macro_features(df)

    # Lookahead=5 (5 minutes on M1 timeframe). atr_multiplier=1.0.
    df_labeled = label_macro_regime(df_features, lookahead=5, atr_multiplier=1.0)

    # Define explicitly the new ZigZag features + Stochastic
    feature_cols = [
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1'
    ]

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    if len(X) < 100:
        print("Error: Dataset too small.")
        return

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    print("\nTraining ZigZag Ridge Classifier...")
    clf = RidgeClassifier(alpha=1.0, class_weight='balanced')
    clf.fit(X_train_scaled, y_train)

    y_pred = clf.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (ZIGZAG RIDGE) ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Coefficients (Weights) - Ridge Interpretation of ZigZag Levels:")
    for i, col in enumerate(feature_cols):
        importance = np.mean(np.abs(clf.coef_[:, i]))
        print(f"  {col}: {importance:.4f}")

    os.makedirs("../models", exist_ok=True)
    joblib.dump(scaler, '../models/macro_scaler_M1_zigzag.pkl')
    joblib.dump(clf, '../models/macro_ridge_M1_zigzag.pkl')
    print("\n✅ ZigZag Pipeline saved to Macro_Regime/models/")

if __name__ == "__main__":
    main()
