import streamlit as st
import plotly.graph_objects as go
import pandas as pd
import time
from data_pipeline import load_and_resample
from market_simulator import MarketSimulator
from core_engine import HMMCoreEngine

# Oldal konfiguráció
st.set_page_config(page_title='HMM Hybrid Scalping HUD', layout='wide')

st.title('HMM Hibrid Skalpoló Elemző (S5 / M1 / M5)')

# Placeholderek a dinamikus frissítéshez
metrics_container = st.empty()
chart_container = st.empty()

@st.cache_resource
def get_engine_and_simulator():
    csv_file = '/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_v1.10_20260408_025931.csv'
    s5_df, m1_df, m5_df = load_and_resample(csv_file)
    sim = MarketSimulator(s5_df, m1_df, m5_df)
    engine = HMMCoreEngine()

    # Pre-warm (gyorsított inicializálás)
    m1_list = m1_df.head(100).to_dict('records')
    m5_list = m5_df.head(35).to_dict('records')
    s5_list = s5_df.head(60).to_dict('records')

    for row in m5_list: engine.process_tick(None, None, None, 'dummy', row)
    for row in m1_list: engine.process_tick(None, 'dummy', row, None, None)
    for row in s5_list: engine.process_tick(row, None, None, None, None)

    # Keresünk egy biztos pontot
    for _ in range(500): sim.fetch_next_tick()

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

    s5_data = tick['s5_data']
    advice = engine.process_tick(s5_data, tick['m1_time'], tick['m1_data'], tick['m5_time'], tick['m5_data'])

    # Adatok gyűjtése a chart-hoz
    current_state = 0
    if 'LONG' in advice: current_state = 1
    elif 'SHORT' in advice or 'TILTVA' in advice: current_state = -1

    history_data.append({
        'time': tick['s5_time'],
        'open': s5_data['open'],
        'high': s5_data['high'],
        'low': s5_data['low'],
        'close': s5_data['close'],
        'advice': advice,
        'state': current_state
    })

    if len(history_data) > visible_window:
        history_data.pop(0)

    df_plot = pd.DataFrame(history_data)

    with metrics_container.container():
        cols = st.columns(2)
        cols[0].metric("Jelenlegi Ár (XAUUSD)", f"{s5_data['close']:.2f}")

        # Színkódolt javaslat
        if 'ERŐS LONG' in advice:
            st.markdown(f"<div style='background-color:#d4edda;padding:20px;border-radius:10px'><h3 style='color:green'>🟢 {advice}</h3></div>", unsafe_allow_html=True)
        elif 'ERŐS SHORT' in advice or 'TILTVA' in advice:
            st.markdown(f"<div style='background-color:#f8d7da;padding:20px;border-radius:10px'><h3 style='color:red'>🔴 {advice}</h3></div>", unsafe_allow_html=True)
        elif 'GYENGÜL' in advice:
            st.markdown(f"<div style='background-color:#fff3cd;padding:20px;border-radius:10px'><h3 style='color:orange'>🟡 {advice}</h3></div>", unsafe_allow_html=True)
        else:
            st.markdown(f"<div style='background-color:#e2e3e5;padding:20px;border-radius:10px'><h3>⚪ {advice}</h3></div>", unsafe_allow_html=True)

    fig = go.Figure(data=[go.Candlestick(
        x=df_plot['time'],
        open=df_plot['open'],
        high=df_plot['high'],
        low=df_plot['low'],
        close=df_plot['close'],
        name="XAUUSD S5"
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

    chart_container.plotly_chart(fig, use_container_width=True, key=f"chart_{tick['s5_time']}")

    time.sleep(0.1) # Szimulációs sebesség
