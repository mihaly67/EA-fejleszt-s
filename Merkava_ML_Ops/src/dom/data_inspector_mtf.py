import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os

st.set_page_config(page_title="Merkava Prado Dollar Bars & Labels Inspector", layout="wide")

st.title("Merkava ML-Ops: Copilot Triple-Barrier & Dollar Bars")
st.markdown("Vizuális ellenőrzés a Dollar Clock mintavételezéshez, a Feature-ökhöz, és az egyedi (Aszimmetrikus 1.5:1.0 P/L) Triple Barrier címkézéshez.")

DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv"

@st.cache_data
def load_data():
    try:
        df = pd.read_csv(DATA_PATH)
        df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
        return df
    except Exception as e:
        st.error(f"Hiba az adatok beolvasásakor: {e}")
        return None

df = load_data()

if df is not None and not df.empty:
    st.write(f"📊 Betöltött adatok: {len(df)} Dollar Bar")

    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.05,
                        subplot_titles=('Dollar Bars OHLC & Asymmetric Triple-Barrier Labels', 'Order Book Imbalance (Z-Score)', 'Tick Speed (Activity)'),
                        row_heights=[0.6, 0.2, 0.2])

    fig.add_trace(go.Candlestick(x=df['Start_Timestamp'],
                                 open=df['Open'],
                                 high=df['High'],
                                 low=df['Low'],
                                 close=df['Close'],
                                 name='OHLC'),
                  row=1, col=1)

    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['15m_Close'], line=dict(color='orange', width=2), name='15m Close Macro'), row=1, col=1)

    # 🌟 CÍMKÉZÉS VIZUALIZÁCIÓJA
    # Záróárhoz (Close) illesztjük a jeleket, hogy pontosan lássuk, honnan indult a mérés
    long_points = df[df['Target_Label'] == 1]
    short_points = df[df['Target_Label'] == -1]
    noise_points = df[df['Target_Label'] == 0]

    fig.add_trace(go.Scatter(x=long_points['Start_Timestamp'], y=long_points['Close'],
                             mode='markers', marker=dict(symbol='triangle-up', color='lime', size=14, line=dict(color='darkgreen', width=1)),
                             name='Long (+1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=short_points['Start_Timestamp'], y=short_points['Close'],
                             mode='markers', marker=dict(symbol='triangle-down', color='red', size=14, line=dict(color='darkred', width=1)),
                             name='Short (-1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=noise_points['Start_Timestamp'], y=noise_points['Close'],
                             mode='markers', marker=dict(symbol='x', color='yellow', size=8, opacity=0.7),
                             name='Noise (0)'), row=1, col=1)

    # 2. OBI Z-Score VASTAGÍTOTT vonalakkal
    colors = ['green' if val >= 0 else 'red' for val in df['OBI_ZScore']]
    fig.add_trace(go.Bar(x=df['Start_Timestamp'], y=df['OBI_ZScore'], marker_color=colors, name='OBI Z-Score',
                         marker_line_width=1, opacity=0.9), row=2, col=1)

    # 3. Tick Speed
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['Tick_Speed'], fill='tozeroy', line=dict(color='cyan', width=2), name='Tick Speed'),
                  row=3, col=1)

    fig.update_layout(height=900, title_text="Micro Gold (@GCE) Dollar Bars & Copilot Labels (P/L 1.5:1.0)", xaxis_rangeslider_visible=False)

    # Hogy a vastagság érvényesüljön a bar charton, kikapcsoljuk az automatikus szóközöket a barlok között
    fig.update_layout(barmode='group', bargap=0.1)

    st.plotly_chart(fig, use_container_width=True)
else:
    st.warning(f"Kérlek generáld le az adatokat a `dom_labeler_mtf.py` futtatásával a VPS-en!")
