import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import shap
import matplotlib.pyplot as plt
import os

def main():
    print("=== 🔬 DEEP SHAP: SHORT 'NOISE' TRAP ANALYZER ===")
    print("Investigating why the model calls valid Short entries 'Noise'.")

    data_path = "../data/exam_blind_fused.csv"
    df = pd.read_csv(data_path)

    label_path = "../data/exam_blind_labeled_v5.csv"
    df_labels = pd.read_csv(label_path)
    df = pd.merge(df, df_labels[['Target_Label']], left_index=True, right_index=True)

    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
    df['DateOnly'] = df['End_Timestamp'].dt.date

    target_date = pd.to_datetime("2026-07-23").date()
    exam_raw = df[df['DateOnly'] == target_date].copy()

    if len(exam_raw) == 0:
        print("Error: Exam day is empty.")
        return

    print("Loading Pre-trained V5 Fusion LGBM Model...")
    clf = joblib.load('../models/lgbm_model_fusion_v5_tuned.pkl')
    booster = clf.booster_
    model_features = booster.feature_name()

    X_exam = exam_raw[model_features]
    y_exam_true = exam_raw['Target_Label'].values

    print("Running Inference...")
    probs = clf.predict_proba(X_exam)

    # Raw argmax prediction (0=Downtrend, 1=Noise, 2=Uptrend)
    y_pred = clf.predict(X_exam)

    # -------------------------------------------------------------
    # ISOLATE FALSE NEGATIVES FOR SHORTS (Missed Opportunities)
    # The market dropped (Target = -1), BUT the model predicted Noise (1)
    # -------------------------------------------------------------
    missed_short_idx = np.where((y_exam_true == -1) & (y_pred == 1))[0]

    if len(missed_short_idx) == 0:
        print("No missed short trends found! Model captured all of them.")
        return

    print(f"\nFound {len(missed_short_idx)} valid Short breakouts that the model ignored (labeled as Noise).")
    print("Calculating SHAP values for these specific failures...")

    X_missed_shorts = X_exam.iloc[missed_short_idx]

    explainer = shap.TreeExplainer(booster)
    shap_values = explainer.shap_values(X_missed_shorts)

    # We want to see why it predicted NOISE (Class index 1)
    if isinstance(shap_values, list):
        shap_noise_impact = shap_values[1]
    else:
        shap_noise_impact = shap_values[:, :, 1]

    # Calculate Mean Absolute SHAP Impact for the Noise Class on these specific rows
    mean_shap = np.abs(shap_noise_impact).mean(axis=0)

    feature_importance_df = pd.DataFrame({
        'Feature': model_features,
        'SHAP_Drive_to_Noise': mean_shap
    }).sort_values(by='SHAP_Drive_to_Noise', ascending=False)

    print("\n🚨 TOP FEATURES PARALYZING THE MODEL (Causing it to miss Shorts):")
    print("These features gave the 'Noise' signal instead of letting the Short execute:")
    print(feature_importance_df.head(10).to_string(index=False))

    # Single Prediction Deep Dive
    print("\n--- DEEP DIVE: THE MOST CONFIDENT FALSE NOISE TRAP (Missed Short) ---")
    # Find the row where it was MOST confident it was noise, but it was actually a short
    P_Noise_Array = probs[missed_short_idx, 1]
    worst_local_idx = np.argmax(P_Noise_Array)
    worst_global_idx = missed_short_idx[worst_local_idx]

    print(f"Timestamp: {exam_raw['End_Timestamp'].iloc[worst_global_idx]}")
    print(f"Model P_Noise Confidence: {probs[worst_global_idx, 1]*100:.1f}%")
    print(f"Model P_Short Confidence: {probs[worst_global_idx, 0]*100:.1f}%")

    print("\nFeature values exactly at this missed opportunity:")
    trap_row = X_exam.iloc[worst_global_idx]
    for feat in model_features:
        print(f"  {feat}: {trap_row[feat]:.4f}")

if __name__ == "__main__":
    main()
