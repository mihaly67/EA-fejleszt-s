import pandas as pd
import plotly.graph_objects as go
import os
import argparse

def generate_chart(input_file, output_html, subset=100):
    print(f"Generating chart for dollar bars from {input_file}...")

    df = pd.read_csv(input_file)

    # Use only a subset to prevent massive file sizes and rendering issues
    df_subset = df.head(subset)

    # Determine colors based on Close vs Open
    # Erdőzöld: #228B22, Téglavörös: #B22222
    colors = ['#228B22' if row['Close'] >= row['Open'] else '#B22222' for _, row in df_subset.iterrows()]

    # To draw simple vertical lines for each bar, we can use a Scatter plot with error_y (or just line segments by interleaving NaNs).
    # Interleaved NaN method for rendering vertical lines from Low to High:
    x_lines = []
    y_lines = []
    line_colors = []

    for i, row in df_subset.iterrows():
        x_lines.extend([row['Start_Timestamp'], row['Start_Timestamp'], None])
        y_lines.extend([row['Low'], row['High'], None])
        line_colors.extend([colors[i]] * 3)

    # Note: Plotly scatter lines take a single color. To color individually, it's easier to use a bar chart or individual shapes.
    # A cleaner approach for OHLC lines without the "box" (candlestick) is go.Ohlc
    # But user specifically asked for "egyszerű függőleges vonalak" (simple vertical lines).

    fig = go.Figure()

    # Create green lines trace
    green_x = []
    green_y = []
    for i, row in df_subset.iterrows():
        if row['Close'] >= row['Open']:
            green_x.extend([row['Start_Timestamp'], row['Start_Timestamp'], None])
            green_y.extend([row['Low'], row['High'], None])

    fig.add_trace(go.Scatter(
        x=green_x,
        y=green_y,
        mode='lines',
        line=dict(color='#228B22', width=2),
        name='Bull Bar'
    ))

    # Create red lines trace
    red_x = []
    red_y = []
    for i, row in df_subset.iterrows():
        if row['Close'] < row['Open']:
            red_x.extend([row['Start_Timestamp'], row['Start_Timestamp'], None])
            red_y.extend([row['Low'], row['High'], None])

    fig.add_trace(go.Scatter(
        x=red_x,
        y=red_y,
        mode='lines',
        line=dict(color='#B22222', width=2),
        name='Bear Bar'
    ))

    fig.update_layout(title=f'Merkava ML-Ops: Prado Dollar Bars (First {subset})',
                      yaxis_title='Price',
                      xaxis_rangeslider_visible=False,
                      height=800,
                      width=1200,
                      plot_bgcolor='white')

    fig.update_xaxes(showgrid=True, gridwidth=1, gridcolor='lightgray')
    fig.update_yaxes(showgrid=True, gridwidth=1, gridcolor='lightgray')

    fig.write_html(output_html)
    print(f"Chart saved to {output_html}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/dollar_bars.csv', help='Path to the input dollar bars CSV')
    parser.add_argument('--output', default='/home/misi/Merkava_ML_Ops/data/processed/dollar_bars_chart_100.html', help='Path to output HTML')
    parser.add_argument('--subset', type=int, default=100, help='Number of rows to visualize')
    args = parser.parse_args()

    generate_chart(args.input_file, args.output, args.subset)
