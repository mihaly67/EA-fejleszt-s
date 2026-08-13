import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import glob
import os
import argparse
import warnings
warnings.filterwarnings('ignore')

def load_and_merge_data(pred_file, m1_file):
    print(f"📥 Loading Raw Tick Data from: {m1_file}")
    df_raw = pd.read_csv(m1_file, on_bad_lines='skip')

    if 'Time' not in df_raw.columns or 'Bid' not in df_raw.columns or 'Ask' not in df_raw.columns:
        print("❌ Could not find required 'Time', 'Bid', 'Ask' columns in the MT5 data file.")
        return None, None, None

    # Convert Time to datetime
    df_raw['Datetime'] = pd.to_datetime(df_raw['Time'], format='mixed', errors='coerce')
    df_raw = df_raw.dropna(subset=['Datetime']).sort_values('Datetime')

    # Calculate Mid Price
    df_raw['Mid'] = (df_raw['Bid'] + df_raw['Ask']) / 2.0

    print("⏳ Resampling tick data into M1 (1-Minute) OHLC candlesticks...")
    df_raw.set_index('Datetime', inplace=True)
    df_m1 = df_raw['Mid'].resample('1min').ohlc()

    if 'Stoch_K' in df_raw.columns:
        # Scale Stoch_K from 0-100 to 0-1 so it fits on the probability chart
        stoch_series = df_raw['Stoch_K'].resample('1min').last() / 100.0
        df_m1['Stoch_K'] = stoch_series

    df_m1.dropna(inplace=True)
    df_m1.reset_index(inplace=True)

    # Rename for plotly compatibility
    df_m1.rename(columns={'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close'}, inplace=True)
    print(f"✅ Generated {len(df_m1)} M1 candlesticks.")

    print(f"📥 Loading Predictions Data: {pred_file}")
    df_pred = pd.read_csv(pred_file)

    # EA writes: ServerTime,P_Long,P_Short,P_Noise,Signal
    # Format of ServerTime: "2026.08.12 00:38:04"
    if 'ServerTime' in df_pred.columns:
        df_pred['Datetime'] = pd.to_datetime(df_pred['ServerTime'], format='mixed', errors='coerce')
        df_m1['Datetime'] = pd.to_datetime(df_m1['Datetime']).astype('datetime64[us]')
        df_pred['Datetime'] = df_pred['Datetime'].astype('datetime64[us]')
    else:
        print("❌ Could not find ServerTime column in predictions CSV.")
        return None

    df_pred = df_pred.dropna(subset=['Datetime']).sort_values('Datetime').reset_index(drop=True)

    print(f"Loaded {len(df_pred)} raw prediction rows.")
    print(f"Unique signals found in file: {df_pred['Signal'].unique()}")
    # Remove any HOLD/Noise signals from the chart markers, keep active ones
    active_preds = df_pred[df_pred['Signal'] != 0].copy()

    print(f"🔄 Merging {len(df_pred)} total predictions ({len(active_preds)} active signals) with {len(df_m1)} M1 bars...")

    # We use merge_asof to align the exact tick prediction to the closest preceding M1 candle
    # so we know what the chart looked like at that moment.
    merged = pd.merge_asof(active_preds, df_m1, on='Datetime', direction='backward')

    return merged, df_m1, df_pred

