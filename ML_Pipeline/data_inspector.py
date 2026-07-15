import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px

st.set_page_config(page_title="Merkava XGBoost Data Inspector", layout="wide")

st.title("Merkava ML-Ops: Triple Barrier Címkék & Korreláció (Új Szimmetrikus Logika)")
st.markdown("Ellenőrizd az M1 XAUUSD gyertyadiagramot a javított Triple Barrier szignálokkal.")

DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/scalp_features.parquet"
RAW_CSV_PATH = "/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_MINER_M1_SCRIPT_v1.04_20260618_022831.csv"

@st.cache_data
def load_data():
    try:
        # Load processed features (with target)
        df = pd.read_parquet(DATA_PATH)

        # Load raw data for OHLC
        raw_df = pd.read_csv(RAW_CSV_PATH)
        df = df.reset_index(drop=True)

        if len(raw_df) == len(df):
            plot_df = raw_df.copy()
            plot_df['target'] = df['target'].values
            plot_df.rename(columns={'Time': 'time', 'Bar_Open': 'Open', 'Bar_High': 'High', 'Bar_Low': 'Low', 'Bar_Close': 'Close'}, inplace=True)

            plot_df['TR'] = np.maximum((plot_df['High'] - plot_df['Low']),
                           np.maximum(abs(plot_df['High'] - plot_df['Close'].shift(1)),
                                      abs(plot_df['Low'] - plot_df['Close'].shift(1))))
            plot_df['ATR_14'] = plot_df['TR'].rolling(window=14).mean().bfill()

            return plot_df, df
        else:
            return None, f"Hossz eltérés: raw_df {len(raw_df)} vs df {len(df)}"

    except Exception as e:
        return None, str(e)

df_plot, raw_features_or_error = load_data()

if df_plot is None:
    st.error(f"Hiba az adatok betöltésekor: {raw_features_or_error}")
else:
    df_feat = raw_features_or_error
    tab1, tab2 = st.tabs(["📉 OHLC Chart & Szignálok", "🔥 Korrelációs Hőtérkép"])

    with tab1:
        st.subheader("Interaktív Gyertyadiagram (Triple Barrier Címkékkel)")

        # Slider for range
        total_bars = len(df_plot)
        start_idx, end_idx = st.slider(
            "Válaszd ki az idősávot (gyertyák indexe):",
            0, total_bars, (max(0, total_bars - 500), total_bars)
        )

        df_subset = df_plot.iloc[start_idx:end_idx].copy()
        df_subset['Time_Str'] = df_subset['time']

        fig = go.Figure(data=[go.Candlestick(x=df_subset['Time_Str'],
                        open=df_subset['Open'],
                        high=df_subset['High'],
                        low=df_subset['Low'],
                        close=df_subset['Close'],
                        name='XAUUSD M1')])

        # Add signals
        buy_signals = df_subset[df_subset['target'] == 1]
        sell_signals = df_subset[df_subset['target'] == -1]

        if not buy_signals.empty:
            fig.add_trace(go.Scatter(
                x=buy_signals['Time_Str'],
                y=buy_signals['Low'] - (buy_signals['ATR_14'] * 0.5),
                mode='markers',
                marker=dict(symbol='triangle-up', size=12, color='lime', line=dict(width=1, color='black')),
                name='Buy (TP 1.75x)'
            ))

        if not sell_signals.empty:
            fig.add_trace(go.Scatter(
                x=sell_signals['Time_Str'],
                y=sell_signals['High'] + (sell_signals['ATR_14'] * 0.5),
                mode='markers',
                marker=dict(symbol='triangle-down', size=12, color='red', line=dict(width=1, color='black')),
                name='Sell (TP 1.75x)'
            ))

        fig.update_layout(height=800, xaxis_rangeslider_visible=False, template="plotly_dark", margin=dict(l=0, r=0, t=30, b=0))
        st.plotly_chart(fig, use_container_width=True)

        # Statisztika az aktuális nézetre
        st.markdown(f"**Jelenlegi nézet statisztikája:** Összes gyertya: {len(df_subset)} | Hold(0): {len(df_subset[df_subset['target']==0])} | Buy(1): {len(buy_signals)} | Sell(-1): {len(sell_signals)}")

    with tab2:
        st.subheader("XGBoost Feature Korrelációs Hőtérkép")
        st.markdown("Ideálisan kevés a sötétkék (1.0) vagy sötétpiros (-1.0), bizonyítva, hogy a **Data Leakage** megszűnt.")

        features_to_corr = df_feat.drop(columns=['timestamp', 'target', 'open', 'high', 'low', 'close', 'tick_volume', 'spread'], errors='ignore')
        features_to_corr = features_to_corr.select_dtypes(include=[np.number])
        corr_matrix = features_to_corr.corr()

        fig_corr = go.Figure(data=go.Heatmap(
                           z=corr_matrix.values,
                           x=corr_matrix.columns,
                           y=corr_matrix.columns,
                           colorscale='RdBu',
                           zmin=-1, zmax=1))

        fig_corr.update_layout(height=900, width=900, margin=dict(l=0, r=0, t=30, b=0))
        st.plotly_chart(fig_corr, use_container_width=True)
