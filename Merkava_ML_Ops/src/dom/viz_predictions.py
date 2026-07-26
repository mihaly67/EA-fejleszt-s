import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import argparse

def generate_visualization(input_file, output_html, hours=24):
    print(f"OOS Vizualizáció generálása ({hours} óra) ebből: {input_file}...")

    df = pd.read_csv(input_file)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])

    # Kiválasztjuk a fájl elejét (vagy megadott órányi ablakot)
    start_time = df['Start_Timestamp'].iloc[0]
    end_time = start_time + pd.Timedelta(hours=hours)
    df_subset = df[(df['Start_Timestamp'] >= start_time) & (df['Start_Timestamp'] <= end_time)].copy()

    print(f"Kiválasztott sorok száma a vizsga adathalmazban: {len(df_subset)}")

    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.05,
                        subplot_titles=('Prado Dollar Bars & ML Copilot Predikciók (OOS)', 'Copilot Valószínűségek (P_Long vs P_Short vs P_Noise)', 'Microstructure: Price Velocity'),
                        row_heights=[0.6, 0.2, 0.2])

    # 1. Dollar Bars
    colors = ['#228B22' if row['Close'] >= row['Open'] else '#B22222' for _, row in df_subset.iterrows()]

    for i, row in df_subset.iterrows():
        fig.add_trace(go.Scatter(
            x=[row['Start_Timestamp'], row['Start_Timestamp']],
            y=[row['Low'], row['High']],
            mode='lines',
            line=dict(color=colors[len(fig.data)], width=2),
            showlegend=False
        ), row=1, col=1)

    # Predikciók (A következő gyertya nyitójára rajzoljuk)
    df_subset['Next_Timestamp'] = df_subset['Start_Timestamp'].shift(-1)
    df_subset['Next_Open'] = df_subset['Open'].shift(-1)
    df_labels = df_subset.dropna(subset=['Next_Timestamp'])

    long_points = df_labels[df_labels['Copilot_Signal'] == 1]
    short_points = df_labels[df_labels['Copilot_Signal'] == -1]
    noise_points = df_labels[df_labels['Copilot_Signal'] == 0]

    fig.add_trace(go.Scatter(x=long_points['Next_Timestamp'], y=long_points['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-up', color='#00FF00', size=12, line=dict(color='white', width=1)),
                             name='Predicted Long (+1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=short_points['Next_Timestamp'], y=short_points['Next_Open'],
                             mode='markers', marker=dict(symbol='triangle-down', color='#FF00FF', size=12, line=dict(color='white', width=1)),
                             name='Predicted Short (-1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=noise_points['Next_Timestamp'], y=noise_points['Next_Open'],
                             mode='markers', marker=dict(symbol='x', color='gray', size=6),
                             name='Predicted Noise/Hold (0)'), row=1, col=1)


    # 2. Copilot Probabilities (A jövőbeli irányerősség)
    fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['P_Long'], line=dict(color='#00FF00', width=1), name='P(Long)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['P_Short'], line=dict(color='#FF00FF', width=1), name='P(Short)'), row=2, col=1)
    fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['P_Noise'], line=dict(color='gray', width=1, dash='dash'), name='P(Noise)'), row=2, col=1)

    # 3. Price Velocity (Mint input feature)
    if 'Price_Velocity' in df_subset.columns:
        fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['Price_Velocity'], fill='tozeroy', line=dict(color='#00FFFF', width=1), name='Price Velocity'), row=3, col=1)

    fig.update_layout(
        height=1000,
        width=1600,
        title_text=f"Merkava ML-Ops: ÉLES VIZSGA (Out-Of-Sample) Eredmények ({hours} Óra)",
        xaxis_rangeslider_visible=False,
        plot_bgcolor='#111111',
        paper_bgcolor='#000000',
        font=dict(color='white')
    )

    fig.update_xaxes(showgrid=True, gridwidth=1, gridcolor='#333333', type='date')
    fig.update_yaxes(showgrid=True, gridwidth=1, gridcolor='#333333')

    fig.write_html(output_html)
    print(f"Chart saved to {output_html}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/exam_predictions.csv')
    parser.add_argument('--output', default='/home/misi/Merkava_ML_Ops/data/processed/exam_decision_chart.html')
    parser.add_argument('--hours', type=int, default=24)
    args = parser.parse_args()

    generate_visualization(args.input_file, args.output, args.hours)
