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


import altair as alt

chart_data = df_plot[['time', 'close']].copy()
chart_data['time'] = pd.to_datetime(chart_data['time'])

# Y tengely dinamikus skálázása Altair segítségével (könnyű HTML)
min_price = chart_data['close'].min() - 2.0
max_price = chart_data['close'].max() + 2.0

c = alt.Chart(chart_data).mark_line(color='#1f77b4', strokeWidth=3).encode(
    x=alt.X('time:T', title='Idő'),
    y=alt.Y('close:Q', scale=alt.Scale(domain=[min_price, max_price]), title='Ár (XAUUSD)')
).properties(height=400)

st.altair_chart(c, use_container_width=True)

st.subheader("Utolsó 5 Tick Története")
display_df = df_plot.tail(5)[['time', 'close', 'advice', 'state']].copy()
st.table(display_df)
