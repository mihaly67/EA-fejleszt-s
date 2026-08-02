import pandas as pd
import numpy as np
import lightgbm as lgb
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import joblib
from sklearn.metrics import accuracy_score, classification_report

def main():
    print("=== 🎓 FUSION LGBM BLIND EXAM V5 (JULY 23, 2026) ===")

    # We must load the FUSED data which has all the features
    data_path = "../data/exam_blind_fused.csv"
    print(f"Loading data from: {data_path}")
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

    print(f"Selecting BLIND EXAM DAY: {target_date} (0-24h)")

    print("Loading Pre-trained V5 Fusion LGBM Model...")
    clf = joblib.load('../models/lgbm_model_fusion_v5_tuned.pkl')
    booster = clf.booster_
    model_features = booster.feature_name()

    X_exam = exam_raw[model_features]
    y_exam_true = exam_raw['Target_Label'].values + 1 # 0, 1, 2

    print("Running Inference on Blind Exam Day...")
    probs = clf.predict_proba(X_exam)
    y_pred = clf.predict(X_exam)

    acc = accuracy_score(y_exam_true, y_pred)
    print(f"\n--- BLIND EVALUATION RESULTS ---")
    print(f"Accuracy: {acc*100:.2f}%")
    print("\nClassification Report (0=Downtrend, 1=Range, 2=Uptrend):")
    print(classification_report(y_exam_true, y_pred, zero_division=0))

    P_Short = probs[:, 0]
    P_Noise = probs[:, 1]
    P_Long = probs[:, 2]

    exam_raw['P_Short'] = P_Short
    exam_raw['P_Noise'] = P_Noise
    exam_raw['P_Long'] = P_Long

    # Apply the 2D Optuna Threshold
    P_SIGNAL_MIN = 0.494
    P_NOISE_MAX = 0.351

    signals = []
    for i in range(len(probs)):
        if P_Long[i] > P_SIGNAL_MIN and P_Noise[i] < P_NOISE_MAX and P_Long[i] > P_Short[i]:
            signals.append(1)
        elif P_Short[i] > P_SIGNAL_MIN and P_Noise[i] < P_NOISE_MAX and P_Short[i] > P_Long[i]:
            signals.append(-1)
        else:
            signals.append(0)

    exam_raw['Prediction'] = signals

    print("Generating HTML Visualization...")
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True, vertical_spacing=0.05, row_heights=[0.7, 0.3])

    fig.add_trace(go.Candlestick(
        x=exam_raw['End_Timestamp'],
        open=exam_raw['Open'], high=exam_raw['High'], low=exam_raw['Low'], close=exam_raw['Close'],
        name='Price'
    ), row=1, col=1)

    ups = exam_raw[exam_raw['Prediction'] == 1]
    downs = exam_raw[exam_raw['Prediction'] == -1]
    noise = exam_raw[exam_raw['Prediction'] == 0]

    fig.add_trace(go.Scatter(
        x=ups['End_Timestamp'], y=ups['Low'] - 0.5,
        mode='markers', marker=dict(symbol='triangle-up', color='lime', size=14),
        name=f'CLEAN UPTREND'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=downs['End_Timestamp'], y=downs['High'] + 0.5,
        mode='markers', marker=dict(symbol='triangle-down', color='red', size=14),
        name=f'CLEAN DOWNTREND'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=noise['End_Timestamp'], y=noise['Open'],
        mode='markers', marker=dict(symbol='x', color='gray', size=6, opacity=0.5),
        name='Noise/Whipsaw Trap'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Short'], mode='lines', line=dict(color='red', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'), row=2, col=1)

    fig.add_hline(y=P_SIGNAL_MIN, line_dash="dash", line_color="white", row=2, col=1, annotation_text="Min Signal Prob")
    fig.add_hline(y=P_NOISE_MAX, line_dash="dash", line_color="gray", row=2, col=1, annotation_text="Max Noise Prob")

    fig.update_layout(
        title=f"LGBM V5 Blind Exam (07/23/2026) | 2D Threshold (Wick-Aware)",
        yaxis_title="Price", yaxis2_title="Probability",
        xaxis_rangeslider_visible=False, template="plotly_dark", height=1000
    )

    html_path = "../data/lgbm_blind_exam_July23_V5.html"
    fig.write_html(html_path)
    print(f"✅ Visualization saved to {html_path}")

if __name__ == "__main__":
    main()
