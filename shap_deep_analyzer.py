import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import shap

def main():
    print("=== 🔬 DEEP SHAP ANALYZER: DECODING FALSE POSITIVES (WHIPSAW STOPOUTS) ===")

    # We must load the FUSED data which has all the features, not just the labels
    data_path = "../data/exam_blind_fused.csv"
    print(f"Loading strict V5 fused data from: {data_path}")
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

    print("Loading Pre-trained Fusion LGBM Model (Tuned)...")
    clf = joblib.load('../models/lgbm_model_fusion_v4_tuned.pkl')
    booster = clf.booster_
    model_features = booster.feature_name()

    X_exam = exam_raw[model_features]
    y_exam_true = exam_raw['Target_Label'].values

    print("Running Inference...")
    probs = clf.predict_proba(X_exam)
    P_Short = probs[:, 0]
    P_Noise = probs[:, 1]
    P_Long = probs[:, 2]

    # ISOLATE FALSE POSITIVES (Whipsaws)
    # The model predicted strong Long (P_Long > 0.50) BUT the actual Strict Wick Label is Noise (0) or Short (-1)
    false_long_idx = np.where((P_Long > 0.50) & (y_exam_true <= 0))[0]

    if len(false_long_idx) == 0:
        print("No False Longs found above threshold on this day! The model is clean.")
        return

    print(f"Identified {len(false_long_idx)} False Long Traps (Whipsaws/Stopouts). Calculating Deep SHAP...")

    X_traps = X_exam.iloc[false_long_idx]

    explainer = shap.TreeExplainer(booster)
    shap_values = explainer.shap_values(X_traps)

    # shap_values[2] is the output for class 2 (Uptrend / Long)
    # We want to see what convinced the model to go Long on these trap rows
    if isinstance(shap_values, list):
        shap_long_traps = shap_values[2]
    else:
        shap_long_traps = shap_values[:, :, 2]

    mean_shap_traps = np.abs(shap_long_traps).mean(axis=0)

    feature_importance_df = pd.DataFrame({
        'Feature': model_features,
        'Mean_SHAP_Impact_on_False_Longs': mean_shap_traps
    }).sort_values(by='Mean_SHAP_Impact_on_False_Longs', ascending=False)

    print("\n🚨 TOP FEATURES DRIVING THE MACHINE INTO DEADLY WICK TRAPS:")
    print("These features gave the false 'Green Light' right before a stop-out:")
    print(feature_importance_df.to_string(index=False))

    # Single Prediction Deep Dive (Examine the worst trap)
    print("\n--- DEEP DIVE: THE WORST FALSE LONG TRAP ---")
    worst_idx = np.argmax(P_Long[false_long_idx])
    global_idx = false_long_idx[worst_idx]

    print(f"Timestamp: {exam_raw['End_Timestamp'].iloc[global_idx]}")
    print(f"Actual Label: {y_exam_true[global_idx]} (0=Noise, -1=Short)")
    print(f"Model P_Long Confidence: {P_Long[global_idx]*100:.1f}%")
    print(f"Model P_Noise Confidence: {P_Noise[global_idx]*100:.1f}%")

    print("\nFeature values exactly at this micro-second trap:")
    trap_row = X_exam.iloc[global_idx]
    for feat in model_features:
        print(f"  {feat}: {trap_row[feat]:.4f}")

if __name__ == "__main__":
    main()
