import pandas as pd
import numpy as np

def calculate_kama(close_series, period=10, fast_ema=2, slow_ema=30):
    """
    Kaufman's Adaptive Moving Average (KAMA / AMA) Python Implementation.
    Mathematically identical to the MT5 iAMA.
    """
    # 1. Efficiency Ratio (ER)
    # Direction = abs(Close - Close[n])
    direction = close_series.diff(period).abs()
    # Volatility = sum(abs(Close - Close[1])) over n periods
    volatility = close_series.diff(1).abs().rolling(window=period).sum()

    # Avoid division by zero
    er = direction / (volatility + 1e-8)

    # 2. Smoothing Constant (SC)
    fast_alpha = 2.0 / (fast_ema + 1)
    slow_alpha = 2.0 / (slow_ema + 1)

    # Scaled Smoothing Constant (SSC)
    ssc = er * (fast_alpha - slow_alpha) + slow_alpha

    # Final Smoothing Constant
    sc = ssc ** 2

    # 3. KAMA Calculation
    kama = np.zeros_like(close_series)
    # Warmup
    kama[:period] = close_series[:period]

    # Pandas iterrows is slow, we use a numpy loop for the recursive KAMA calculation
    close_vals = close_series.values
    sc_vals = sc.values

    for i in range(period, len(close_vals)):
        kama[i] = kama[i-1] + sc_vals[i] * (close_vals[i] - kama[i-1])

    return pd.Series(kama, index=close_series.index)
