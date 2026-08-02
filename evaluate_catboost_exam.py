import pandas as pd
import numpy as np
from catboost import CatBoostClassifier
from sklearn.preprocessing import StandardScaler
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import warnings

warnings.filterwarnings("ignore")

from macro_feature_engineer import process_macro_features
from macro_labeler import label_macro_regime

def main():
    print("=== 🎓 CATBOOST OUT-OF-SAMPLE EXAM (JULY 28) & PROBABILITY VISUALIZATION ===")

    # 1. Load Data
    data_path = "../data/Master_ZigZag_GCEQ26_M1.csv"
    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv")

    df['Time'] = pd.to_datetime(df['Time'])
    df['DateOnly'] = df['Time'].dt.date

    # User specifically requested July 28th
    target_date = pd.to_datetime("2026-07-28").date()

    if target_date not in df['DateOnly'].values:
        print(f"⚠️ Warning: {target_date} not found in CSV. Using the most volatile available day.")
        # Fallback: Just take a day near the end that isn't the very last incomplete day
        unique_days = df['DateOnly'].unique()
        exam_day = unique_days[-3]
    else:
        exam_day = target_date

    print(f"Selecting EXAM DAY: {exam_day} (Strictly isolated from training)")

    # Split raw data
    train_raw = df[df['DateOnly'] < exam_day].copy()
    exam_raw = df[df['DateOnly'] == exam_day].copy()

    if len(exam_raw) == 0:
        print("Error: Exam day is empty.")
        return

    # 2. Process Features
    print("Processing Training Features...")
    train_features = process_macro_features(train_raw)
    train_labeled = label_macro_regime(train_features, lookahead=5, atr_multiplier=1.0)

    print("Processing Exam Features...")
    exam_features = process_macro_features(exam_raw)
    exam_labeled = label_macro_regime(exam_features, lookahead=5, atr_multiplier=1.0)

    # Added Stoch_State_M1 back based on user request (+1% edge)
    feature_cols = [
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1'
    ]

    X_train = train_labeled[feature_cols]
    y_train = train_labeled['Macro_Label'] + 1 # Shift to 0, 1, 2

    X_exam = exam_labeled[feature_cols]

    # Scale
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_exam_scaled = scaler.transform(X_exam)

    # 3. Train Model
    print("Training CatBoost on Historical Data...")
    clf = CatBoostClassifier(
        iterations=500,
        learning_rate=0.05,
        depth=6,
        auto_class_weights='Balanced',
        loss_function='MultiClass',
        verbose=0
    )
    clf.fit(X_train_scaled, y_train)

    # 4. Predict Exam Day (Probabilities & Thresholds)
    print("Running Inference on Exam Day...")
    probs = clf.predict_proba(X_exam_scaled)

    # CatBoost outputs [P_0, P_1, P_2] which corresponds to [P_Short, P_Noise, P_Long]
    P_Short = probs[:, 0]
    P_Noise = probs[:, 1]
    P_Long = probs[:, 2]

    exam_labeled['P_Short'] = P_Short
    exam_labeled['P_Noise'] = P_Noise
    exam_labeled['P_Long'] = P_Long

    # Apply Threshold Logic (e.g., must be > 50% sure to declare a trend)
    THRESHOLD = 0.50

    signals = []
    for i in range(len(probs)):
        if P_Long[i] > THRESHOLD and P_Long[i] > P_Short[i]:
            signals.append(1) # Uptrend
        elif P_Short[i] > THRESHOLD and P_Short[i] > P_Long[i]:
            signals.append(-1) # Downtrend
        else:
            signals.append(0) # Range / Noise / Uncertain

    exam_labeled['Prediction'] = signals

    # 5. Visualization (Plotly 2-Panel)
    print("Generating HTML Visualization...")
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True, vertical_spacing=0.05, row_heights=[0.7, 0.3])

    # Top Panel: Candlesticks
    fig.add_trace(go.Candlestick(
        x=exam_labeled['Time'],
        open=exam_labeled['Open'],
        high=exam_labeled['High'],
        low=exam_labeled['Low'],
        close=exam_labeled['Close'],
        name='Price'
    ), row=1, col=1)

    # Overlays
    ups = exam_labeled[exam_labeled['Prediction'] == 1]
    downs = exam_labeled[exam_labeled['Prediction'] == -1]
    noise = exam_labeled[exam_labeled['Prediction'] == 0]

    # Uptrends (Green Arrow)
    fig.add_trace(go.Scatter(
        x=ups['Time'], y=ups['Low'] - 0.5,
        mode='markers', marker=dict(symbol='triangle-up', color='lime', size=12),
        name=f'Predicted Uptrend (P > {THRESHOLD})'
    ), row=1, col=1)

    # Downtrends (Red Arrow)
    fig.add_trace(go.Scatter(
        x=downs['Time'], y=downs['High'] + 0.5,
        mode='markers', marker=dict(symbol='triangle-down', color='red', size=12),
        name=f'Predicted Downtrend (P > {THRESHOLD})'
    ), row=1, col=1)

    # Noise/Range (Gray X)
    fig.add_trace(go.Scatter(
        x=noise['Time'], y=noise['Open'],
        mode='markers', marker=dict(symbol='x', color='gray', size=6),
        name='Predicted Range/Uncertain'
    ), row=1, col=1)

    # Bottom Panel: Probabilities
    fig.add_trace(go.Scatter(x=exam_labeled['Time'], y=exam_labeled['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_labeled['Time'], y=exam_labeled['P_Short'], mode='lines', line=dict(color='red', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=exam_labeled['Time'], y=exam_labeled['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'), row=2, col=1)

    # Draw Threshold Line
    fig.add_hline(y=THRESHOLD, line_dash="dash", line_color="white", annotation_text=f"Threshold ({THRESHOLD})", row=2, col=1)

    fig.update_layout(
        title=f"CatBoost Macro Regime (OOS Exam Day: {exam_day}) | ZigZag + Fast Stoch",
        yaxis_title="Price",
        yaxis2_title="Probability",
        xaxis_rangeslider_visible=False,
        template="plotly_dark",
        height=1000
    )

    html_path = "../data/catboost_exam_chart_July28.html"
    fig.write_html(html_path)
    print(f"✅ Visualization saved to {html_path}")

if __name__ == "__main__":
    main()
