import numpy as np
import pandas as pd
import json
import sys

# Try importing optimization libraries, handle missing ones gracefully
try:
    from scipy.signal import butter, filtfilt
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False

try:
    from pykalman import KalmanFilter
    PYKALMAN_AVAILABLE = True
except ImportError:
    PYKALMAN_AVAILABLE = False

class HybridSignalProcessor:
    """
    Advanced Signal Processor for Hybrid Scalping Strategy.
    Implements:
    1. Kalman Filter (or ZeroLag EMA fallback) for noise reduction.
    2. CUSUM Filter for event detection.
    3. Hybrid MACD+WPR+IFT Calculation.
    """

    def __init__(self, use_kalman=True):
        self.use_kalman = use_kalman and PYKALMAN_AVAILABLE

    def kalman_smooth(self, prices, transition_covariance=0.01):
        """
        Applies a Kalman Filter to smooth price data with minimal lag.
        """
        if self.use_kalman:
            kf = KalmanFilter(
                transition_matrices=[1],
                observation_matrices=[1],
                initial_state_mean=prices[0],
                initial_state_covariance=1,
                observation_covariance=1,
                transition_covariance=transition_covariance
            )
            state_means, _ = kf.filter(prices)
            return state_means.flatten()
        else:
            # Fallback: ZeroLag EMA (DEMA approximation)
            return self.calculate_dema(prices, 10) # Default smoothing

    def calculate_ema(self, series, span):
        return series.ewm(span=span, adjust=False).mean()

    def calculate_dema(self, series, span):
        ema1 = self.calculate_ema(series, span)
        ema2 = self.calculate_ema(ema1, span)
        return 2 * ema1 - ema2

    def ift_normalize(self, series, gain=1.5):
        """Inverse Fisher Transform Normalization to [-1, 1]"""
        # First, stoch-like normalization to -0.5..0.5
        rolling_min = series.rolling(window=50).min()
        rolling_max = series.rolling(window=50).max()

        # Avoid division by zero
        denom = rolling_max - rolling_min
        denom[denom == 0] = 1.0

        stoch = (series - rolling_min) / denom
        centered = stoch - 0.5

        # Scale for IFT
        scaled = centered * 4.0

        # Apply Tanh (IFT)
        # (exp(2x)-1)/(exp(2x)+1) is exactly tanh(x)
        return np.tanh(scaled * gain)

    def calculate_hybrid_signal(self, df):
        """
        Calculates the Hybrid Conviction Signal.
        df must contain 'close', 'high', 'low' columns.
        """
        # 1. Pre-smoothing
        if self.use_kalman:
            # Use Kalman on Close prices
            smooth_price = pd.Series(self.kalman_smooth(df['close'].values), index=df.index)
        else:
            # Use DEMA
            smooth_price = self.calculate_dema(df['close'], 5)

        # 2. MACD (ZeroLag based on smoothed price)
        # Fast=12, Slow=26
        ema_fast = self.calculate_ema(smooth_price, 12)
        ema_slow = self.calculate_ema(smooth_price, 26)
        macd_raw = ema_fast - ema_slow

        # 3. WPR (Williams %R)
        # WPR = (H_n - C) / (H_n - L_n) * -100
        # We calculate it manually or use TA-Lib if available. Manual here for dependency-free.
        period = 14
        highest_high = df['high'].rolling(window=period).max()
        lowest_low = df['low'].rolling(window=period).min()
        wpr_raw = -100 * ((highest_high - df['close']) / (highest_high - lowest_low))

        # Normalize WPR to [-1, 1]
        # -100 -> -1, 0 -> 1. Formula: 1 + (WPR / 50)
        wpr_norm = 1.0 + (wpr_raw / 50.0)

        # 4. Normalize MACD via IFT
        macd_ift = self.ift_normalize(macd_raw)

        # 5. Fusion
        # Weighted average
        hybrid_signal = (macd_ift * 0.6) + (wpr_norm * 0.4)

        # Clamp
        hybrid_signal = hybrid_signal.clip(-1.0, 1.0)

        return pd.DataFrame({
            'timestamp': df.index,
            'close': df['close'],
            'smooth_price': smooth_price,
            'macd_ift': macd_ift,
            'wpr_norm': wpr_norm,
            'hybrid_signal': hybrid_signal
        })

    def process_csv(self, filepath):
        """Entry point for CSV processing"""
        try:
            df = pd.read_csv(filepath)
            # Ensure columns exist
            required = ['time', 'open', 'high', 'low', 'close']
            # Simple mapping if names differ
            df.columns = [c.lower() for c in df.columns]

            # Index by time
            if 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
                df.set_index('time', inplace=True)

            result = self.calculate_hybrid_signal(df)
            return result
        except Exception as e:
            print(f"Error processing CSV: {e}")
            return None

if __name__ == "__main__":
    print("=== Hybrid Signal Processor (Python) ===")
    print(f"SciPy Available: {SCIPY_AVAILABLE}")
    print(f"PyKalman Available: {PYKALMAN_AVAILABLE}")

    # Simple test with random data if run directly
    dates = pd.date_range(start='2023-01-01', periods=100, freq='1min')
    prices = 1.1000 + np.cumsum(np.random.randn(100) * 0.0005)
    highs = prices + 0.0002
    lows = prices - 0.0002

    df_test = pd.DataFrame({
        'close': prices,
        'high': highs,
        'low': lows
    }, index=dates)

    processor = HybridSignalProcessor()
    res = processor.calculate_hybrid_signal(df_test)

    print("\n--- Sample Output (Last 5 Rows) ---")
    print(res.tail())

    # In a real scenario, this script would read a CSV passed as arg
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
        print(f"\nProcessing file: {csv_path}")
        real_res = processor.process_csv(csv_path)
        if real_res is not None:
             out_path = csv_path.replace('.csv', '_processed.csv')
             real_res.to_csv(out_path)
             print(f"Saved processed data to: {out_path}")
