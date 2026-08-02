import pandas as pd
import numpy as np
import lightgbm as lgb
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import joblib
from sklearn.metrics import accuracy_score, classification_report

def main():
    print("=== 🎓 FUSION LGBM BLIND EXAM (JULY 23, 2026) ===")

    # Load Labeled Exam Data
    data_path = "../data/exam_blind_labeled.csv"
    df = pd.read_csv(data_path)
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
    df['DateOnly'] = df['End_Timestamp'].dt.date

    target_date = pd.to_datetime("2026-07-23").date()
    exam_raw = df[df['DateOnly'] == target_date].copy()

    if len(exam_raw) == 0:
        print(f"Error: Exam day {target_date} is empty.")
        print(df['DateOnly'].unique())
        return

    print(f"Selecting BLIND EXAM DAY: {target_date} (0-24h)")

    features = [
        'Tick_Speed', 'Micro_Trend', 'Macro_Trend', 'Imbalance_L1', 'Imbalance_L2',
        'Imbalance_L3', 'Imbalance_L4', 'Imbalance_L5', 'Imbalance_L6',
        'Imbalance_L7', 'Imbalance_L8', 'Imbalance_L9', 'Imbalance_L10',
        'CVD_Raw', 'CVD_Rolling_10', 'Cancel_Rate_Rolling_10',
        'Trade_Size_Imbalance', 'Spread_ZScore',
        'M5_RSI_7', 'M15_RSI_14', 'ATR_Micro', 'Velocity_Micro',
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1'
    ]

    existing_features = [f for f in features if f in exam_raw.columns]

    X_exam = exam_raw[existing_features]
    y_exam_true = exam_raw['Target_Label'] + 1 # 0, 1, 2

    print("Loading Pre-trained Fusion LGBM Model (Trained exclusively up to July 17)...")
    clf = joblib.load('../models/lgbm_model_fusion_v4.pkl')

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

    THRESHOLD = 0.55 # Setting a strict threshold to filter noise
    signals = []
    for i in range(len(probs)):
        if P_Long[i] > THRESHOLD and P_Long[i] > P_Short[i]:
            signals.append(1)
        elif P_Short[i] > THRESHOLD and P_Short[i] > P_Long[i]:
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
        mode='markers', marker=dict(symbol='triangle-up', color='lime', size=12),
        name=f'Predicted Uptrend (P > {THRESHOLD})'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=downs['End_Timestamp'], y=downs['High'] + 0.5,
        mode='markers', marker=dict(symbol='triangle-down', color='red', size=12),
        name=f'Predicted Downtrend (P > {THRESHOLD})'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=noise['End_Timestamp'], y=noise['Open'],
        mode='markers', marker=dict(symbol='x', color='gray', size=6),
        name='Noise/Range'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Short'], mode='lines', line=dict(color='red', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_raw['End_Timestamp'], y=exam_raw['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'), row=2, col=1)

    fig.add_hline(y=THRESHOLD, line_dash="dash", line_color="white", row=2, col=1)

    fig.update_layout(
        title=f"LGBM Fusion Blind Exam (07/23/2026) | DOM + ZigZag Pivot Walls",
        yaxis_title="Price", yaxis2_title="Probability",
        xaxis_rangeslider_visible=False, template="plotly_dark", height=1000
    )

    html_path = "../data/lgbm_blind_exam_July23.html"
    fig.write_html(html_path)
    print(f"✅ Visualization saved to {html_path}")

if __name__ == "__main__":
    main()
