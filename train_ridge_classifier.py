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
    print("=== 🏗️ STRUCTURAL MACRO REGIME MODEL (RIDGE CLASSIFIER) ===")

    # Load Real Data from the MQL5 Miner
    data_path = "../data/Macro_GCEQ26_PERIOD_M15.csv"
    print(f"Loading real macro data from: {data_path}")

    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        # Fallback to absolute path if running from weird dir
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Macro_GCEQ26_PERIOD_M15.csv")

    print(f"Loaded {len(df)} rows.")

    # 2. Engineer Features
    df_features = process_macro_features(df)

    # 3. Apply Labels
    # For M15, a lookahead of 4 means 1 hour into the future.
    df_labeled = label_macro_regime(df_features, lookahead=4, trend_threshold=0.0005)

    # Define features
    feature_cols = ['Log_Return', 'Rolling_Vol_20', 'Dist_to_Max_50', 'Dist_to_Min_50', 'Dist_Nearest_Level']

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    if len(X) < 100:
        print("Error: Dataset too small after processing.")
        return

    # 4. Train/Test Split (Time-Series Split)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

    # 5. Scale Data (Ridge is very sensitive to unscaled data)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 6. Train Ridge Classifier
    print("\nTraining Ridge Classifier...")
    clf = RidgeClassifier(alpha=1.0, class_weight='balanced')
    clf.fit(X_train_scaled, y_train)

    # 7. Evaluate
    y_pred = clf.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (M15 REAL DATA) ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Coefficients (Weights):")
    for i, col in enumerate(feature_cols):
        # Multi-class Ridge returns a matrix of coefs. We take the mean abs weight as importance.
        importance = np.mean(np.abs(clf.coef_[:, i]))
        print(f"  {col}: {importance:.4f}")

    # 8. Save Pipeline
    import os
    os.makedirs("../models", exist_ok=True)
    joblib.dump(scaler, '../models/macro_scaler.pkl')
    joblib.dump(clf, '../models/macro_ridge.pkl')
    print("\n✅ Pipeline saved to Macro_Regime/models/")

if __name__ == "__main__":
    main()
