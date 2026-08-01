import pandas as pd
import numpy as np
from sklearn.linear_model import RidgeClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib

from macro_feature_engineer import process_macro_features
from macro_labeler import label_macro_regime

def main():
    print("=== 🏗️ STRUCTURAL MACRO REGIME MODEL (RIDGE CLASSIFIER - M1 MICRO-TRENDS) ===")

    # Load Real Data from the M1 MQL5 Miner
    data_path = "../data/Macro_GCEQ26_PERIOD_M1.csv"
    print(f"Loading real macro data from: {data_path}")

    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Macro_GCEQ26_PERIOD_M1.csv")

    print(f"Loaded {len(df)} rows.")

    # 2. Engineer Features (ATR normalized)
    df_features = process_macro_features(df)

    # 3. Apply Dynamic Labels
    # User feedback: Micro-trends happen in 5 bars (1-minute window).
    # Lookahead=5 (5 minutes).
    # If the price moves by more than 1.0 ATR in 5 minutes, it's a solid trend.
    df_labeled = label_macro_regime(df_features, lookahead=5, atr_multiplier=1.0)

    # Define features
    feature_cols = ['Log_Return', 'Vol_State', 'Dist_to_Max_50_ATR', 'Dist_to_Min_50_ATR', 'Dist_Nearest_Level_ATR']

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    if len(X) < 100:
        print("Error: Dataset too small after processing.")
        return

    # 4. Train/Test Split (Time-Series Split)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

    # 5. Scale Data
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 6. Train Ridge Classifier
    print("\nTraining Ridge Classifier on M1 Micro-Trends...")
    clf = RidgeClassifier(alpha=1.0, class_weight='balanced')
    clf.fit(X_train_scaled, y_train)

    # 7. Evaluate
    y_pred = clf.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (M1 REAL DATA) ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Coefficients (Weights):")
    for i, col in enumerate(feature_cols):
        importance = np.mean(np.abs(clf.coef_[:, i]))
        print(f"  {col}: {importance:.4f}")

    # 8. Save Pipeline
    import os
    os.makedirs("../models", exist_ok=True)
    joblib.dump(scaler, '../models/macro_scaler_M1.pkl')
    joblib.dump(clf, '../models/macro_ridge_M1.pkl')
    print("\n✅ M1 Pipeline saved to Macro_Regime/models/")

if __name__ == "__main__":
    main()
