import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px

st.set_page_config(page_title="Merkava XGBoost Data Inspector", layout="wide")

st.title("Merkava ML-Ops: Triple Barrier Címkék & Korreláció")
st.markdown("Ellenőrizd az M1 XAUUSD gyertyadiagramot a Triple Barrier szignálokkal és az új, szivárgásmentes feature korrelációt.")

DATA_PATH = "/home/misi/Merkava_ML_Ops/data/processed/scalp_features.parquet"
RAW_CSV_PATH = "/home/misi/Merkava_ML_Ops/data/Merkava_XAUUSD_MINER_M1_SCRIPT_v1.04_20260618_022831.csv"

@st.cache_data
def load_data():
    try:
        # Load processed features (with target)
        df_feat = pd.read_parquet(DATA_PATH)
        if 'time' in df_feat.columns:
            df_feat['time'] = pd.to_datetime(df_feat['time'])
            df_feat.set_index('time', inplace=True)

        # Load raw data for OHLC
        df_raw = pd.read_csv(RAW_CSV_PATH)
        df_raw['time'] = pd.to_datetime(df_raw['Time'], format='%Y.%m.%d %H:%M:%S.%f')
        df_raw.set_index('time', inplace=True)
        df_raw.rename(columns={'Bar_Open': 'Open', 'Bar_High': 'High', 'Bar_Low': 'Low', 'Bar_Close': 'Close'}, inplace=True)

        # Calculate ATR for marker placement
        df_raw['TR'] = np.maximum((df_raw['High'] - df_raw['Low']),
                       np.maximum(abs(df_raw['High'] - df_raw['Close'].shift(1)),
                                  abs(df_raw['Low'] - df_raw['Close'].shift(1))))
        df_raw['ATR_14'] = df_raw['TR'].rolling(window=14).mean()

        # Join OHLC with Targets
        # Use target col from parquet
        target_col = 'target' if 'target' in df_feat.columns else 'Target'

        # Merge only on matching indexes
        df_plot = df_raw[['Open', 'High', 'Low', 'Close', 'ATR_14']].join(df_feat[[target_col]], how='inner')
        df_plot.rename(columns={target_col: 'Target'}, inplace=True)

        return df_feat, df_plot
    except Exception as e:
        return None, str(e)

df_feat, df_plot_or_error = load_data()

if df_feat is None:
    st.error(f"Hiba az adatok betöltésekor: {df_plot_or_error}")
else:
    df_plot = df_plot_or_error

    tab1, tab2 = st.tabs(["📉 OHLC Chart & Szignálok", "🔥 Korrelációs Hőtérkép"])

    with tab1:
        st.subheader("Interaktív Gyertyadiagram (Triple Barrier Címkékkel)")

        # Slider for range
        total_bars = len(df_plot)
        start_idx, end_idx = st.slider(
            "Válaszd ki az idősávot (gyertyák indexe):",
            0, total_bars, (max(0, total_bars - 1000), total_bars)
        )

        df_subset = df_plot.iloc[start_idx:end_idx]

        fig = go.Figure(data=[go.Candlestick(x=df_subset.index,
                        open=df_subset['Open'],
                        high=df_subset['High'],
                        low=df_subset['Low'],
                        close=df_subset['Close'],
                        name='XAUUSD M1')])

        # Add signals
        buy_signals = df_subset[df_subset['Target'] == 1]
        sell_signals = df_subset[df_subset['Target'] == 2]

        if not buy_signals.empty:
            fig.add_trace(go.Scatter(
                x=buy_signals.index,
                y=buy_signals['Low'] - (buy_signals['ATR_14'] * 0.5),
                mode='markers',
                marker=dict(symbol='triangle-up', size=10, color='lime', line=dict(width=1, color='black')),
                name='Buy (TP 3.5x)'
            ))

        if not sell_signals.empty:
            fig.add_trace(go.Scatter(
                x=sell_signals.index,
                y=sell_signals['High'] + (sell_signals['ATR_14'] * 0.5),
                mode='markers',
                marker=dict(symbol='triangle-down', size=10, color='red', line=dict(width=1, color='black')),
                name='Sell (TP 3.5x)'
            ))

        fig.update_layout(height=700, xaxis_rangeslider_visible=False, template="plotly_dark", margin=dict(l=0, r=0, t=30, b=0))
        st.plotly_chart(fig, use_container_width=True)

        # Statisztika az aktuális nézetre
        st.markdown(f"**Jelenlegi nézet statisztikája:** Összes gyertya: {len(df_subset)} | Hold(0): {len(df_subset[df_subset['Target']==0])} | Buy(1): {len(buy_signals)} | Sell(2): {len(sell_signals)}")

    with tab2:
        st.subheader("XGBoost Feature Korrelációs Hőtérkép")
        st.markdown("Az alábbi hőtérkép mutatja a feature-ök közötti kapcsolatot. Ideálisan kevés a sötétkék (1.0) vagy sötétpiros (-1.0), bizonyítva, hogy a **Data Leakage** megszűnt.")

        features_to_corr = df_feat.drop(columns=['time', 'target', 'Target', 'Open', 'High', 'Low', 'Close', 'Tick_Volume', 'Spread'], errors='ignore')
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
