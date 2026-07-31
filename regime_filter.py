import pandas as pd
import numpy as np

def calculate_macro_regime(df, fast_period=20, slow_period=50):
    """
    Calculates a macro trend regime using EMA crossover logic on the Close prices.
    Returns +1 for Uptrend (Fast > Slow), -1 for Downtrend (Fast < Slow).
    """
    close_series = df['Close']

    # Calculate Exponential Moving Averages
    ema_fast = close_series.ewm(span=fast_period, adjust=False).mean()
    ema_slow = close_series.ewm(span=slow_period, adjust=False).mean()

    # Determine regime: 1 for uptrend, -1 for downtrend
    # We could introduce a buffer for 'Sideways' (0), e.g., if difference is < threshold
    regime = np.where(ema_fast > ema_slow, 1, -1)

    return pd.Series(regime, index=df.index)

def apply_hard_filter(probs_df, regime_series):
    """
    Applies the regime as a hard filter to the LightGBM probabilities/signals.
    If regime is +1 (Uptrend), short signals are neutralized (set to noise/hold).
    If regime is -1 (Downtrend), long signals are neutralized.
    """
    # Assuming probs_df has columns: P_Short (0), P_Noise (1), P_Long (2)
    # and a raw 'Signal' column (0=Short, 1=Noise, 2=Long)

    filtered_signal = probs_df['Signal'].copy()

    # Block shorts during uptrend
    filtered_signal = np.where((regime_series == 1) & (filtered_signal == 0), 1, filtered_signal)

    # Block longs during downtrend
    filtered_signal = np.where((regime_series == -1) & (filtered_signal == 2), 1, filtered_signal)

    return filtered_signal
