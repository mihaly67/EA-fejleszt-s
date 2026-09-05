import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os

def run_offline_visualizer():
    print("==================================================")
    print("📈 OFFLINE LGBM PREDICTION VISUALIZER 📈")
    print("==================================================")

    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/labeled_dollar_bars_v5_strict.csv"
    lgbm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl"
    output_html = "/home/Jules/LGBM_mlops/Micro_LGBM/src/offline_lgbm_test_results.html"

    print(f"Loading raw dollar bars from {data_path}...")
    df = pd.read_csv(data_path)

    # Sort chronologically if not already
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df = df.sort_values('Start_Timestamp').reset_index(drop=True)

    print(f"Loading LightGBM model from {lgbm_model_path}...")
    clf = joblib.load(lgbm_model_path)

    # 1. Prepare Features for LGBM (The current lgbm_model_fusion_v5_tuned.pkl on Jules Box requires exactly 10 features,
    # not the 29 features from the older Contabo training script).
    features = [
        'Tick_Speed', 'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1',
        'Upper_Wick_ATR', 'Lower_Wick_ATR'
    ]

    # Temporarily pad missing columns with 0
    # The dataset `labeled_dollar_bars_v5_strict.csv` might not have ZigZag Dist_Micro_R, so we pad it.
    for f in features:
        if f not in df.columns:
            df[f] = 0.0

    X = df[features]

    print("Generating predictions...")
    probs = clf.predict_proba(X)

    classes = clf.classes_
    # The LGBM training script shifted the labels by +1 to avoid negative classes.
    idx_short = np.where(classes == 0)[0][0]
    idx_hold = np.where(classes == 1)[0][0]
    idx_long = np.where(classes == 2)[0][0]

    df['P_Long'] = probs[:, idx_long]
    df['P_Short'] = probs[:, idx_short]
    df['P_Noise'] = probs[:, idx_hold]

    # Asymmetric Optuna Thresholds (V5)
    TH_LONG = 0.35
    TH_SHORT = 0.36

    df['LGBM_Signal'] = 0
    for i in range(len(df)):
        if df['P_Long'].iloc[i] > TH_LONG and df['P_Long'].iloc[i] > df['P_Short'].iloc[i]:
            df.at[i, 'LGBM_Signal'] = 1
        elif df['P_Short'].iloc[i] > TH_SHORT and df['P_Short'].iloc[i] > df['P_Long'].iloc[i]:
            df.at[i, 'LGBM_Signal'] = -1

    # 3. Visualization
    print("Generating Plotly visualization...")

    # Let's find a dense subset of data where actual signals happened
    signal_indices = df[df['LGBM_Signal'] != 0].index
    if len(signal_indices) > 0:
        start_idx = max(0, signal_indices[len(signal_indices)//2] - 250)
        end_idx = min(len(df), start_idx + 500)
        plot_df = df.iloc[start_idx:end_idx].copy()
        print(f"Plotting subset from index {start_idx} to {end_idx} containing {len(plot_df[plot_df['LGBM_Signal'] != 0])} signals.")
    else:
        plot_df = df.iloc[-500:].copy()
        print("No signals found above thresholds. Plotting last 500 rows.")

    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, subplot_titles=('Price & LGBM Signals', 'Copilot Probabilities'),
                        row_width=[0.3, 0.7])

    # Plot Candlesticks as lines (similar to original code)
    colors = ["#228B22" if row["Close"] >= row["Open"] else "#B22222" for _, row in plot_df.iterrows()]
    for i, row in plot_df.iterrows():
        fig.add_trace(go.Scatter(
            x=[row["Start_Timestamp"], row["Start_Timestamp"]],
            y=[row["Low"], row["High"]],
            mode="lines",
            line=dict(color=colors[len(fig.data)], width=2),
            showlegend=False
        ), row=1, col=1)

    # Next Timestamp mapping for plotting signals exactly as original script
    plot_df["Next_Timestamp"] = plot_df["Start_Timestamp"].shift(-1)
    plot_df["Next_Open"] = plot_df["Open"].shift(-1)

    long_points = plot_df[plot_df["LGBM_Signal"] == 1]
    short_points = plot_df[plot_df["LGBM_Signal"] == -1]

    fig.add_trace(go.Scatter(x=long_points["Next_Timestamp"], y=long_points["Next_Open"],
                             mode="markers", marker=dict(symbol="triangle-up", color="#00FF00", size=12, line=dict(color="white", width=1)),
                             name="Predicted Long (+1)"), row=1, col=1)

    fig.add_trace(go.Scatter(x=short_points["Next_Timestamp"], y=short_points["Next_Open"],
                             mode="markers", marker=dict(symbol="triangle-down", color="#FF00FF", size=12, line=dict(color="white", width=1)),
                             name="Predicted Short (-1)"), row=1, col=1)

    # Plot Probabilities
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Long"], line=dict(color="#00FF00", width=1), name="P(Long)"), row=2, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Short"], line=dict(color="#FF00FF", width=1), name="P(Short)"), row=2, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Noise"], line=dict(color="gray", width=1, dash="solid"), name="P(Noise)"), row=2, col=1)

    fig.add_hline(y=TH_LONG, line_dash="dash", row=2, col=1, line_color="green", annotation_text=f"Long TH: {TH_LONG}")
    fig.add_hline(y=TH_SHORT, line_dash="dash", row=2, col=1, line_color="red", annotation_text=f"Short TH: {TH_SHORT}")

    fig.update_layout(
        height=900,
        width=1500,
        title_text=f"LGBM V5 Offline Sandbox Visualization (Padding applied)",
        xaxis_rangeslider_visible=False,
        plot_bgcolor="#111111",
        paper_bgcolor="#000000",
        font=dict(color="white")
    )

    fig.write_html(output_html)
    print(f"✅ Visualization saved to {output_html}")

if __name__ == "__main__":
    run_offline_visualizer()
