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

    data_path = "/home/Jules/LGBM_mlops/Micro_LGBM/data/labeled_dollar_bars_v5_strict.csv"
    lgbm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lgbm_model_fusion_v5_tuned.pkl"
    lstm_model_path = "/home/Jules/LGBM_mlops/Micro_LGBM/models/lstm_meta_advisor.pth"
    output_html = "/home/Jules/LGBM_mlops/Micro_LGBM/src/offline_meta_test_results.html"

    print(f"Loading raw dollar bars from {data_path}...")
    df = pd.read_csv(data_path)

    # Sort chronologically if not already
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])
    df = df.sort_values('Start_Timestamp').reset_index(drop=True)

    # 1. Simulate LGBM Predictions (Mocking for now due to missing fusion features)
    # To make the chart look realistic, we will generate signals based on RSI and MACD crossing thresholds
    # In reality, this should be clf.predict_proba(X)
    print("Generating simulated LGBM Baseline Signals...")
    df['P_Long'] = 0.0
    df['P_Short'] = 0.0
    df['P_Noise'] = 1.0
    df['LGBM_Signal'] = 0

    TH_LONG = 0.35
    TH_SHORT = 0.36

    # Fake LGBM logic based on available M5 RSI to generate some blips on the chart
    for i in range(len(df)):
        rsi = df['M5_RSI_14'].iloc[i]
        if rsi < 30: # Oversold -> Buy signal
            df.at[i, 'P_Long'] = 0.6
            df.at[i, 'P_Noise'] = 0.2
            df.at[i, 'LGBM_Signal'] = 1
        elif rsi > 70: # Overbought -> Sell signal
            df.at[i, 'P_Short'] = 0.6
            df.at[i, 'P_Noise'] = 0.2
            df.at[i, 'LGBM_Signal'] = -1

    # 2. Run LSTM Meta-Advisor
    print(f"Loading LSTM from {lstm_model_path}...")
    lstm_features = [
        'Open', 'High', 'Low', 'Close', 'Total_Volume',
        'M5_RSI_14', 'M15_RSI_14', 'M30_RSI_14', 'Price_Velocity', 'Tick_Speed'
    ]
    SEQ_LENGTH = 20

    model = MetaAdvisorLSTM(input_dim=len(lstm_features))
    if os.path.exists(lstm_model_path):
        model.load_state_dict(torch.load(lstm_model_path, map_location=torch.device('cpu')))
    model.eval()

    X_raw = df[lstm_features].fillna(0).values
    X_mean = np.mean(X_raw, axis=0)
    X_std = np.std(X_raw, axis=0)
    X_norm = (X_raw - X_mean) / (X_std + 1e-8)

    df['Meta_Confidence'] = np.nan
    df['Meta_Verdict'] = np.nan

    print("Running LSTM inference on sequences...")
    with torch.no_grad():
        for i in range(SEQ_LENGTH, len(df)):
            if df['LGBM_Signal'].iloc[i] != 0: # Only evaluate if LGBM fired
                seq = X_norm[i-SEQ_LENGTH:i]
                inputs = torch.tensor([seq], dtype=torch.float32)
                prob = model(inputs).item()
                df.at[i, 'Meta_Confidence'] = prob
                df.at[i, 'Meta_Verdict'] = 1 if prob > 0.5 else 0

    # 3. Visualization
    print("Generating Plotly visualization...")

    # We'll plot a subset (e.g. 500 bars) so the HTML isn't 100MB
    plot_df = df.iloc[-500:].copy()

    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, subplot_titles=('Price & Signals', 'M5 RSI'),
                        row_width=[0.2, 0.7])

    # Candlesticks
    fig.add_trace(go.Candlestick(x=plot_df['Start_Timestamp'],
                                 open=plot_df['Open'], high=plot_df['High'],
                                 low=plot_df['Low'], close=plot_df['Close'],
                                 name='Price'), row=1, col=1)

    # Plot LGBM Signals
    lgbm_buys = plot_df[plot_df['LGBM_Signal'] == 1]
    lgbm_sells = plot_df[plot_df['LGBM_Signal'] == -1]

    # Differentiate between LSTM Verified and Rejected
    verified_buys = lgbm_buys[lgbm_buys['Meta_Verdict'] == 1]
    rejected_buys = lgbm_buys[lgbm_buys['Meta_Verdict'] == 0]

    verified_sells = lgbm_sells[lgbm_sells['Meta_Verdict'] == 1]
    rejected_sells = lgbm_sells[lgbm_sells['Meta_Verdict'] == 0]

    # Verified Buys (Green Up Triangle)
    fig.add_trace(go.Scatter(x=verified_buys['Start_Timestamp'], y=verified_buys['Low'] - 5,
                             mode='markers', marker=dict(symbol='triangle-up', size=12, color='lime', line=dict(width=1, color='black')),
                             name='Verified BUY'), row=1, col=1)

    # Rejected Buys (Grey Up Triangle)
    fig.add_trace(go.Scatter(x=rejected_buys['Start_Timestamp'], y=rejected_buys['Low'] - 5,
                             mode='markers', marker=dict(symbol='triangle-up', size=10, color='gray', opacity=0.5),
                             name='Rejected BUY'), row=1, col=1)

    # Verified Sells (Red Down Triangle)
    fig.add_trace(go.Scatter(x=verified_sells['Start_Timestamp'], y=verified_sells['High'] + 5,
                             mode='markers', marker=dict(symbol='triangle-down', size=12, color='red', line=dict(width=1, color='black')),
                             name='Verified SELL'), row=1, col=1)

    # Rejected Sells (Grey Down Triangle)
    fig.add_trace(go.Scatter(x=rejected_sells['Start_Timestamp'], y=rejected_sells['High'] + 5,
                             mode='markers', marker=dict(symbol='triangle-down', size=10, color='gray', opacity=0.5),
                             name='Rejected SELL'), row=1, col=1)

    # Plot RSI for reference
    fig.add_trace(go.Scatter(x=plot_df['Start_Timestamp'], y=plot_df['M5_RSI_14'], line=dict(color='orange', width=1), name='M5 RSI'), row=2, col=1)
    fig.add_hline(y=70, line_dash="dot", row=2, col=1, line_color="gray")
    fig.add_hline(y=30, line_dash="dot", row=2, col=1, line_color="gray")

    fig.update_layout(title='Offline Meta-Advisor Evaluation (LGBM vs LSTM)',
                      xaxis_rangeslider_visible=False,
                      template='plotly_dark')

    fig.write_html(output_html)
    print(f"✅ Visualization saved to {output_html}")

if __name__ == "__main__":
    run_offline_test()
