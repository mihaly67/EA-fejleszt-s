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

def generate_visualization(merged_df, df_m1, df_pred, out_file='live_forward_test_results.html', p_long=0.35, p_short=0.36, p_noise=0.47):
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

    # 2. Add Signals (Strictly Recalculated for Visualization)
    # We ignore the raw Signal column and strictly enforce the user's thresholds and Stoch hard filter.
    df_viz = merged_df.copy()

    # Calculate RAW signals
    cond_long_raw = (df_viz['P_Long'] > p_long) & (df_viz['P_Noise'] < p_noise) & (df_viz['P_Long'] > df_viz['P_Short'])
    cond_short_raw = (df_viz['P_Short'] > p_short) & (df_viz['P_Noise'] < p_noise) & (df_viz['P_Short'] > df_viz['P_Long'])

    # Apply Stoch Filter
    if 'Stoch_K' not in df_viz.columns:
        df_viz['Stoch_K'] = 0.5

    cond_long_filtered = cond_long_raw & (df_viz['Stoch_K'] >= 0.50)
    cond_short_filtered = cond_short_raw & (df_viz['Stoch_K'] <= 0.50)

    longs = df_viz[cond_long_filtered]
    shorts = df_viz[cond_short_filtered]

    print(f"\n🖌️ VISUALIZATION DATA:")
    print(f"  - Plotted Longs: {len(longs)}")
    print(f"  - Plotted Shorts: {len(shorts)}")

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
    fig.add_hline(y=p_long, line_dash="dash", line_color="lime", row=2, col=1, annotation_text=f"Long Threshold ({p_long})")
    fig.add_hline(y=p_short, line_dash="dash", line_color="red", row=2, col=1, annotation_text=f"Short Threshold ({p_short})")
    fig.add_hline(y=p_noise, line_dash="dash", line_color="gray", row=2, col=1, annotation_text=f"Max Noise ({p_noise})")

    fig.update_layout(
        title="Copilot Forward-Test Live Evaluation",
        yaxis_title="Price",
        yaxis2_title="Probability",
        yaxis2=dict(range=[0, 1]), # Force Y-axis scale to 0.0 - 1.0 for Stoch & Probs
        xaxis_rangeslider_visible=False,
        template="plotly_dark",
        height=900,
        hovermode='x unified'
    )

    fig.write_html(out_file)
    print(f"✅ Visualization saved to {out_file}")

