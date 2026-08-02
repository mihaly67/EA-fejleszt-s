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
    print("=== 🎓 CATBOOST OUT-OF-SAMPLE EXAM & VISUALIZATION ===")

    # 1. Load Data
    data_path = "../data/Master_ZigZag_GCEQ26_M1.csv"
    try:
        df = pd.read_csv(data_path)
    except FileNotFoundError:
        df = pd.read_csv("/home/misi/LGBM_mlops/Macro_Regime/data/Master_ZigZag_GCEQ26_M1.csv")

    # Ensure Time is datetime
    df['Time'] = pd.to_datetime(df['Time'])

    # 2. Extract exactly one 24-hour day from the end of the dataset to be the EXAM.
    # Let's take the second-to-last unique day to ensure it's a full 24h block.
    df['DateOnly'] = df['Time'].dt.date
    unique_days = df['DateOnly'].unique()
    exam_day = unique_days[-2]

    print(f"Selecting EXAM DAY: {exam_day} (Strictly isolated from training)")

    # Split raw data
    train_raw = df[df['DateOnly'] < exam_day].copy()
    exam_raw = df[df['DateOnly'] == exam_day].copy()

    # We must process features INDEPENDENTLY to avoid leakage
    print("Processing Training Features...")
    train_features = process_macro_features(train_raw)
    train_labeled = label_macro_regime(train_features, lookahead=5, atr_multiplier=1.0)

    print("Processing Exam Features...")
    exam_features = process_macro_features(exam_raw)
    # We don't actually need labels for inference, but we label it to calculate accuracy
    exam_labeled = label_macro_regime(exam_features, lookahead=5, atr_multiplier=1.0)

    feature_cols = [
        'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S'
    ]

    X_train = train_labeled[feature_cols]
    y_train = train_labeled['Macro_Label'] + 1 # Shift to 0, 1, 2

    X_exam = exam_labeled[feature_cols]
    y_exam_true = exam_labeled['Macro_Label'] + 1

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

    # 4. Predict Exam Day
    print("Running Inference on Exam Day...")
    y_pred = clf.predict(X_exam_scaled).flatten()

    # Shift back to -1, 0, 1 for visualization logic
    exam_labeled['Prediction'] = y_pred - 1

    # 5. Visualization (Plotly)
    print("Generating HTML Visualization...")
    fig = make_subplots(rows=1, cols=1, shared_xaxes=True, vertical_spacing=0.05)

    # Candlesticks
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
        mode='markers', marker=dict(symbol='triangle-up', color='lime', size=10),
        name='Predicted Uptrend'
    ), row=1, col=1)

    # Downtrends (Red Arrow)
    fig.add_trace(go.Scatter(
        x=downs['Time'], y=downs['High'] + 0.5,
        mode='markers', marker=dict(symbol='triangle-down', color='red', size=10),
        name='Predicted Downtrend'
    ), row=1, col=1)

    # Noise/Range (Gray X)
    fig.add_trace(go.Scatter(
        x=noise['Time'], y=noise['Open'],
        mode='markers', marker=dict(symbol='x', color='gray', size=6),
        name='Predicted Range/Noise'
    ), row=1, col=1)

    fig.update_layout(
        title=f"CatBoost Macro Regime (OOS Exam Day: {exam_day}) | Pure ZigZag Geometry",
        yaxis_title="Price",
        xaxis_rangeslider_visible=False,
        template="plotly_dark",
        height=800
    )

    html_path = "../data/catboost_exam_chart.html"
    fig.write_html(html_path)
    print(f"✅ Visualization saved to {html_path}")

if __name__ == "__main__":
    main()
