import pandas as pd
import numpy as np
import ta

def process_macro_features(df):
    """
    Ingests the Master ZigZag M1 CSV and computes ATR-normalized geometric distances
    from the current price to the exact ZigZag Pivot Support/Resistance levels.
    """
    print("Engineer: Generating ZigZag-Driven Geometric Features...")
    df = df.copy()

    if 'Time' in df.columns:
        df['Time'] = pd.to_datetime(df['Time'])
        df.sort_values('Time', inplace=True)

    df['ATR_14'] = ta.volatility.AverageTrueRange(high=df['High'], low=df['Low'], close=df['Close'], window=14).average_true_range()

    # Calculate Distances to the MQL5 ZigZag Pivots, normalized by ATR
    # Positive distance means price is below resistance (or above support)
    df['Dist_Micro_R'] = (df['Micro_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Micro_S'] = (df['Close'] - df['Micro_S']) / (df['ATR_14'] + 1e-8)

    df['Dist_Sec_R'] = (df['Sec_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Sec_S'] = (df['Close'] - df['Sec_S']) / (df['ATR_14'] + 1e-8)

    df['Dist_Ter_R'] = (df['Ter_R'] - df['Close']) / (df['ATR_14'] + 1e-8)
    df['Dist_Ter_S'] = (df['Close'] - df['Ter_S']) / (df['ATR_14'] + 1e-8)

    # ---------------------------------------------------------
    # Momentum confirmation: Ultra-fast Stochastic
    # ---------------------------------------------------------
    stoch_m1 = ta.momentum.StochasticOscillator(high=df['High'], low=df['Low'], close=df['Close'], window=2, smooth_window=3)
    df['Stoch_State_M1'] = (stoch_m1.stoch() - 50.0) / 50.0

    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.dropna(inplace=True)

    return df
