import pandas as pd
import numpy as np

def label_macro_regime(df, lookahead=4, atr_multiplier=1.0):
    """
    Labels the macro regime using a Dynamic ATR-based threshold.
    +1 = Uptrend (Future price moves UP by at least atr_multiplier * ATR)
    -1 = Downtrend (Future price moves DOWN by at least atr_multiplier * ATR)
     0 = Range/Sideways (Future price remains within the ATR band)
    """
    print(f"Labeler: Generating Dynamic ATR Macro Regime Labels (Lookahead={lookahead}, ATR Mult={atr_multiplier})")
    df = df.copy()

    # Absolute dollar movement in the future
    df['Future_Move'] = df['Close'].shift(-lookahead) - df['Close']

    # The dynamic threshold is the local ATR multiplied by our factor
    df['Dynamic_Threshold'] = df['ATR_14'] * atr_multiplier

    # Conditions
    conditions = [
        (df['Future_Move'] > df['Dynamic_Threshold']),
        (df['Future_Move'] < -df['Dynamic_Threshold'])
    ]
    choices = [1, -1]

    # Default is 0 (Range/Sideways)
    df['Macro_Label'] = np.select(conditions, choices, default=0)

    # Drop rows where we couldn't calculate future returns (end of dataset)
    df.dropna(subset=['Future_Move'], inplace=True)
    df.drop(columns=['Future_Move', 'Dynamic_Threshold'], inplace=True)

    return df
