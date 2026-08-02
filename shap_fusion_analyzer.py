import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import shap

def main():
    print("=== 🔬 SHAP DIAGNOSTIC ANALYZER: DECODING THE NOISE (0) CLASS ===")

    data_path = "../data/exam_blind_labeled.csv"
    print(f"Loading data from: {data_path}")
    df = pd.read_csv(data_path)
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
    df['DateOnly'] = df['End_Timestamp'].dt.date

    target_date = pd.to_datetime("2026-07-23").date()
    exam_raw = df[df['DateOnly'] == target_date].copy()

    if len(exam_raw) == 0:
        print("Error: Exam day is empty.")
        return

    print("Loading Pre-trained Fusion LGBM Model...")
    clf = joblib.load('../models/lgbm_model_fusion_v4.pkl')
    booster = clf.booster_
    model_features = booster.feature_name()

    print(f"Model was trained on {len(model_features)} features.")

    X_exam = exam_raw[model_features]

    print("Calculating SHAP values for the exam dataset...")
    explainer = shap.TreeExplainer(booster)
    shap_values = explainer.shap_values(X_exam)

    # Check shape of shap_values. LightGBM shap_values output can vary by version.
    print(f"SHAP output type: {type(shap_values)}, length: {len(shap_values) if isinstance(shap_values, list) else shap_values.shape}")

    if isinstance(shap_values, list):
        # shap_values[1] is the output for class index 1 (which corresponds to target_label 0 / 'Noise')
        shap_noise = shap_values[1]
    else:
        # If it returns a 3D array: (samples, classes, features) or (samples, features, classes)
        if len(shap_values.shape) == 3:
             # usually (samples, features, classes)
             shap_noise = shap_values[:, :, 1]
        else:
             print("Unexpected SHAP shape.")
             return

    # Calculate mean absolute SHAP values for the Noise class
    mean_shap_noise = np.abs(shap_noise).mean(axis=0)

    print(f"mean_shap_noise shape: {mean_shap_noise.shape}")
    print(f"model_features length: {len(model_features)}")

    feature_importance_df = pd.DataFrame({
        'Feature': model_features,
        'Mean_SHAP_Impact_on_Noise': mean_shap_noise
    }).sort_values(by='Mean_SHAP_Impact_on_Noise', ascending=False)

    print("\n🚨 TOP 15 FEATURES DRIVING THE 'NOISE' (0) PREDICTIONS:")
    print("These are the features confusing the model and causing it to stay flat:")
    print(feature_importance_df.head(15).to_string(index=False))

if __name__ == "__main__":
    main()
