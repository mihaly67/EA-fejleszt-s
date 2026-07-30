import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import plotly.graph_objects as go
from plotly.subplots import make_subplots

DATA_PATH = "data/exam_24h_volatile_3MTF_v3.csv"
MODEL_PATH = "models/lgbm_model_default.pkl" # A tiszta gyári modell!
OUTPUT_HTML = "data/volatile_RAW_decision_chart.html" # A kért pontos fájlnév
# KIVETTEM A LIMIT_BARS VÁLTOZÓT: a teljes fájlt dolgozzuk fel!

def main():
    print(f"Adatok betöltése (TELJES 24 ÓRA): {DATA_PATH}")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'], format='mixed', utc=True)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]
    X_test = df[features]

    print(f"Szűz modell betöltése: {MODEL_PATH}")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # VEGYTISZTA ARGMAX - Nincs Optuna, nincs dinamikus küszöb!
    df['Signal'] = np.argmax(probs, axis=1)

    print(f"Plotly chart generálása {len(df)} bárral...")
    fig = make_subplots(
        rows=2, cols=1, shared_xaxes=True,
        row_heights=[0.7, 0.3], vertical_spacing=0.03,
        subplot_titles=("Price & PURE Argmax ML Signals (Full Day)", "Model Probabilities (Default LGBM)")
    )

    colors = np.where(df['Close'] >= df['Open'], '#228B22', '#B22222')

    # 1. Price Chart
    for i in range(len(df)):
        fig.add_trace(go.Scatter(
            x=[df['Start_Timestamp'].iloc[i], df['Start_Timestamp'].iloc[i]],
            y=[df['Low'].iloc[i], df['High'].iloc[i]],
            mode='lines', line=dict(color=colors[i], width=2), showlegend=False
        ), row=1, col=1)

    long_signals = df[df['Signal'] == 2]
    short_signals = df[df['Signal'] == 0]
    noise_signals = df[df['Signal'] == 1]

    fig.add_trace(go.Scatter(x=long_signals['Start_Timestamp'], y=long_signals['Low'] - 0.5, mode='markers', marker=dict(symbol='triangle-up', color='lime', size=10), name='ML Long'), row=1, col=1)
    fig.add_trace(go.Scatter(x=short_signals['Start_Timestamp'], y=short_signals['High'] + 0.5, mode='markers', marker=dict(symbol='triangle-down', color='magenta', size=10), name='ML Short'), row=1, col=1)
    fig.add_trace(go.Scatter(x=noise_signals['Start_Timestamp'], y=noise_signals['Open'], mode='markers', marker=dict(symbol='x', color='gray', size=6), name='ML Hold/Noise'), row=1, col=1)

    # 2. Probabilities
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Short'], mode='lines', line=dict(color='magenta', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P(Noise)'), row=2, col=1)

    fig.update_layout(
        title="Full Day Pure Raw Argmax Evaluation (Default Model, No Optuna)",
        xaxis_rangeslider_visible=False, template='plotly_dark', height=900, showlegend=True
    )
    fig.write_html(OUTPUT_HTML)
    print(f"Chart elmentve: {OUTPUT_HTML}")

if __name__ == "__main__":
    main()