def generate_visualization(merged_df, df_m1, df_pred, out_file='live_forward_test_results.html'):
    print("🎨 Generating Dark Mode Plotly Visualization...")

    # To keep the chart readable, we might limit it to a 24h window around the predictions
    if len(df_pred) > 0:
        start_time = df_pred['Datetime'].min() - pd.Timedelta(hours=1)
        end_time = df_pred['Datetime'].max() + pd.Timedelta(hours=1)
        df_m1_plot = df_m1[(df_m1['Datetime'] >= start_time) & (df_m1['Datetime'] <= end_time)].copy()
    else:
        df_m1_plot = df_m1.copy()

    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, row_heights=[0.7, 0.3],
                        subplot_titles=('M1 Price Action & Active Copilot Signals', 'LightGBM Probabilities'))

    # 1. Price Candlesticks
    fig.add_trace(go.Candlestick(
        x=df_m1_plot['Datetime'],
        open=df_m1_plot['Open'],
        high=df_m1_plot['High'],
        low=df_m1_plot['Low'],
        close=df_m1_plot['Close'],
        name='M1 Price',
        increasing_line_color='#228B22', decreasing_line_color='#B22222'
    ), row=1, col=1)

    # 2. Add Signals
    longs = merged_df[merged_df['Signal'] == 1]
    shorts = merged_df[merged_df['Signal'] == -1]

    if not longs.empty:
        fig.add_trace(go.Scatter(
            x=longs['Datetime'],
            y=longs['Low'] - (longs['High'] - longs['Low']) * 0.5, # Plot below the candle
            mode='markers',
            marker=dict(symbol='triangle-up', size=14, color='lime', line=dict(width=1, color='darkgreen')),
            name='BUY Signal'
        ), row=1, col=1)

    if not shorts.empty:
        fig.add_trace(go.Scatter(
            x=shorts['Datetime'],
            y=shorts['High'] + (shorts['High'] - shorts['Low']) * 0.5, # Plot above the candle
            mode='markers',
            marker=dict(symbol='triangle-down', size=14, color='red', line=dict(width=1, color='darkred')),
            name='SELL Signal'
        ), row=1, col=1)

    # 3. Add Probabilities Oscillator
    fig.add_trace(go.Scatter(x=df_pred['Datetime'], y=df_pred['P_Long'], mode='lines', line=dict(color='lime', width=1.5), name='P_Long'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df_pred['Datetime'], y=df_pred['P_Short'], mode='lines', line=dict(color='red', width=1.5), name='P_Short'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df_pred['Datetime'], y=df_pred['P_Noise'], mode='lines', line=dict(color='gray', width=1, dash='dot'), name='P_Noise'), row=2, col=1)

    if 'Stoch_K' in df_m1_plot.columns:
        fig.add_trace(go.Scatter(x=df_m1_plot['Datetime'], y=df_m1_plot['Stoch_K'], mode='lines', line=dict(color='rgba(200, 200, 180, 0.4)', width=1), name='Stoch_K (Scaled)'), row=2, col=1)

    # Threshold Lines
    fig.add_hline(y=0.45, line_dash="dash", line_color="lime", row=2, col=1, annotation_text="Long Threshold (0.45)")
    fig.add_hline(y=0.37, line_dash="dash", line_color="red", row=2, col=1, annotation_text="Short Threshold (0.37)")
    fig.add_hline(y=0.35, line_dash="dash", line_color="gray", row=2, col=1, annotation_text="Noise Max (0.35)")

    fig.update_layout(
        title="Copilot Forward-Test Live Evaluation",
        yaxis_title="Price",
        yaxis2_title="Probability",
        xaxis_rangeslider_visible=False,
        template="plotly_dark",
        height=900,
        hovermode='x unified'
    )

    fig.write_html(out_file)
    print(f"✅ Visualization saved to {out_file}")

def evaluate_win_rate(merged_df, df_m1, tp_pts=1.5, sl_pts=1.0, max_bars=5):
    print(f"\n🎯 --- FORWARD TEST PROFIT & WIN RATE ANALYSIS ---")
    print(f"Parameters: Minimum TP={tp_pts} pts, SL={sl_pts} pts, Timeout={max_bars} bars")

    wins = 0
    losses = 0
    timeouts = 0

    total_potential_profit = 0.0
    total_deficit = 0.0

    stoch_saved_losses = 0
    stoch_sacrificed_wins = 0
    stoch_filtered_trades = 0

    # We iterate over every active signal and simulate the trade
    for index, row in merged_df.iterrows():
        signal = row['Signal']
        entry_time = row['Datetime']
        entry_price = row['Close']

        stoch_k = row.get('Stoch_K', 0.5)

        stoch_allowed = True
        if signal == 1 and stoch_k < 0.50: stoch_allowed = False
        if signal == -1 and stoch_k > 0.50: stoch_allowed = False

        if signal == 0: continue

        m1_start_idx = df_m1['Datetime'].searchsorted(entry_time, side='right') - 1
        if m1_start_idx < 0:
            m1_start_idx = 0

        outcome = "TIMEOUT"
        max_favorable_price = entry_price

        for i in range(1, max_bars + 1):
            if m1_start_idx + i >= len(df_m1):
                break

            future_bar = df_m1.iloc[m1_start_idx + i]
            high_price = future_bar['High']
            low_price = future_bar['Low']

            if signal == 1: # Long
                if high_price > max_favorable_price: max_favorable_price = high_price
                if low_price <= entry_price - sl_pts:
                    outcome = "LOSS"
                    break
                elif high_price >= entry_price + tp_pts:
                    outcome = "WIN"
            elif signal == -1: # Short
                if low_price < max_favorable_price: max_favorable_price = low_price
                if high_price >= entry_price + sl_pts:
                    outcome = "LOSS"
                    break
                elif low_price <= entry_price - tp_pts:
                    outcome = "WIN"

        actual_mfe = 0.0
        if outcome != "LOSS":
            mfe_price = entry_price
            for i in range(1, max_bars + 1):
                if m1_start_idx + i >= len(df_m1): break
                fb = df_m1.iloc[m1_start_idx + i]
                if signal == 1:
                    if fb['High'] > mfe_price: mfe_price = fb['High']
                    if fb['Low'] <= entry_price - sl_pts: break
                if signal == -1:
                    if fb['Low'] < mfe_price: mfe_price = fb['Low']
                    if fb['High'] >= entry_price + sl_pts: break

            actual_mfe = abs(mfe_price - entry_price)

        if outcome == "WIN":
            wins += 1
            total_potential_profit += actual_mfe
            if not stoch_allowed: stoch_sacrificed_wins += 1
        elif outcome == "LOSS":
            losses += 1
            total_deficit += sl_pts
            if not stoch_allowed: stoch_saved_losses += 1
        else:
            timeouts += 1
            total_potential_profit += actual_mfe

        if not stoch_allowed: stoch_filtered_trades += 1

    total_trades = wins + losses + timeouts
    win_rate = (wins / total_trades * 100) if total_trades > 0 else 0.0

    print(f"Total Evaluated Trades: {total_trades}")
    print(f"  - 🟩 WINS (Hit TP {tp_pts}): {wins}")
    print(f"  - 🟥 LOSSES (Hit SL {sl_pts}): {losses}")
    print(f"  - 🟨 TIMEOUTS ({max_bars} bars expired): {timeouts}")
    print(f"\n⭐ ESTIMATED CLEAN WIN RATE: {win_rate:.2f}%")

    print(f"\n💰 --- PROFITABILITY (Maximum Favorable Excursion) ---")
    print(f"  - Total Deficit (Losses x {sl_pts} pt SL): -{total_deficit:.2f} pts")
    print(f"  - Total Potential Profit (Max points reached within {max_bars} bars): +{total_potential_profit:.2f} pts")
    net_potential = total_potential_profit - total_deficit
    marker = "📈 PROFITABLE" if net_potential > 0 else "📉 DEFICIT"
    print(f"  -> Net Max Potential: {net_potential:+.2f} pts ({marker})")

    print(f"\n🧪 --- STOCHASTIC FILTER SIMULATION (Stoch > 50 for Long, < 50 for Short) ---")
    print(f"  - Total Trades Filtered Out: {stoch_filtered_trades}")
    print(f"  - 🟩 Sacrificed WINS (Good trades missed): {stoch_sacrificed_wins}")
    print(f"  - 🟥 Saved LOSSES (Bad trades avoided): {stoch_saved_losses}")

    if stoch_filtered_trades > 0:
        net_saved = stoch_saved_losses - stoch_sacrificed_wins
        print(f"  -> Net Benefit of Filter: {net_saved:+} trades")
        if net_saved > 0:
            print("  -> Verdict: Stoch filter would IMPROVE profitability by blocking more losses than wins.")
        else:
            print("  -> Verdict: Stoch filter would HURT profitability (blocks too many valid breakouts).")

