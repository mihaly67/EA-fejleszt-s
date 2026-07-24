import pandas as pd
import numpy as np
import lightgbm as lgb
import os
import sys
import plotly.graph_objects as go
from plotly.subplots import make_subplots

def visualize_decisions(data_path, model_path, output_dir):
    print(f"🔄 Betöltés: {data_path}")
    df = pd.read_csv(data_path).dropna()
    df['End_Timestamp'] = pd.to_datetime(df['End_Timestamp'])

    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)

    X = df[features].values

    print(f"🧠 Modell betöltése és predikció: {model_path}")
    bst = lgb.Booster(model_file=model_path)
    probs = bst.predict(X)

    # Valószínűségek kinyerése
    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # Szignál generálás
    preds = np.argmax(probs, axis=1) - 1 # -1: Short, 0: Zaj, 1: Long
    df['Signal'] = preds

    # Hozzuk létre a Plotly Subplot ábrát
    print("📈 Interaktív HTML generálása (Plotly)...")
    fig = make_subplots(
        rows=4, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.05,
        row_heights=[0.5, 0.15, 0.15, 0.2],
        subplot_titles=("Gyertyák és Címkék", "LightGBM Valószínűségek", "M15 Makro Oszcillátorok", "Mikro Oszcillátorok")
    )

    # 1. Sor: OHLC Gyertyák és Szignálok
    fig.add_trace(go.Candlestick(
        x=df['End_Timestamp'],
        open=df['Open'], high=df['High'],
        low=df['Low'], close=df['Close'],
        name='Árfolyam'
    ), row=1, col=1)

    # Szignálok jelzése a charton
    long_signals = df[df['Signal'] == 1]
    short_signals = df[df['Signal'] == -1]

    if not long_signals.empty:
        fig.add_trace(go.Scatter(
            x=long_signals['End_Timestamp'],
            y=long_signals['Low'] - (df['ATR_Proxy'].mean() * 0.5), # Kicsit a gyertya alá
            mode='markers',
            marker=dict(symbol='triangle-up', size=10, color='green'),
            name='Long Jel (Gép)'
        ), row=1, col=1)

    if not short_signals.empty:
        fig.add_trace(go.Scatter(
            x=short_signals['End_Timestamp'],
            y=short_signals['High'] + (df['ATR_Proxy'].mean() * 0.5), # Kicsit a gyertya fölé
            mode='markers',
            marker=dict(symbol='triangle-down', size=10, color='red'),
            name='Short Jel (Gép)'
        ), row=1, col=1)

    # 2. Sor: Valószínűségek (P_Long, P_Short, P_Noise)
    fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['P_Long'], mode='lines', line=dict(color='green'), name='P_Long'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['P_Short'], mode='lines', line=dict(color='red'), name='P_Short'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['P_Noise'], mode='lines', line=dict(color='gray', dash='dot'), name='P_Noise'), row=2, col=1)

    # 3. Sor: Makro Indikátorok (Pl. M15 BB Z-Score és M15 RSI)
    fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['M15_RSI_14'], mode='lines', line=dict(color='purple'), name='M15_RSI'), row=3, col=1)
    # Húzzunk 30-as és 70-es vonalat
    fig.add_hline(y=70, line_dash="dash", line_color="red", row=3, col=1)
    fig.add_hline(y=30, line_dash="dash", line_color="green", row=3, col=1)

    # 4. Sor: Mikro Indikátorok (Pl. ROC és OBI_ZScore)
    fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['OBI_ZScore'], mode='lines', line=dict(color='blue'), name='OBI Z-Score'), row=4, col=1)
    if 'Micro_ROC_5' in df.columns:
        fig.add_trace(go.Scatter(x=df['End_Timestamp'], y=df['Micro_ROC_5'], mode='lines', line=dict(color='orange'), name='Micro ROC (5)'), row=4, col=1)

    fig.update_layout(
        title='LightGBM Döntési Mechanizmus Vizualizáció (08:00 - 24:00)',
        height=1200,
        xaxis_rangeslider_visible=False,
        template='plotly_dark'
    )

    html_path = os.path.join(output_dir, 'decision_visualization.html')
    fig.write_html(html_path)
    print(f"✅ Vizualizáció elmentve: {html_path}")

if __name__ == '__main__':
    # Alapértelmezésben a legutóbbi vizsga (éles) adatot vizualizáljuk
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/exam_0720_23/exam_features.csv'
    model_path = '/home/misi/Merkava_ML_Ops/models/lgbm_copilot_model.txt'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]
    if len(sys.argv) > 2:
        model_path = sys.argv[2]

    output_dir = os.path.dirname(data_path)
    visualize_decisions(data_path, model_path, output_dir)
