import pandas as pd
import numpy as np
from catboost import CatBoostClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

from macro_feature_engineer import process_macro_features
from macro_labeler import label_macro_regime

def main():
    print("=== 🏗️ STRUCTURAL MACRO REGIME MODEL (PURE ZIGZAG - ABLATION STUDY) ===")

    data_path = "../data/Master_ZigZag_GCEQ26_M1.csv"
    print(f"Loading raw ZigZag data from: {data_path}")

    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv")

    print(f"Loaded {len(df)} rows.")

    # 2. Engineer Features
    df_features = process_macro_features(df)

    # 3. Apply Labels
    # Lookahead=5, atr_multiplier=1.0 (Based on Optuna baseline testing)
    df_labeled = label_macro_regime(df_features, lookahead=5, atr_multiplier=1.0)

    # Define EXPLICITLY PURE ZIGZAG features (Stochastic Excluded)
    feature_cols = [
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S'
    ]

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    if len(X) < 100:
        print("Error: Dataset too small.")
        return

    y_shifted = y + 1

    X_train, X_test, y_train, y_test = train_test_split(X, y_shifted, test_size=0.2, shuffle=False)

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    print("\nTraining CatBoost Classifier (PURE GEOMETRY)...")
    clf = CatBoostClassifier(
        iterations=500,
        learning_rate=0.05,
        depth=6,
        auto_class_weights='Balanced',
        loss_function='MultiClass',
        verbose=100
    )

    clf.fit(X_train_scaled, y_train)

    y_pred = clf.predict(X_test_scaled).flatten()
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (PURE ZIGZAG GEOMETRY) ---")
    print(f"Accuracy: {acc*100:.2f}%")

    print("\nClassification Report (0=Downtrend, 1=Range, 2=Uptrend):")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Importances (CatBoost Symmetric Trees):")
    importances = clf.get_feature_importance()
    for col, imp in zip(feature_cols, importances):
        print(f"  {col}: {imp:.4f}%")

if __name__ == "__main__":
    main()
