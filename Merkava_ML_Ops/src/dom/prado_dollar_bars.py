import pandas as pd
import numpy as np

def create_dollar_bars_from_ticks(filepath, tick_bar_size=10, dollar_threshold=444000, output_path=None):
    """
    Marcos Lopez de Prado's methodology:
    1. Group raw ticks into 'Tick Bars' (e.g., 10 ticks per bar) to remove time dependency.
    2. Construct 'Dollar Bars' from these Tick Bars based on a dollar threshold.
    """
    print(f"⏳ Generating Dollar Bars (Tick Size={tick_bar_size}, Threshold=${dollar_threshold:,.2f}) from: {filepath}")

    # 1. Read Raw Tick Data (assuming the input CSV has tick-level resolution)
    df = pd.read_csv(filepath)

    # 2. Basic tick calculations
    df['Mid_Price'] = (df['Bid'] + df['Ask']) / 2
    df['Total_Trade_Vol'] = df['Bid_Volume'] + df['Ask_Volume']
    df['Dollar_Value'] = df['Total_Trade_Vol'] * df['Mid_Price']

    # Ensure sequential index for tick grouping
    df = df.reset_index(drop=True)

    # 3. Create Tick Bars (Grouping every N ticks)
    # Using integer division on the index to create group IDs
    df['Tick_Group'] = df.index // tick_bar_size

    # Aggregate ticks into Tick Bars
    tick_bars = df.groupby('Tick_Group').agg(
        Timestamp=('Timestamp', 'last'), # Keep the timestamp of the last tick in the bar
        Open=('Mid_Price', 'first'),
        High=('Mid_Price', 'max'),
        Low=('Mid_Price', 'min'),
        Close=('Mid_Price', 'last'),
        Bid_Volume=('Bid_Volume', 'sum'),
        Ask_Volume=('Ask_Volume', 'sum'),
        Total_Volume=('Total_Trade_Vol', 'sum'),
        Total_Dollar_Value=('Dollar_Value', 'sum'),
        # Assuming MTF features are forward-filled per tick, we take the last value for the bar
        Close_5m=('5m_Close', 'last') if '5m_Close' in df.columns else ('Mid_Price', 'last'),
        Close_15m=('15m_Close', 'last') if '15m_Close' in df.columns else ('Mid_Price', 'last'),
        Close_30m=('30m_Close', 'last') if '30m_Close' in df.columns else ('Mid_Price', 'last')
    ).reset_index(drop=True)

    print(f"✅ Generated {len(tick_bars)} intermediate Tick Bars.")

    # 4. Construct Dollar Bars from Tick Bars
    bars = []
    current_dollar_val = 0.0
    current_bar = {}

    for idx, row in tick_bars.iterrows():
        d_val = row['Total_Dollar_Value']
        if d_val == 0 and current_dollar_val == 0:
            continue

        if current_dollar_val == 0.0:
            current_bar = {
                'Start_Timestamp': row['Timestamp'],
                'Open': row['Open'],
                'High': row['High'],
                'Low': row['Low'],
                'Bid_Volume': 0,
                'Ask_Volume': 0,
                'Total_Volume': 0,
                'Total_Dollar_Value': 0.0
            }

        current_dollar_val += d_val
        current_bar['Bid_Volume'] += row['Bid_Volume']
        current_bar['Ask_Volume'] += row['Ask_Volume']
        current_bar['Total_Volume'] += row['Total_Volume']
        current_bar['Total_Dollar_Value'] += d_val

        if row['High'] > current_bar['High']: current_bar['High'] = row['High']
        if row['Low'] < current_bar['Low']: current_bar['Low'] = row['Low']

        if current_dollar_val >= dollar_threshold:
            current_bar['End_Timestamp'] = row['Timestamp']
            current_bar['Close'] = row['Close']

            # Attach MTF features
            current_bar['5m_Close'] = row['Close_5m']
            current_bar['15m_Close'] = row['Close_15m']
            current_bar['30m_Close'] = row['Close_30m']

            bars.append(current_bar)
            current_dollar_val = 0.0

    bars_df = pd.DataFrame(bars)

    print(f"✅ Generated {len(bars_df)} Final Dollar Bars.")

    if output_path:
        bars_df.to_csv(output_path, index=False)
        print(f"💾 Saved to {output_path}")

    return bars_df

if __name__ == '__main__':
    import sys
    import os
    import argparse

    parser = argparse.ArgumentParser(description="Generate Marcos Lopez de Prado Dollar Bars from Tick Data")
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/Merkava_MTF_GCE_Data.csv')
    parser.add_argument('--threshold', type=float, default=444000, help="Dollar value threshold per bar")
    parser.add_argument('--tick_size', type=int, default=10, help="Number of ticks to form an intermediate Tick Bar")
    args = parser.parse_args()

    out_dir = os.path.join(os.path.dirname(args.input_file), 'processed')
    os.makedirs(out_dir, exist_ok=True)
    out_csv = os.path.join(out_dir, 'dollar_bars.csv')

    create_dollar_bars_from_ticks(args.input_file, tick_bar_size=args.tick_size, dollar_threshold=args.threshold, output_path=out_csv)
