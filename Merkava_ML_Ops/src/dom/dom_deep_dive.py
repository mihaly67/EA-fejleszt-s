import pandas as pd
import numpy as np

def detect_spoofing(df, lookback=5):
    # Spoofing: Huge volume appears then disappears without trade execution (price hasn't moved through it)
    df['Ask_V1_Rolling_Max'] = df.get('Ask_Vol_1', df.get('AskV1', pd.Series(dtype=float))).rolling(lookback).max()
    df['Bid_V1_Rolling_Max'] = df.get('Bid_Vol_1', df.get('BidV1', pd.Series(dtype=float))).rolling(lookback).max()

    # Sudden drop > 50%
    df['Ask_Spoof'] = (df.get('Ask_Vol_1', df.get('AskV1', pd.Series(dtype=float))) < df['Ask_V1_Rolling_Max'] * 0.5) & (df.get('Ask', df.get('BestAsk', pd.Series(dtype=float))) == df.get('Ask', df.get('BestAsk', pd.Series(dtype=float))).shift(1))
    df['Bid_Spoof'] = (df.get('Bid_Vol_1', df.get('BidV1', pd.Series(dtype=float))) < df['Bid_V1_Rolling_Max'] * 0.5) & (df.get('Bid', df.get('BestBid', pd.Series(dtype=float))) == df.get('Bid', df.get('BestBid', pd.Series(dtype=float))).shift(1))

    return df['Ask_Spoof'].sum(), df['Bid_Spoof'].sum()

import sys
f = sys.argv[1] if len(sys.argv) > 1 else 'DOM_Data.csv'
if True:
    print(f"\\nFájl: {f}")
    try:
        df = pd.read_csv(f)
    except Exception:
        print(f'Nincs ilyen fájl: {f}')
        sys.exit(1)

    ask_s, bid_s = detect_spoofing(df)
    print(f"Detektált Ask Spoof gyanús tickek: {ask_s} ({ask_s/len(df)*100:.1f}%)")
    print(f"Detektált Bid Spoof gyanús tickek: {bid_s} ({bid_s/len(df)*100:.1f}%)")

    df['Spread_Tick'] = df.get('Ask', df.get('BestAsk', pd.Series(dtype=float))) - df.get('Bid', df.get('BestBid', pd.Series(dtype=float)))
    print(f"Átlagos Spread: {df['Spread_Tick'].mean():.5f}")
