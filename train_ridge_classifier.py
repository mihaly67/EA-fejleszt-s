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

    # 1. Load Data (Mocking a path for now, user will provide CSV via MQL5 miner)
    # df = pd.read_csv("Macro_Regime/data/Macro_MGCQ_PERIOD_M15.csv")

    # FOR TESTING: Create dummy DataFrame
    print("Generating dummy structural data for testing pipeline...")
    dates = pd.date_range("2026-01-01", periods=1000, freq="15min")
    close = np.cumsum(np.random.randn(1000)) + 4000
    df = pd.DataFrame({'Time': dates, 'Open': close, 'High': close+2, 'Low': close-2, 'Close': close})

    # 2. Engineer Features
    df_features = process_macro_features(df)

    # 3. Apply Labels
    df_labeled = label_macro_regime(df_features, lookahead=5, trend_threshold=0.0005)

    # Define features
    feature_cols = ['Log_Return', 'Rolling_Vol_20', 'Dist_to_Max_50', 'Dist_to_Min_50', 'Dist_Nearest_Level']

    X = df_labeled[feature_cols]
    y = df_labeled['Macro_Label']

    print(f"\nDataset shape: {X.shape}")
    print(f"Class distribution:\n{y.value_counts()}")

    # 4. Train/Test Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

    # 5. Scale Data (Ridge is very sensitive to unscaled data)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 6. Train Ridge Classifier
    print("\nTraining Ridge Classifier...")
    # alpha is the L2 regularization strength
    clf = RidgeClassifier(alpha=1.0, class_weight='balanced')
    clf.fit(X_train_scaled, y_train)

    # 7. Evaluate
    y_pred = clf.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)

    print(f"\n--- EVALUATION RESULTS ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("\nFeature Coefficients (Weights):")
    for i, col in enumerate(feature_cols):
        # Multi-class Ridge returns a matrix of coefs. We take the mean abs weight as importance.
        importance = np.mean(np.abs(clf.coef_[:, i]))
        print(f"  {col}: {importance:.4f}")

    # 8. Save Pipeline
    # joblib.dump(scaler, 'Macro_Regime/models/macro_scaler.pkl')
    # joblib.dump(clf, 'Macro_Regime/models/macro_ridge.pkl')
    print("\n✅ Pipeline test complete.")

if __name__ == "__main__":
    main()
