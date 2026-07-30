import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import plotly.graph_objects as go
from plotly.subplots import make_subplots

DATA_PATH = "data/exam_24h_volatile_3MTF_v3.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl" # A jól működő alapmodell (optuna architekturával)
OUTPUT_HTML = "data/regime_volatile_decision_chart_M5_RSI7.html"
LIMIT_BARS = 600

def main():
    print(f"Adatok betöltése: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True).head(LIMIT_BARS).copy()
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'], format='mixed', utc=True)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'P_Short', 'P_Noise', 'P_Long', 'Signal', 'OBI_Raw']
    features = [col for col in df.columns if col not in ignore_cols]
    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]
    X_test = df[['OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_5m', 'Dist_15m', 'Dist_30m', 'ATR_Proxy', 'Micro_RSI_14', 'Micro_MACD_Hist', 'Micro_BB_ZScore', 'Micro_ROC_5', 'Micro_MFI_5', 'M15_RSI_14', 'M15_MACD_Hist', 'M15_BB_ZScore', 'M15_ROC_5', 'M15_MFI_5', 'M30_RSI_14', 'M30_MACD_Hist', 'M30_BB_ZScore', 'M30_ROC_5', 'M30_MFI_5']]

    # 5 Perces (RSI 7) alapján a trend meghatározása
    df['Macro_Trend'] = 'Sideways'
    df.loc[df['M5_RSI_14'] > 55, 'Macro_Trend'] = 'Uptrend'
    df.loc[df['M5_RSI_14'] < 45, 'Macro_Trend'] = 'Downtrend'

    print(f"Modell betöltése: {MODEL_PATH}")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(X_test)
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(X_test)

    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # TISZTA, EMBERI, LOGIKUS KÜSZÖBÖK BEÉGETÉSE (Nem használjuk a túltanult Optunát)
    # Uptrend: Könnyű Long (0.35), Nehéz Short (0.50)
    # Downtrend: Könnyű Short (0.35), Nehéz Long (0.50)
    # Sideways: Kiegyensúlyozott (0.40 mindkettőnek)
    df['Thr_Long'] = np.where(df['Macro_Trend'] == 'Uptrend', 0.35,
                     np.where(df['Macro_Trend'] == 'Downtrend', 0.50, 0.40))

    df['Thr_Short'] = np.where(df['Macro_Trend'] == 'Uptrend', 0.50,
                      np.where(df['Macro_Trend'] == 'Downtrend', 0.35, 0.40))

    df['Max_Noise'] = 0.35 # Fix ésszerű zajlimit

    preds = np.ones(len(df))

    # VISSZATETTÜK A VAKU ARGMAX SZABÁLYT IS (P_Long > P_Short) a biztonság és egyszerűség kedvéért!
    long_cond = (df['P_Long'] > df['Thr_Long']) & (df['P_Long'] > df['P_Short']) & (df['P_Noise'] < df['Max_Noise'])
    short_cond = (df['P_Short'] > df['Thr_Short']) & (df['P_Short'] > df['P_Long']) & (df['P_Noise'] < df['Max_Noise'])

    preds[long_cond] = 2
    preds[short_cond] = 0
    df['Signal'] = preds

    print("Plotly chart generálása...")
    fig = make_subplots(
        rows=3, cols=1, shared_xaxes=True,
        row_heights=[0.5, 0.3, 0.2], vertical_spacing=0.03,
        subplot_titles=("Price & M5_RSI_14 Regime Signals (Simplified)", "Model Probabilities & Fixed Dynamic Thresholds", "Macro Trend (M5_RSI_14)")
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

    fig.add_trace(go.Scatter(x=long_signals['Start_Timestamp'], y=long_signals['Low'] - 0.5, mode='markers', marker=dict(symbol='triangle-up', color='lime', size=10), name='ML Long'), row=1, col=1)
    fig.add_trace(go.Scatter(x=short_signals['Start_Timestamp'], y=short_signals['High'] + 0.5, mode='markers', marker=dict(symbol='triangle-down', color='magenta', size=10), name='ML Short'), row=1, col=1)

    # 2. Probabilities with Dynamic Steps
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['Thr_Long'], mode='lines', line=dict(color='lime', width=2, dash='dot', shape='hv'), name='Thr Long (Dynamic)'), row=2, col=1)

    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Short'], mode='lines', line=dict(color='magenta', width=1.5), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['Thr_Short'], mode='lines', line=dict(color='magenta', width=2, dash='dot', shape='hv'), name='Thr Short (Dynamic)'), row=2, col=1)

    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['P_Noise'], mode='lines', line=dict(color='gray', width=1), name='P(Noise)'), row=2, col=1)

    # 3. Trend Indicator (M5_RSI_14)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['M5_RSI_14'], mode='lines', line=dict(color='cyan', width=2), name='M5_RSI_14'), row=3, col=1)
    fig.add_hline(y=55, line_dash="dash", line_color="lime", row=3, col=1)
    fig.add_hline(y=45, line_dash="dash", line_color="magenta", row=3, col=1)

    fig.update_layout(
        title="Simplified M5_RSI_14 Regime Evaluation (Argmax Active)",
        xaxis_rangeslider_visible=False, template='plotly_dark', height=1000, showlegend=True
    )
    fig.write_html(OUTPUT_HTML)
    print(f"Chart elmentve: {OUTPUT_HTML}")

if __name__ == "__main__":
    main()
