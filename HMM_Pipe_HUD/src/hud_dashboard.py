import streamlit as st
import pandas as pd
import json
import os
from streamlit_autorefresh import st_autorefresh

st.set_page_config(page_title='HMM TrendFollow HUD', layout='wide')
st.title('HMM TrendKövető Műszerfal (O(1) Engine + Native Chart)')

# Auto refresh to poll JSON
st_autorefresh(interval=1000, limit=None, key="framerater")

latest_file = '/tmp/hmm_latest_tick.json'
history_file = '/tmp/hmm_history.json'

if not os.path.exists(latest_file) or not os.path.exists(history_file):
    st.warning("Adatok szinkronizálása a backendből... Kérlek várj.")
    st.stop()

try:
    with open(latest_file, 'r') as f:
        latest_tick = json.load(f)
    with open(history_file, 'r') as f:
        history_data = json.load(f)
except json.JSONDecodeError:
    st.warning("Adatok olvasása folyamatban...")
    st.stop()

df_plot = pd.DataFrame(history_data)
advice = latest_tick['advice']

cols = st.columns(2)
cols[0].metric("Jelenlegi Ár (XAUUSD M1)", f"{latest_tick['close']:.2f}")

if 'VÉTEL' in advice or 'LONG' in advice:
    st.markdown(f"<div style='background-color:#d4edda;padding:20px;border-radius:10px'><h3 style='color:green'>🟢 {advice}</h3></div>", unsafe_allow_html=True)
elif 'ELADÁS' in advice or 'SHORT' in advice or 'TILTVA' in advice:
    st.markdown(f"<div style='background-color:#f8d7da;padding:20px;border-radius:10px'><h3 style='color:red'>🔴 {advice}</h3></div>", unsafe_allow_html=True)
elif 'GYENGÜL' in advice or 'PULLBACK' in advice:
    st.markdown(f"<div style='background-color:#fff3cd;padding:20px;border-radius:10px'><h3 style='color:orange'>🟡 {advice}</h3></div>", unsafe_allow_html=True)
else:
    st.markdown(f"<div style='background-color:#e2e3e5;padding:20px;border-radius:10px'><h3>⚪ {advice}</h3></div>", unsafe_allow_html=True)

# Native fast rendering line chart instead of heavy Plotly
chart_data = df_plot[['time', 'close']].set_index('time')
st.line_chart(chart_data, height=400)

st.subheader("Utolsó 5 Tick Története")
st.dataframe(df_plot.tail(5)[['time', 'close', 'advice']].set_index('time'))
