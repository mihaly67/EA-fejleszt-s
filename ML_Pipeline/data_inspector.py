import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import streamlit as st
import matplotlib.pyplot as plt
import seaborn as sns

st.set_page_config(layout='wide', page_title='Merkava ML Data Inspector')
st.title('🔍 Merkava ML Data Inspector (Triple Barrier)')

@st.cache_data
def load_data():
    # Load processed parquet file
    data_path = '../data/processed/scalp_features.parquet'
    try:
        df = pd.read_parquet(data_path)
        return df
    except Exception as e:
        st.error(f'Hiba az adat betöltésekor: {e}')
        return None

df = load_data()

if df is not None:
    st.sidebar.header('Beállítások')
    num_candles = st.sidebar.slider('Megjelenített gyertyák száma (Chart)', 100, 1000, 300)
    start_idx = st.sidebar.slider('Kezdőpont eltolása', 0, len(df)-num_candles, 0)

    st.header('1. Triple Barrier Címkék Vizuális Ellenőrzése')

    # Slice data for chart
    df_slice = df.iloc[start_idx:start_idx+num_candles].copy()

    fig = go.Figure()

    # 1. Candlestick
    fig.add_trace(go.Candlestick(
        x=df_slice.index,
        open=df_slice['open'],
        high=df_slice['high'],
        low=df_slice['low'],
        close=df_slice['close'],
        name='Árfolyam'
    ))

    # 2. Add Buy signals (Triple Barrier hit TP first)
    buys = df_slice[df_slice['target'] == 1]
    if len(buys) > 0:
        fig.add_trace(go.Scatter(
            x=buys.index, y=buys['low'] - (buys['atr'] if 'atr' in buys else 1),
            mode='markers',
            marker=dict(symbol='triangle-up', size=12, color='lime'),
            name='Buy (TP Hit)'
        ))

    # 3. Add Sell signals (Triple Barrier hit SL first)
    sells = df_slice[df_slice['target'] == -1]
    if len(sells) > 0:
        fig.add_trace(go.Scatter(
            x=sells.index, y=sells['high'] + (sells['atr'] if 'atr' in sells else 1),
            mode='markers',
            marker=dict(symbol='triangle-down', size=12, color='red'),
            name='Sell (SL Hit)'
        ))

    fig.update_layout(height=600, template='plotly_dark', title='OHLC Gyertyák & Célpontok')
    st.plotly_chart(fig, use_container_width=True)


    st.header('2. Feature Korrelációs Mátrix (Adatszivárgás Keresése)')
    st.write('Ha két feature korrelációja > 0.95 (vagy < -0.95), akkor feleslegesen duplikálják az információt, érdemes az egyiket kidobni.')

    # Select only numeric features (exclude targets and useless ones)
    drop_cols = ['target', 'TickMSC', 'Ping_MS', 'MimicMode', 'Verdict', 'ActionDetails', 'LastEvent', 'LotDir']
    feature_cols = [c for c in df.columns if c not in drop_cols and df[c].dtype in [np.float64, np.float32, np.int64, np.int32]]

    # Compute correlation (using a sample for speed)
    df_sample = df[feature_cols].sample(min(10000, len(df)))
    corr = df_sample.corr()

    # Create mask for upper triangle
    mask = np.triu(np.ones_like(corr, dtype=bool))

    fig_corr, ax_corr = plt.subplots(figsize=(20, 16))
    sns.heatmap(corr, mask=mask, cmap='coolwarm', vmin=-1, vmax=1, center=0,
                square=True, linewidths=.5, cbar_kws={'shrink': .5}, ax=ax_corr)
    st.pyplot(fig_corr)

    # Find highly correlated pairs
    st.subheader('Túl magas korrelációjú párok (>0.90)')
    corr_unstacked = corr.unstack()
    high_corr = corr_unstacked[abs(corr_unstacked) > 0.90].sort_values(ascending=False)
    high_corr = high_corr[high_corr < 1.0].drop_duplicates()

    if len(high_corr) > 0:
        st.dataframe(high_corr.reset_index().rename(columns={'level_0': 'Feature 1', 'level_1': 'Feature 2', 0: 'Korreláció'}))
    else:
        st.success('Nincsenek veszélyesen korreláló feature-ök!')

    # Clean up matplotlib figure
    plt.clf()
    plt.close()
