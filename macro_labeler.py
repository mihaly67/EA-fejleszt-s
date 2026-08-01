import pandas as pd
import numpy as np

def label_macro_regime(df, lookahead=10, trend_threshold=0.001):
    """
    Labels the macro regime based on the forward-looking structural trend.
    +1 = Uptrend
    -1 = Downtrend
     0 = Range/Sideways

    We use the return over the next 'lookahead' bars. If the return is > threshold, it's an uptrend.
    """
    print(f"Labeler: Generating Macro Regime Labels (Lookahead={lookahead}, Threshold={trend_threshold})")
    df = df.copy()

    # Calculate future return over the lookahead window
    df['Future_Return'] = (df['Close'].shift(-lookahead) - df['Close']) / df['Close']

    # Define conditions
    conditions = [
        (df['Future_Return'] > trend_threshold),
        (df['Future_Return'] < -trend_threshold)
    ]
    choices = [1, -1]

    # Default is 0 (Range/Sideways)
    df['Macro_Label'] = np.select(conditions, choices, default=0)

    # Drop rows where we couldn't calculate future returns (end of dataset)
    df.dropna(subset=['Future_Return'], inplace=True)
    df.drop(columns=['Future_Return'], inplace=True)

    return df
