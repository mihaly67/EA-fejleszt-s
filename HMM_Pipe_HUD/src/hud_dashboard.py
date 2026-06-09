import streamlit as st
import plotly.graph_objects as go
import pandas as pd
import time
import os
from data_pipeline import load_and_resample
from market_simulator import MarketSimulator
from core_engine import HMMCoreEngine

# Oldal konfiguráció
st.set_page_config(page_title='HMM TrendFollow HUD', layout='wide')

st.title('HMM TrendKövető Műszerfal (M1 / M5 / M15)')

# Placeholderek a dinamikus frissítéshez
metrics_container = st.empty()
chart_container = st.empty()

@st.cache_resource
def get_engine_and_simulator():
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'
    if not os.path.exists(csv_file):
        csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'

    m1_df, m5_df, m15_df = load_and_resample(csv_file)
    sim = MarketSimulator(m1_df, m5_df, m15_df)
    engine = HMMCoreEngine()

    # Pre-warm (gyorsított inicializálás)
    m15_list = m15_df.head(35).to_dict('records')
    m5_list = m5_df.head(100).to_dict('records')
    m1_list = m1_df.head(60).to_dict('records')

    for row in m15_list: engine.process_tick(None, None, None, 'dummy', row)
    for row in m5_list: engine.process_tick(None, 'dummy', row, None, None)
    for row in m1_list: engine.process_tick(row, None, None, None, None)

    # Keresünk egy biztos pontot
    for _ in range(300): sim.fetch_next_tick()

    return sim, engine

sim, engine = get_engine_and_simulator()

# Megjelenítendő adatablak
visible_window = 100
history_data = []

# Végtelen ciklus a Streamlitben (Offline Stream)
for _ in range(1000):
    tick = sim.fetch_next_tick()
    if not tick:
        break

    m1_data = tick['m1_data']
    advice = engine.process_tick(m1_data, tick['m5_time'], tick['m5_data'], tick['m15_time'], tick['m15_data'])

    # Adatok gyűjtése a chart-hoz
    current_state = 0
    if 'LONG' in advice or 'VÉTEL' in advice: current_state = 1
    elif 'SHORT' in advice or 'ELADÁS' in advice: current_state = -1

    history_data.append({
        'time': tick['m1_time'],
        'open': m1_data['open'],
        'high': m1_data['high'],
        'low': m1_data['low'],
        'close': m1_data['close'],
        'advice': advice,
        'state': current_state
    })

    if len(history_data) > visible_window:
        history_data.pop(0)

    df_plot = pd.DataFrame(history_data)

    with metrics_container.container():
        cols = st.columns(2)
        cols[0].metric("Jelenlegi Ár (XAUUSD M1)", f"{m1_data['close']:.2f}")

        # Színkódolt javaslat
        if 'VÉTEL' in advice or 'LONG' in advice:
            st.markdown(f"<div style='background-color:#d4edda;padding:20px;border-radius:10px'><h3 style='color:green'>🟢 {advice}</h3></div>", unsafe_allow_html=True)
        elif 'ELADÁS' in advice or 'SHORT' in advice or 'TILTVA' in advice:
            st.markdown(f"<div style='background-color:#f8d7da;padding:20px;border-radius:10px'><h3 style='color:red'>🔴 {advice}</h3></div>", unsafe_allow_html=True)
        elif 'GYENGÜL' in advice or 'PULLBACK' in advice:
            st.markdown(f"<div style='background-color:#fff3cd;padding:20px;border-radius:10px'><h3 style='color:orange'>🟡 {advice}</h3></div>", unsafe_allow_html=True)
        else:
            st.markdown(f"<div style='background-color:#e2e3e5;padding:20px;border-radius:10px'><h3>⚪ {advice}</h3></div>", unsafe_allow_html=True)

    fig = go.Figure(data=[go.Candlestick(
        x=df_plot['time'],
        open=df_plot['open'],
        high=df_plot['high'],
        low=df_plot['low'],
        close=df_plot['close'],
        name="XAUUSD M1"
    )])

    # Háttérszínezés a HMM állapot alapján Plotly VRECT-el
    for i in range(len(df_plot)-1):
        state = df_plot['state'].iloc[i]
        if state == 1: color = "rgba(0, 255, 0, 0.1)"
        elif state == -1: color = "rgba(255, 0, 0, 0.1)"
        else: color = "rgba(128, 128, 128, 0.05)"

        fig.add_vrect(
            x0=df_plot['time'].iloc[i],
            x1=df_plot['time'].iloc[i+1],
            fillcolor=color,
            layer="below",
            line_width=0
        )

    fig.update_layout(height=600, margin=dict(l=10, r=10, t=10, b=10), template='plotly_dark')

    chart_container.plotly_chart(fig, use_container_width=True, key=f"chart_{tick['m1_time']}")

    time.sleep(0.1) # Szimulációs sebesség
