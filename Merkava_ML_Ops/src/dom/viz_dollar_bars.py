import pandas as pd
import plotly.graph_objects as go
import os
import argparse

def generate_chart(input_file, output_html, subset=10):
    print(f"Generating chart for dollar bars from {input_file}...")

    df = pd.read_csv(input_file)

    # Használjuk csak az első 'subset' (pl. 10) gyertyát
    df_subset = df.head(subset)

    fig = go.Figure(data=[go.Candlestick(x=df_subset['Start_Timestamp'],
                    open=df_subset['Open'],
                    high=df_subset['High'],
                    low=df_subset['Low'],
                    close=df_subset['Close'])])

    fig.update_layout(title=f'Merkava ML-Ops: Prado Dollar Bars (First {subset})',
                      yaxis_title='Price',
                      xaxis_rangeslider_visible=False,
                      height=800,
                      width=1200)

    fig.write_html(output_html)
    print(f"Chart saved to {output_html}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv', help='Path to the input dollar bars CSV')
    parser.add_argument('--output', default='/home/misi/Merkava_ML_Ops/data/processed/dollar_bars_chart_10.html', help='Path to output HTML')
    parser.add_argument('--subset', type=int, default=10, help='Number of rows to visualize')
    args = parser.parse_args()

    generate_chart(args.input_file, args.output, args.subset)
