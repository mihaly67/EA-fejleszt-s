import pandas as pd
import numpy as np
import torch
import joblib
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os

from nn_meta_model import MetaAdvisorLSTM

def run_tester():
    print("==================================================")
    print("📈 OFFLINE STANDALONE LSTM vs LGBM TESTER 📈")
    print("==================================================")

    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/labeled_dollar_bars_v5_strict.csv"
    lgbm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl"
    lstm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_advisor.pth"
    scaler_mean_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_mean.npy"
    scaler_std_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_standalone_scaler_std.npy"
    output_html = "/home/Jules/LGBM_mlops/Micro_LGBM/src/offline_standalone_test_results.html"

    df = pd.read_csv(data_path).dropna().reset_index(drop=True)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df = df.sort_values('Start_Timestamp').reset_index(drop=True)

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

    lstm_features = [
        'Total_Volume',
        'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed',
        'Dist_Micro_R', 'Dist_Micro_S', 'Dist_Sec_R', 'Dist_Sec_S', 'Dist_Ter_R', 'Dist_Ter_S',
        'Consecutive_Bars', 'Dist_EMA_10', 'EMA_10_Slope'
    ]

    for f in lstm_features:
        if f not in df.columns:
            df[f] = 0.0

    SEQ_LENGTH = 20

    model = MetaAdvisorLSTM(input_dim=len(lstm_features), output_dim=3)
    model.load_state_dict(torch.load(lstm_model_path, map_location=torch.device('cpu')))
    model.eval()

    X_raw = df[lstm_features].fillna(0).values
    X_mean = np.load(scaler_mean_path)
    X_std = np.load(scaler_std_path)

    X_norm = (X_raw - X_mean) / (X_std + 1e-8)

    df['LSTM_Signal'] = 0
    df['LSTM_P_Long'] = np.nan
    df['LSTM_P_Short'] = np.nan

    print("Running LSTM inference on sequences...")
    with torch.no_grad():
        for i in range(SEQ_LENGTH, len(df)):
            seq = X_norm[i - SEQ_LENGTH + 1 : i + 1].copy()
            inputs = torch.tensor(np.array([seq]), dtype=torch.float32)
            out_logits = model(inputs) # Shape (1, 3)

            # Apply softmax
            probs = torch.softmax(out_logits, dim=1).numpy()[0]

            # indices: 0 -> Short (-1), 1 -> Noise (0), 2 -> Long (1)
            lstm_p_short = probs[0]
            lstm_p_noise = probs[1]
            lstm_p_long = probs[2]

            df.at[i, 'LSTM_P_Short'] = lstm_p_short
            df.at[i, 'LSTM_P_Long'] = lstm_p_long

            # Simple argmax for signal
            pred_idx = np.argmax(probs)
            if pred_idx == 0:
                df.at[i, 'LSTM_Signal'] = -1
            elif pred_idx == 2:
                df.at[i, 'LSTM_Signal'] = 1
            else:
                df.at[i, 'LSTM_Signal'] = 0

    print("Generating Plotly visualization...")

    start_idx = max(0, len(df) - 1000)
    end_idx = len(df)
    plot_df = df.iloc[start_idx:end_idx].copy()

    # Calculate agreement
    lgbm_matches = len(plot_df[plot_df['LGBM_Signal'] == plot_df['Target_Label']])
    lstm_matches = len(plot_df[plot_df['LSTM_Signal'] == plot_df['Target_Label']])
    print(f"Subset Accuracy -> LGBM: {lgbm_matches}/{len(plot_df)}, LSTM: {lstm_matches}/{len(plot_df)}")

    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, subplot_titles=('Price & Signals', 'LGBM Probabilities', 'LSTM Probabilities'),
                        row_width=[0.2, 0.2, 0.6])

    # Plot Candlesticks
    fig.add_trace(go.Candlestick(x=plot_df['Start_Timestamp'],
                                 open=plot_df['Open'],
                                 high=plot_df['High'],
                                 low=plot_df['Low'],
                                 close=plot_df['Close'],
                                 name='OHLC'), row=1, col=1)

    # Plot LGBM Signals
    lgbm_buys = plot_df[plot_df['LGBM_Signal'] == 1]
    lgbm_sells = plot_df[plot_df['LGBM_Signal'] == -1]

    fig.add_trace(go.Scatter(x=lgbm_buys['Start_Timestamp'], y=lgbm_buys['Low'],
                             mode='markers', marker=dict(symbol='triangle-up', size=14, color='lime', line=dict(width=1, color='black')),
                             name='LGBM BUY'), row=1, col=1)
    fig.add_trace(go.Scatter(x=lgbm_sells['Start_Timestamp'], y=lgbm_sells['High'],
                             mode='markers', marker=dict(symbol='triangle-down', size=14, color='red', line=dict(width=1, color='black')),
                             name='LGBM SELL'), row=1, col=1)

    # Plot LSTM Signals (offset slightly on price for visibility, or different markers)
    lstm_buys = plot_df[plot_df['LSTM_Signal'] == 1]
    lstm_sells = plot_df[plot_df['LSTM_Signal'] == -1]

    fig.add_trace(go.Scatter(x=lstm_buys['Start_Timestamp'], y=lstm_buys['Low'] - 2,
                             mode='markers', marker=dict(symbol='star-triangle-up', size=10, color='cyan', line=dict(width=1, color='black')),
                             name='LSTM BUY'), row=1, col=1)
    fig.add_trace(go.Scatter(x=lstm_sells['Start_Timestamp'], y=lstm_sells['High'] + 2,
                             mode='markers', marker=dict(symbol='star-triangle-down', size=10, color='magenta', line=dict(width=1, color='black')),
                             name='LSTM SELL'), row=1, col=1)

    # Plot LGBM Probabilities
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Long"], line=dict(color='#00FF00', width=1), name='LGBM P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["P_Short"], line=dict(color='#FF00FF', width=1), name='LGBM P(Short)'), row=2, col=1)

    # Plot LSTM Probabilities
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["LSTM_P_Long"], line=dict(color='cyan', width=1), name='LSTM P(Long)'), row=3, col=1)
    fig.add_trace(go.Scatter(x=plot_df["Start_Timestamp"], y=plot_df["LSTM_P_Short"], line=dict(color='magenta', width=1), name='LSTM P(Short)'), row=3, col=1)

    fig.update_layout(title='Offline Tester: LGBM vs Independent LSTM',
                      xaxis_rangeslider_visible=False,
                      template='plotly_dark')

    fig.write_html(output_html)
    print(f"✅ Visualization saved to {output_html}")

if __name__ == "__main__":
    run_tester()
