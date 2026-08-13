import pandas as pd
import numpy as np
import optuna
import warnings
warnings.filterwarnings('ignore')

def load_data(pred_file, m1_file):
    df_raw = pd.read_csv(m1_file, on_bad_lines='skip')
    df_raw['Datetime'] = pd.to_datetime(df_raw['Time'], format='mixed', errors='coerce')
    df_raw = df_raw.dropna(subset=['Datetime']).sort_values('Datetime')
    df_raw['Mid'] = (df_raw['Bid'] + df_raw['Ask']) / 2.0

    df_raw.set_index('Datetime', inplace=True)
    df_m1 = df_raw['Mid'].resample('1min').ohlc()

    if 'Stoch_K' in df_raw.columns:
        stoch_series = df_raw['Stoch_K'].resample('1min').last() / 100.0
        df_m1['Stoch_K'] = stoch_series

    df_m1.dropna(inplace=True)
    df_m1.reset_index(inplace=True)
    df_m1['Datetime'] = pd.to_datetime(df_m1['Datetime']).astype('datetime64[us]')
    df_m1.rename(columns={'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close'}, inplace=True)

    df_pred = pd.read_csv(pred_file)
    df_pred['Datetime'] = pd.to_datetime(df_pred['ServerTime'], format='mixed', errors='coerce').astype('datetime64[us]')
    df_pred = df_pred.dropna(subset=['Datetime']).sort_values('Datetime').reset_index(drop=True)

    return df_m1, df_pred

def simulate_trades(df_pred, df_m1, p_long_min, p_short_min, p_noise_max_long, p_noise_max_short, use_stoch, tp_pts=1.5, sl_pts=1.0, max_bars=5):
    wins = 0
    losses = 0
    timeouts = 0
    total_potential_profit = 0.0
    total_deficit = 0.0

    for index, row in df_pred.iterrows():
        p_long = row['P_Long']
        p_short = row['P_Short']
        p_noise = row['P_Noise']
        entry_time = row['Datetime']

        signal = 0
        if p_long > p_long_min and p_noise < p_noise_max_long and p_long > p_short:
            signal = 1
        elif p_short > p_short_min and p_noise < p_noise_max_short and p_short > p_long:
            signal = -1

        if signal == 0: continue

        m1_start_idx = df_m1['Datetime'].searchsorted(entry_time, side='right') - 1
        if m1_start_idx < 0: m1_start_idx = 0

        # Stoch Filter
        stoch_k = df_m1.iloc[m1_start_idx].get('Stoch_K', 0.5)
        if use_stoch:
            if signal == 1 and stoch_k < 0.50: continue
            if signal == -1 and stoch_k > 0.50: continue

        # Simulate Trade
        # To get the exact entry price without merging beforehand, we just use the Close of the aligned M1 bar
        entry_price = df_m1.iloc[m1_start_idx]['Close']
        outcome = "TIMEOUT"
        max_favorable_price = entry_price

        for i in range(1, max_bars + 1):
            if m1_start_idx + i >= len(df_m1): break
            future_bar = df_m1.iloc[m1_start_idx + i]
            high_price = future_bar['High']
            low_price = future_bar['Low']

            if signal == 1:
                if high_price > max_favorable_price: max_favorable_price = high_price
                if low_price <= entry_price - sl_pts:
                    outcome = "LOSS"
                    break
                elif high_price >= entry_price + tp_pts:
                    outcome = "WIN"
            elif signal == -1:
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
        elif outcome == "LOSS":
            losses += 1
            total_deficit += sl_pts
        else:
            timeouts += 1
            total_potential_profit += actual_mfe

    total_trades = wins + losses + timeouts
    net_potential = total_potential_profit - total_deficit
    return net_potential, total_trades, wins, losses

class ReplayTuner:
    def __init__(self, pred_file, m1_file, use_stoch=True):
        self.df_m1, self.df_pred = load_data(pred_file, m1_file)
        self.use_stoch = use_stoch

    def objective(self, trial):
        p_long_min = trial.suggest_float('p_long_min', 0.35, 0.65)
        p_short_min = trial.suggest_float('p_short_min', 0.35, 0.65)
        p_noise_max_long = trial.suggest_float('p_noise_max_long', 0.25, 0.55)
        p_noise_max_short = trial.suggest_float('p_noise_max_short', 0.25, 0.55)

        net_potential, total_trades, wins, losses = simulate_trades(
            self.df_pred, self.df_m1,
            p_long_min, p_short_min, p_noise_max_long, p_noise_max_short,
            self.use_stoch
        )

        # Penalize if too few trades (we want an active scalper, e.g., minimum 5 trades per session)
        if total_trades < 5:
            return -9999.0

        return net_potential

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--pred', required=True)
    parser.add_argument('--m1', required=True)
    parser.add_argument('--stoch', action='store_true', default=True)
    parser.add_argument('--no-stoch', dest='stoch', action='store_false')
    parser.add_argument('--trials', type=int, default=100)
    args = parser.parse_args()

    tuner = ReplayTuner(args.pred, args.m1, args.stoch)

    study = optuna.create_study(direction='maximize')
    study.optimize(tuner.objective, n_trials=args.trials)

    print("\n✅ OPTIMIZATION COMPLETE")
    print(f"Stoch Filter Enforced: {args.stoch}")
    print(f"Best Net MFE Profit: {study.best_value:.2f} points")
    print("Best Threshold Parameters:")
    for k, v in study.best_params.items():
        print(f"  {k}: {v:.4f}")

    # Re-run best to show exact stats
    bp = study.best_params
    net_p, tt, w, l = simulate_trades(tuner.df_pred, tuner.df_m1, bp['p_long_min'], bp['p_short_min'], bp['p_noise_max_long'], bp['p_noise_max_short'], args.stoch)
    print(f"\nStats for Best Trial -> Total Trades: {tt}, Wins: {w}, Losses: {l} (Win Rate: {w/tt*100:.2f}%)")
