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
    print("=== 🏗️ STRUCTURAL MACRO REGIME MODEL (MULTI-PARAM AMA GEOMETRY) ===")

    # Load Real M1 Data (Raw OHLCV)
    data_path = "../data/Macro_GCEQ26_PERIOD_M1.csv"
    print(f"Loading real raw macro data from: {data_path}")

    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Macro_GCEQ26_PERIOD_M1.csv")

    print(f"Loaded {len(df)} rows.")

    # 2. Engineer Multi-Param AMA Geometric Features
    df_features = process_macro_features(df)

    # 3. Apply Dynamic Labels
    # Lookahead=5 (5 minutes on M1 timeframe). atr_multiplier=1.0.
    df_labeled = label_macro_regime(df_features, lookahead=5, atr_multiplier=1.0)

    # Define explicitly the new AMA Array features
    feature_cols = [
        'X_micro_ama1_dist', 'X_micro_ama2_dist',
        'X_int_ama1_dist', 'X_int_ama2_dist',
        'X_macro_ama1_dist',
        'Slope_AMA_M1', 'Slope_AMA_M5', 'Slope_AMA_M15',
        'X_pivot_dist'
    ]

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    if len(X) < 100:
        print("Error: Dataset too small.")
        return

    # 4. Train/Test Split (Time-Series Split)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

    # 5. Scale Data
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 6. Train Ridge Classifier
    print("\nTraining Multi-Param AMA Ridge Classifier...")
    clf = RidgeClassifier(alpha=1.0, class_weight='balanced')
    clf.fit(X_train_scaled, y_train)

    # 7. Evaluate
    y_pred = clf.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS (MULTI-PARAM AMA RIDGE) ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Coefficients (Weights) - The Ridge Model's Chosen AMA Parameters:")
    for i, col in enumerate(feature_cols):
        importance = np.mean(np.abs(clf.coef_[:, i]))
        print(f"  {col}: {importance:.4f}")

    # 8. Save Pipeline
    os.makedirs("../models", exist_ok=True)
    joblib.dump(scaler, '../models/macro_scaler_M1_ama.pkl')
    joblib.dump(clf, '../models/macro_ridge_M1_ama.pkl')
    print("\n✅ Multi-Param AMA Pipeline saved to Macro_Regime/models/")

if __name__ == "__main__":
    main()
