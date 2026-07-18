import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os

st.set_page_config(page_title="Merkava Prado Dollar Bars Inspector", layout="wide")

st.title("Merkava ML-Ops: Prado's Dollar Bars & Features")
st.markdown("Vizuális ellenőrzés a Dollar Clock mintavételezéshez és a hozzá tartozó Feature Engineeringhez.")

DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv"

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

    # Készítünk egy Plotly ábrát OHLCV gyertyákkal és OBI-val
    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.05,
                        subplot_titles=('Dollar Bars OHLC', 'Order Book Imbalance (Z-Score)', 'Tick Speed (Activity)'),
                        row_heights=[0.6, 0.2, 0.2])

    # 1. OHLC Gyertyák
    fig.add_trace(go.Candlestick(x=df['Start_Timestamp'],
                                 open=df['Open'],
                                 high=df['High'],
                                 low=df['Low'],
                                 close=df['Close'],
                                 name='OHLC'),
                  row=1, col=1)

    # Adjuk hozzá a Makro MTF Árakat az első grafikonhoz
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['15m_Close'], line=dict(color='orange', width=2), name='15m Close Macro'), row=1, col=1)
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['5m_Close'], line=dict(color='purple', width=1, dash='dot'), name='5m Close Macro'), row=1, col=1)

    # 2. OBI Z-Score
    # Ha zöld, vételi nyomás (Market Buy), ha piros, eladási nyomás (Market Sell)
    colors = ['green' if val >= 0 else 'red' for val in df['OBI_ZScore']]
    fig.add_trace(go.Bar(x=df['Start_Timestamp'], y=df['OBI_ZScore'], marker_color=colors, name='OBI Z-Score'),
                  row=2, col=1)

    # 3. Tick Speed
    fig.add_trace(go.Scatter(x=df['Start_Timestamp'], y=df['Tick_Speed'], fill='tozeroy', line=dict(color='cyan'), name='Tick Speed'),
                  row=3, col=1)

    fig.update_layout(height=900, title_text="Micro Gold (@GCE) Dollar Bars Analízis", xaxis_rangeslider_visible=False)
    st.plotly_chart(fig, use_container_width=True)

    st.markdown("### Adattábla")
    st.dataframe(df.tail(50))
else:
    st.warning(f"Kérlek generáld le a Dollar Barokat a `prado_dollar_bars.py` és a `dom_feature_engineer_mtf.py` futtatásával a VPS-en!")