def evaluate_win_rate(merged_df, df_m1, tp_pts=1.5, sl_pts=1.5, be_trigger_pts=1.0, max_bars=5):
    print(f"\n🎯 --- FORWARD TEST PROFIT & WIN RATE ANALYSIS ---")
    print(f"Parameters: Minimum TP={tp_pts} pts, SL={sl_pts} pts, Break-Even Trigger={be_trigger_pts} pts, Timeout={max_bars} bars")

    wins = 0
    losses = 0
    timeouts = 0
    break_evens = 0

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
        be_active = False

        for i in range(1, max_bars + 1):
            if m1_start_idx + i >= len(df_m1): break
            future_bar = df_m1.iloc[m1_start_idx + i]
            high_price = future_bar['High']
            low_price = future_bar['Low']

            if signal == 1: # Long
                if high_price > max_favorable_price: max_favorable_price = high_price
                # Check BE Trigger first
                if high_price >= entry_price + be_trigger_pts: be_active = True

                # If BE is active, our SL moves to entry_price
                current_sl = entry_price if be_active else entry_price - sl_pts

                if low_price <= current_sl:
                    outcome = "BREAK_EVEN" if be_active else "LOSS"
                    break
                elif high_price >= entry_price + tp_pts:
                    outcome = "WIN"
                    break
            elif signal == -1: # Short
                if low_price < max_favorable_price: max_favorable_price = low_price
                # Check BE Trigger
                if low_price <= entry_price - be_trigger_pts: be_active = True

                current_sl = entry_price if be_active else entry_price + sl_pts

                if high_price >= current_sl:
                    outcome = "BREAK_EVEN" if be_active else "LOSS"
                    break
                elif low_price <= entry_price - tp_pts:
                    outcome = "WIN"
                    break

        actual_mfe = 0.0
        if outcome != "LOSS" and outcome != "BREAK_EVEN":
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
        elif outcome == "BREAK_EVEN":
            break_evens += 1
            # Deficit is 0 for BE
        else:
            timeouts += 1
            total_potential_profit += actual_mfe

        if not stoch_allowed: stoch_filtered_trades += 1

    total_trades = wins + losses + timeouts + break_evens
    win_rate = (wins / total_trades * 100) if total_trades > 0 else 0.0

    print(f"Total Evaluated Trades: {total_trades}")
    print(f"  - 🟩 WINS (Hit TP {tp_pts}): {wins}")
    print(f"  - 🟦 BREAK-EVENS (Hit BE Trigger {be_trigger_pts} -> Stopped at Entry): {break_evens}")
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
    total_preds = len(merged_df)
    long_count = len(merged_df[merged_df['Signal'] == 1])
    short_count = len(merged_df[merged_df['Signal'] == -1])
    noise_count = len(merged_df[merged_df['Signal'] == 0])

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
    parser.add_argument('--plong', type=float, default=0.35)
    parser.add_argument('--pshort', type=float, default=0.36)
    parser.add_argument('--pnoise', type=float, default=0.47)
    parser.add_argument('--sl', type=float, default=1.5)
    parser.add_argument('--tp', type=float, default=1.5)
    parser.add_argument('--be', type=float, default=1.0)
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
        print(f"\n⚙️ Applying Custom Thresholds: Long={args.plong}, Short={args.pshort}, MaxNoise={args.pnoise}")

        # Calculate RAW signals purely based on Optuna thresholds (no stoch)
        cond_long_raw = (merged_df['P_Long'] > args.plong) & (merged_df['P_Noise'] < args.pnoise) & (merged_df['P_Long'] > merged_df['P_Short'])
        cond_short_raw = (merged_df['P_Short'] > args.pshort) & (merged_df['P_Noise'] < args.pnoise) & (merged_df['P_Short'] > merged_df['P_Long'])

        merged_df['Raw_Signal'] = 0
        merged_df.loc[cond_long_raw, 'Raw_Signal'] = 1
        merged_df.loc[cond_short_raw, 'Raw_Signal'] = -1

        # Calculate FILTERED signals (incorporating Stoch_K logic)
        # Note: Stoch_K is 0-1 scaled. 50 level = 0.50
        # Long allowed ONLY IF Stoch_K >= 0.50
        # Short allowed ONLY IF Stoch_K <= 0.50
        merged_df['Stoch_K'] = merged_df['Stoch_K'].fillna(0.5) # Default neutral if missing

        cond_long_filtered = cond_long_raw & (merged_df['Stoch_K'] >= 0.50)
        cond_short_filtered = cond_short_raw & (merged_df['Stoch_K'] <= 0.50)

        merged_df['Signal'] = 0
        merged_df.loc[cond_long_filtered, 'Signal'] = 1
        merged_df.loc[cond_short_filtered, 'Signal'] = -1

        # Display Statistics on RAW signals to calculate "Sacrificed Wins / Saved Losses" correctly
        # We need to temporarily set the 'Signal' column to RAW so evaluate_win_rate calculates MFE correctly
        merged_df_stats = merged_df.copy()
        merged_df_stats['Signal'] = merged_df_stats['Raw_Signal']
        generate_statistics(merged_df_stats, df_pred)
        evaluate_win_rate(merged_df_stats[merged_df_stats['Signal'] != 0].copy(), df_m1, tp_pts=args.tp, sl_pts=args.sl, be_trigger_pts=args.be)

        # Now pass the STRICTLY FILTERED dataframe to the visualizer
        active_filtered = merged_df[merged_df['Signal'] != 0].copy()

        longs_count = len(active_filtered[active_filtered['Signal'] == 1])
        shorts_count = len(active_filtered[active_filtered['Signal'] == -1])
        print(f"\n🖌️ Visualizing strictly Stoch-Filtered signals: {longs_count} Longs, {shorts_count} Shorts")

        generate_visualization(active_filtered, df_m1, df_pred, args.out, args.plong, args.pshort, args.pnoise)

if __name__ == "__main__":
    main()
