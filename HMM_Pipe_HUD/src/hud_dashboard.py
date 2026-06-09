import streamlit as st
import plotly.graph_objects as go
import pandas as pd
import json
import os
from streamlit_autorefresh import st_autorefresh

# Oldal konfiguráció
st.set_page_config(page_title='HMM TrendFollow HUD', layout='wide')

st.title('HMM TrendKövető Műszerfal (Backend + UI szétválasztva)')
st.write("A motor a háttérben fut, így a CPU-terhelés ~10% alatt marad.")

# Autorefresh (1 mp = 1000 ms)
count = st_autorefresh(interval=1000, limit=None, key="framerater")

latest_file = '/tmp/hmm_latest_tick.json'
history_file = '/tmp/hmm_history.json'

if not os.path.exists(latest_file) or not os.path.exists(history_file):
    st.warning("A háttérfolyamat (run_backend.py) még nem indult el, vagy még nem generált adatot.")
    st.stop()

with open(latest_file, 'r') as f:
    latest_tick = json.load(f)

with open(history_file, 'r') as f:
    history_data = json.load(f)

df_plot = pd.DataFrame(history_data)

advice = latest_tick['advice']

cols = st.columns(2)
cols[0].metric("Jelenlegi Ár (XAUUSD M1)", f"{latest_tick['close']:.2f}")

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

# Háttérszínezés a HMM állapot alapján
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

st.plotly_chart(fig, use_container_width=True)
