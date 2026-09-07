import sys
sys.path.append("/home/Jules/LGBM_mlops/Micro_LGBM/src")
import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import torch
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os
from nn_meta_model import MetaAdvisorLSTM

def run_offline_test():
    print("==================================================")
    print("📈 OFFLINE META-ADVISOR TEST & VISUALIZER 📈")
    print("==================================================")

    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/meta_labeled_fused_v5_mom.csv"
    lgbm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl"
    lstm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    scaler_mean_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_mean.npy"
    scaler_std_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_scaler_std.npy"
    output_html = "/home/Jules/LGBM_mlops/Micro_LGBM/src/offline_meta_test_results.html"

    print(f"Loading raw dollar bars from {data_path}...")
    df = pd.read_csv(data_path)

    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df = df.sort_values('Start_Timestamp').reset_index(drop=True)

    print(f"Loading LightGBM model from {lgbm_model_path}...")
    clf = joblib.load(lgbm_model_path)

    lgbm_features = [
        'Tick_Speed', 'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1',
        'Upper_Wick_ATR', 'Lower_Wick_ATR'
    ]

    for f in lgbm_features:
        if f not in df.columns:
            df[f] = 0.0

    X_lgbm = df[lgbm_features]
    print("Generating fresh LGBM predictions...")
    probs = clf.predict_proba(X_lgbm)

    classes = clf.classes_
    idx_short = np.where(classes == 0)[0][0]
    idx_hold = np.where(classes == 1)[0][0]
    idx_long = np.where(classes == 2)[0][0]

    df['P_Long'] = probs[:, idx_long]
    df['P_Short'] = probs[:, idx_short]
    df['P_Noise'] = probs[:, idx_hold]

    TH_LONG = 0.35
    TH_SHORT = 0.36
    TH_NOISE = 0.47

    df['LGBM_Signal'] = 0
    df.loc[(df['P_Long'] > TH_LONG) & (df['P_Long'] > df['P_Short']), 'LGBM_Signal'] = 1
    df.loc[(df['P_Short'] > TH_SHORT) & (df['P_Short'] > df['P_Long']), 'LGBM_Signal'] = -1

    noise_mask = df['P_Noise'] >= TH_NOISE
    df.loc[noise_mask, 'LGBM_Signal'] = 0
    print(f"Filtered out {noise_mask.sum()} signals due to P_Noise >= {TH_NOISE}.")

    print("Loaded Real LGBM Baseline Signals.")

    print(f"Loading LSTM from {lstm_model_path}...")
    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'P_Long', 'P_Short', 'P_Noise',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    existing_lstm_features = lstm_features
    for f in existing_lstm_features:
        if f not in df.columns:
            df[f] = 0.0

    SEQ_LENGTH = 20

    model = MetaAdvisorLSTM(input_dim=len(existing_lstm_features))
    if os.path.exists(lstm_model_path):
        model.load_state_dict(torch.load(lstm_model_path, map_location=torch.device('cpu')))
    model.eval()

    X_raw = df[existing_lstm_features].fillna(0).values
    try:
        X_mean = np.load(scaler_mean_path)
        X_std = np.load(scaler_std_path)
        print("[INFO] Loaded global feature scalers for normalization.")
    except FileNotFoundError:
        print("[WARNING] Missing global scalers! Computing from current dataset...")
        X_mean = np.mean(X_raw, axis=0)
        X_std = np.std(X_raw, axis=0)

    X_norm = (X_raw - X_mean) / (X_std + 1e-8)

    df['Meta_Confidence'] = np.nan
    df['Meta_Verdict'] = np.nan

    print("Running LSTM inference on sequences...")
    with torch.no_grad():
        # Evaluate EVERY bar to create a continuous confidence curve
        for i in range(SEQ_LENGTH, len(df)):
            seq = X_norm[i - SEQ_LENGTH + 1 : i + 1].copy()
            inputs = torch.tensor(np.array([seq]), dtype=torch.float32)
            prob = model(inputs).item()
            df.at[i, 'Meta_Confidence'] = prob

            if df['LGBM_Signal'].iloc[i] != 0:
                df.at[i, 'Meta_Verdict'] = 1 if prob > 0.5 else 0

    print("Generating Plotly visualization...")

    signal_indices = df[df['LGBM_Signal'] != 0].index
    if len(signal_indices) > 0:
        start_idx = max(0, signal_indices[-1] - 250)
        end_idx = min(len(df), start_idx + 500)
        plot_df = df.iloc[start_idx:end_idx].copy()
        print(f"Plotting subset from index {start_idx} to {end_idx} containing {len(plot_df[plot_df['LGBM_Signal'] != 0])} signals.")
    else:
        plot_df = df.iloc[-500:].copy()
        print("No signals found in dataset. Plotting last 500 rows.")

    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, subplot_titles=('Price & Signals (LGBM + Meta Advisor)', 'LGBM Probabilities', 'LSTM Confidence Curve'),
                        row_width=[0.2, 0.2, 0.6])

    fig.add_trace(go.Candlestick(x=plot_df['Start_Timestamp'],
                                 open=plot_df['Open'], high=plot_df['High'],
                                 low=plot_df['Low'], close=plot_df['Close'],
                                 name='Price'), row=1, col=1)

    plot_df["Next_Timestamp"] = plot_df["Start_Timestamp"].shift(-1)
    plot_df["Next_Open"] = plot_df["Open"].shift(-1)

    lgbm_buys = plot_df[plot_df['LGBM_Signal'] == 1]
    lgbm_sells = plot_df[plot_df['LGBM_Signal'] == -1]

    verified_buys = lgbm_buys[lgbm_buys['Meta_Verdict'] == 1]
    rejected_buys = lgbm_buys[lgbm_buys['Meta_Verdict'] == 0]

    verified_sells = lgbm_sells[lgbm_sells['Meta_Verdict'] == 1]
    rejected_sells = lgbm_sells[lgbm_sells['Meta_Verdict'] == 0]

    # Explicitly print the counts so we can see what exists in the plot dataframe
    print(f"Plotting Verified Buys: {len(verified_buys)}, Rejected Buys: {len(rejected_buys)}")
    print(f"Plotting Verified Sells: {len(verified_sells)}, Rejected Sells: {len(rejected_sells)}")

    fig.add_trace(go.Scatter(x=verified_buys['Next_Timestamp'], y=verified_buys['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-up', size=14, color='lime', line=dict(width=1, color='black')),
                             name='Verified BUY'), row=1, col=1)

    # User requested solid grey. #808080 is solid grey.
    fig.add_trace(go.Scatter(x=rejected_buys['Next_Timestamp'], y=rejected_buys['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-up', size=14, color='#808080', line=dict(width=1, color='black')),
                             name='Rejected BUY'), row=1, col=1)

    fig.add_trace(go.Scatter(x=verified_sells['Next_Timestamp'], y=verified_sells['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-down', size=14, color='red', line=dict(width=1, color='black')),
                             name='Verified SELL'), row=1, col=1)

    fig.add_trace(go.Scatter(x=rejected_sells['Next_Timestamp'], y=rejected_sells['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-down', size=14, color='#808080', line=dict(width=1, color='black')),
                             name='Rejected SELL'), row=1, col=1)

    # Plot Probabilities
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Long"], line=dict(color='#00FF00', width=1), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Short"], line=dict(color='#FF00FF', width=1), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Noise"], line=dict(color='gray', width=1, dash='solid'), name='P(Noise)'), row=2, col=1)

    fig.add_hline(y=TH_LONG, line_dash="dash", row=2, col=1, line_color="green", annotation_text=f"Long TH: {TH_LONG}")
    fig.add_hline(y=TH_SHORT, line_dash="dash", row=2, col=1, line_color="red", annotation_text=f"Short TH: {TH_SHORT}")
    fig.add_hline(y=TH_NOISE, line_dash="dot", row=2, col=1, line_color="gray", annotation_text=f"Noise TH: {TH_NOISE}")

    # Plot LSTM Confidence on row 3
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["Meta_Confidence"], line=dict(color='cyan', width=1.5), name='LSTM Confidence'), row=3, col=1)
    fig.add_hline(y=0.5, line_dash="dash", row=3, col=1, line_color="yellow", annotation_text="Verdict TH: 0.5")

    fig.update_layout(title='Offline Meta-Advisor Evaluation (LGBM vs LSTM)',
                      xaxis_rangeslider_visible=False,
                      template='plotly_dark')

    fig.write_html(output_html)
    print(f"✅ Visualization saved to {output_html}")

if __name__ == "__main__":
    run_offline_test()
