import pandas as pd
import numpy as np

def create_dollar_bars(filepath, threshold=444000, output_path=None):
    print(f"⏳ Generating Dollar Bars (Threshold=${threshold:,.2f}) from: {filepath}")

    df = pd.read_csv(filepath)
    df['Mid_Price'] = (df['Bid'] + df['Ask']) / 2
    df['Total_Trade_Vol'] = df['Bid_Volume'] + df['Ask_Volume']
    df['Dollar_Value'] = df['Total_Trade_Vol'] * df['Mid_Price']

    bars = []
    current_dollar_val = 0.0
    current_bar = {}

    for idx, row in df.iterrows():
        d_val = row['Dollar_Value']
        if d_val == 0:
            continue

        if current_dollar_val == 0.0:
            current_bar = {
                'Start_Timestamp': row['Timestamp'],
                'Open': row['Mid_Price'],
                'High': row['Mid_Price'],
                'Low': row['Mid_Price'],
                'Bid_Volume': 0,
                'Ask_Volume': 0,
                'Total_Volume': 0,
                'Total_Dollar_Value': 0.0
            }

        current_dollar_val += d_val
        current_bar['Bid_Volume'] += row['Bid_Volume']
        current_bar['Ask_Volume'] += row['Ask_Volume']
        current_bar['Total_Volume'] += row['Total_Trade_Vol']
        current_bar['Total_Dollar_Value'] += d_val

        if row['Mid_Price'] > current_bar['High']: current_bar['High'] = row['Mid_Price']
        if row['Mid_Price'] < current_bar['Low']: current_bar['Low'] = row['Mid_Price']

        if current_dollar_val >= threshold:
            current_bar['End_Timestamp'] = row['Timestamp']
            current_bar['Close'] = row['Mid_Price']

            # Forward filled MTF features attached to the end of the bar
            current_bar['1m_Close'] = row['1m_Close']
            current_bar['5m_Close'] = row['5m_Close']
            current_bar['15m_Close'] = row['15m_Close']

            bars.append(current_bar)
            current_dollar_val = 0.0

    bars_df = pd.DataFrame(bars)

    print(f"✅ Generated {len(bars_df)} Dollar Bars.")

    if output_path:
        bars_df.to_csv(output_path, index=False)
        print(f"💾 Saved to {output_path}")

    return bars_df

if __name__ == '__main__':
    import sys
    import os

    input_csv = '/home/misi/Merkava_ML_Ops/data/Merkava_MTF_GCE_Data.csv'
    if len(sys.argv) > 1:
        input_csv = sys.argv[1]

    out_dir = os.path.join(os.path.dirname(input_csv), 'processed')
    os.makedirs(out_dir, exist_ok=True)
    out_csv = os.path.join(out_dir, 'dollar_bars.csv')

    create_dollar_bars(input_csv, threshold=444000, output_path=out_csv)
