import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import json
import plotly.graph_objects as go
from plotly.subplots import make_subplots

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"
PARAMS_PATH = "models/optuna_asymmetric_params_3MTF_v2.json"
OUTPUT_HTML = "data/asymmetric_volatile_decision_chart.html"
LIMIT_BARS = 600 # Csak az első 600 bart jelenítjük meg a chart átláthatósága érdekében

def main():
    print(f"Adatok betöltése: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
    df = df.head(LIMIT_BARS).copy()

    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'], format='mixed', utc=True)

    ignore_cols = [
        'Start_Timestamp', 'End_Timestamp', 'Target_Label',
        'Open', 'High', 'Low', 'Close',
        'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value',
        '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close',
        'Bar_Time_Seconds', 'OBI_Raw',
        'P_Short', 'P_Noise', 'P_Long', 'Signal'
    ]
    features = [col for col in df.columns if col not in ignore_cols]

    X_test = df[features]

    print(f"Modell betöltése: {MODEL_PATH}")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    p_short = probs[:, 0]
    p_noise = probs[:, 1]
    p_long = probs[:, 2]

    with open(PARAMS_PATH, 'r') as f:
        best_params = json.load(f)

    threshold_short = best_params['threshold_short']
    threshold_long = best_params['threshold_long']
    max_noise = best_params['max_noise']

    print(f"Kalkuláció aszimmetrikus küszöbökkel: Short: {threshold_short:.4f}, Long: {threshold_long:.4f}, Max Noise: {max_noise:.4f}")

    preds = np.ones(len(df))
    long_cond = (p_long > threshold_long) & (p_long > p_short) & (p_noise < max_noise)
    short_cond = (p_short > threshold_short) & (p_short > p_long) & (p_noise < max_noise)

    preds[long_cond] = 2
    preds[short_cond] = 0

    df['P_Short'] = p_short
    df['P_Noise'] = p_noise
    df['P_Long'] = p_long
    df['Signal'] = preds

    print("Plotly chart generálása...")
    fig = make_subplots(
        rows=2, cols=1, shared_xaxes=True,
        row_heights=[0.7, 0.3], vertical_spacing=0.03,
        subplot_titles=("Price & Asymmetric ML Signals", "Model Probabilities")
    )

    colors = np.where(df['Close'] >= df['Open'], '#228B22', '#B22222')

    # 1. Price Chart (Vonalak)
    for i in range(len(df)):
        fig.add_trace(go.Scatter(
            x=[df['Start_Timestamp'].iloc[i], df['Start_Timestamp'].iloc[i]],
            y=[df['Low'].iloc[i], df['High'].iloc[i]],
            mode='lines',
            line=dict(color=colors[i], width=2),
            showlegend=False
        ), row=1, col=1)

    # 2. ML Signals Overlay
    long_signals = df[df['Signal'] == 2]
    short_signals = df[df['Signal'] == 0]
    noise_signals = df[df['Signal'] == 1]

    fig.add_trace(go.Scatter(
        x=long_signals['Start_Timestamp'], y=long_signals['Low'] - 0.5,
        mode='markers', marker=dict(symbol='triangle-up', color='lime', size=10),
        name='ML Long Signal'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=short_signals['Start_Timestamp'], y=short_signals['High'] + 0.5,
        mode='markers', marker=dict(symbol='triangle-down', color='magenta', size=10),
        name='ML Short Signal'
    ), row=1, col=1)

    fig.add_trace(go.Scatter(
        x=noise_signals['Start_Timestamp'], y=noise_signals['Open'],
        mode='markers', marker=dict(symbol='x', color='gray', size=6),
        name='ML Hold/Noise'
    ), row=1, col=1)

    # 3. Probabilities (Subplot)
    fig.add_trace(go.Scatter(
        x=df['Start_Timestamp'], y=df['P_Long'],
        mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'
    ), row=2, col=1)

    fig.add_trace(go.Scatter(
        x=df['Start_Timestamp'], y=df['P_Short'],
        mode='lines', line=dict(color='magenta', width=1.5), name='P(Short)'
    ), row=2, col=1)

    fig.add_trace(go.Scatter(
        x=df['Start_Timestamp'], y=df['P_Noise'],
        mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'
    ), row=2, col=1)

    # Thresholds
    fig.add_hline(y=threshold_long, line_dash="dash", line_color="lime", row=2, col=1, annotation_text=f"Long Thr: {threshold_long:.2f}")
    fig.add_hline(y=threshold_short, line_dash="dash", line_color="magenta", row=2, col=1, annotation_text=f"Short Thr: {threshold_short:.2f}")
    fig.add_hline(y=max_noise, line_dash="solid", line_color="gray", row=2, col=1, annotation_text=f"Max Noise: {max_noise:.2f}")

    fig.update_layout(
        title=f"Asymmetric Threshold Model Evaluation (Short: {threshold_short:.2f}, Long: {threshold_long:.2f})",
        xaxis_rangeslider_visible=False,
        template='plotly_dark',
        height=900,
        showlegend=True
    )

    fig.write_html(OUTPUT_HTML)
    print(f"Chart elmentve: {OUTPUT_HTML}")

if __name__ == "__main__":
    main()
