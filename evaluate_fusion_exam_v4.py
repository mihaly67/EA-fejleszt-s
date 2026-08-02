import pandas as pd
import numpy as np
import lightgbm as lgb
from sklearn.preprocessing import StandardScaler
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import joblib

def main():
    print("=== 🎓 FUSION LGBM OUT-OF-SAMPLE EXAM (V4: JULY 16) ===")

    # Load Fused Data
    data_path = "../data/fused_features_dollar_bars.csv"
    df = pd.read_csv(data_path)
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])
    df['DateOnly'] = df['End_Timestamp'].dt.date

    # Load V4 Labels
    label_path = "../data/labeled_dollar_bars_v4_5bar.csv"
    df_labels = pd.read_csv(label_path)
    df = pd.merge(df, df_labels[['Target_Label']], left_index=True, right_index=True)

    target_date = pd.to_datetime("2026-07-16").date()
    exam_raw = df[df['DateOnly'] == target_date].copy()
    train_raw = df[df['DateOnly'] < target_date].copy()

    if len(exam_raw) == 0:
        print("Error: Exam day is empty.")
        return

    print(f"Selecting EXAM DAY: {target_date} (Strictly isolated from training)")

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

    existing_features = [f for f in features if f in df.columns]

    X_train = train_raw[existing_features]
    y_train = train_raw['Target_Label'] + 1
    X_exam = exam_raw[existing_features]

    print("Training Fusion LGBM V4 on Historical Data...")
    clf = lgb.LGBMClassifier(
        n_estimators=1000,
        learning_rate=0.05,
        num_leaves=31,
        class_weight='balanced',
        objective='multiclass',
        random_state=42,
        n_jobs=-1
    )
    clf.fit(X_train, y_train)

    print("Running Inference on Exam Day...")
    probs = clf.predict_proba(X_exam)

    P_Short = probs[:, 0]
    P_Noise = probs[:, 1]
    P_Long = probs[:, 2]

    exam_raw['P_Short'] = P_Short
    exam_raw['P_Noise'] = P_Noise
    exam_raw['P_Long'] = P_Long

    THRESHOLD = 0.53 # A bit stricter for V4
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

    dollar_bars_full = pd.read_csv("../data/dollar_bars_3MTF.csv")
    dollar_bars_full['End_Timestamp'] = pd.to_datetime(dollar_bars_full['End_Timestamp'])
    exam_ohlc = dollar_bars_full[dollar_bars_full['End_Timestamp'].dt.date == target_date].copy()

    exam_viz = pd.merge(exam_ohlc, exam_raw[['End_Timestamp', 'Prediction', 'P_Long', 'P_Short', 'P_Noise']], on='End_Timestamp', how='inner')

    fig.add_trace(go.Candlestick(
        x=exam_viz['End_Timestamp'],
        open=exam_viz['Open'], high=exam_viz['High'], low=exam_viz['Low'], close=exam_viz['Close'],
        name='Price'
    ), row=1, col=1)

    ups = exam_viz[exam_viz['Prediction'] == 1]
    downs = exam_viz[exam_viz['Prediction'] == -1]
    noise = exam_viz[exam_viz['Prediction'] == 0]

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

    fig.add_trace(go.Scatter(x=exam_viz['End_Timestamp'], y=exam_viz['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_viz['End_Timestamp'], y=exam_viz['P_Short'], mode='lines', line=dict(color='red', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_viz['End_Timestamp'], y=exam_viz['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'), row=2, col=1)

    fig.add_hline(y=THRESHOLD, line_dash="dash", line_color="white", row=2, col=1)

    fig.update_layout(
        title=f"LGBM Feature Fusion V4 (Exam Day: {target_date}) | 5-Bar Strict Target",
        yaxis_title="Price", yaxis2_title="Probability",
        xaxis_rangeslider_visible=False, template="plotly_dark", height=1000
    )

    html_path = "../data/lgbm_fusion_exam_July16_V4.html"
    fig.write_html(html_path)
    print(f"✅ Visualization saved to {html_path}")

if __name__ == "__main__":
    main()