def generate_statistics(merged_df, df_pred):
    print("\n📊 --- FORWARD TEST STATISTICS ---")
    total_preds = len(df_pred)
    long_count = len(df_pred[df_pred['Signal'] == 1])
    short_count = len(df_pred[df_pred['Signal'] == -1])
    noise_count = len(df_pred[df_pred['Signal'] == 0])

    print(f"Total Model Inferences (Dollar Bars Closed): {total_preds}")
    print(f"Total Active Signals Triggered: {long_count + short_count}")
    print(f"  - Long Signals: {long_count}")
    print(f"  - Short Signals: {short_count}")
    print(f"  - Noise (Hold) Ignored: {noise_count}")

    if total_preds > 0:
        print(f"Signal Activity Rate: {((long_count + short_count) / total_preds) * 100:.2f}%")

    print("\nNote: True Win Rate evaluation requires the 5-bar Prado method logic which can be added later.")

def main():
    parser = argparse.ArgumentParser(description="Live Copilot Forward-Test Analyzer")
    parser.add_argument('--pred', type=str, help="Path to LGBM_Live_Predictions CSV", default=None)
    parser.add_argument('--m1', type=str, help="Path to Merkava_M1 CSV", default=None)
    parser.add_argument('--out', type=str, help="Output HTML filename", default="live_forward_test_results.html")
    args = parser.parse_args()

    pred_file = args.pred
    m1_file = args.m1

    # Auto-discover if not provided
    if not pred_file:
        files = glob.glob("/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/LGBM_Live_Predictions_*.csv")
        if files:
            pred_file = max(files, key=os.path.getmtime)
        else:
            files = glob.glob("LGBM_Live_Predictions_*.csv")
            if files: pred_file = max(files, key=os.path.getmtime)

    if not m1_file:
        # Assuming Merkava Data Miner writes M1 files starting with Merkava_MGC
        files = glob.glob("/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/Merkava_MGC*.csv")
        if files:
            m1_file = max(files, key=os.path.getmtime)
        else:
            files = glob.glob("Merkava_MGC*.csv")
            if files: m1_file = max(files, key=os.path.getmtime)

    if not pred_file or not m1_file:
        print("❌ Could not automatically locate required CSV files. Please specify using --pred and --m1")
        return

    merged_df, df_m1, df_pred = load_and_merge_data(pred_file, m1_file)

    if merged_df is not None:
        generate_statistics(merged_df, df_pred)
        # Evaluate strict Prado Win Rate
        evaluate_win_rate(merged_df[merged_df['Signal'] != 0], df_m1)
        generate_visualization(merged_df, df_m1, df_pred, args.out)

if __name__ == "__main__":
    main()
