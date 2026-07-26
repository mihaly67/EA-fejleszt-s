import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import os
import argparse

def generate_visualization(input_file, output_html, hours=24):
    print(f"Vizualizáció generálása ({hours} óra) ebből: {input_file}...")

    df = pd.read_csv(input_file)
    df['Start_Timestamp'] = pd.to_datetime(df['Start_Timestamp'])

    # Kiválasztjuk a DataFrame közepéről a megadott órányi ablakot (hogy biztos legyen benne aktív piac)
    mid_idx = len(df) // 2
    mid_time = df.loc[mid_idx, 'Start_Timestamp']

    start_time = mid_time - pd.Timedelta(hours=hours/2)
    end_time = mid_time + pd.Timedelta(hours=hours/2)

    df_subset = df[(df['Start_Timestamp'] >= start_time) & (df['Start_Timestamp'] <= end_time)].copy()

    if len(df_subset) == 0:
        print("Nem található adat a megadott időablakban. Próbálkozom a fájl elejével.")
        start_time = df['Start_Timestamp'].iloc[0]
        end_time = start_time + pd.Timedelta(hours=hours)
        df_subset = df[(df['Start_Timestamp'] >= start_time) & (df['Start_Timestamp'] <= end_time)].copy()

    print(f"Kiválasztott sorok száma a {hours} órás ablakban: {len(df_subset)}")

    fig = make_subplots(rows=3, cols=1, shared_xaxes=True,
                        vertical_spacing=0.05,
                        subplot_titles=('Prado Dollar Bars & Aszimmetrikus Címkék (1.5R/1.0R)', 'Microstructure: OBI Z-Score', 'Price Velocity'),
                        row_heights=[0.6, 0.2, 0.2])

    # 1. Dollar Bars
    # Referencia színek és sötét mód a korábbi HTML és a kérés alapján
    colors = ['#228B22' if row['Close'] >= row['Open'] else '#B22222' for _, row in df_subset.iterrows()]

    # Függőleges vonalak generálása Scatter-el
    for i, row in df_subset.iterrows():
        fig.add_trace(go.Scatter(
            x=[row['Start_Timestamp'], row['Start_Timestamp']],
            y=[row['Low'], row['High']],
            mode='lines',
            line=dict(color=colors[len(fig.data)], width=2),
            showlegend=False
        ), row=1, col=1)

    # MTF Makro Trend (pl. 15 perces záróár)
    if '15m_Close' in df_subset.columns:
        fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['15m_Close'], line=dict(color='#FFA500', width=2), name='15m Close (Makro)'), row=1, col=1)

    # Címkék (Labels)
    long_points = df_subset[df_subset['Target_Label'] == 1]
    short_points = df_subset[df_subset['Target_Label'] == -1]
    noise_points = df_subset[df_subset['Target_Label'] == 0]

    # Jól látható rikító markerek a sötét háttéren
    fig.add_trace(go.Scatter(x=long_points['Start_Timestamp'], y=long_points['Close'],
                             mode='markers', marker=dict(symbol='triangle-up', color='#00FF00', size=10, line=dict(color='white', width=1)),
                             name='Long (+1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=short_points['Start_Timestamp'], y=short_points['Close'],
                             mode='markers', marker=dict(symbol='triangle-down', color='#FF00FF', size=10, line=dict(color='white', width=1)),
                             name='Short (-1)'), row=1, col=1)

    fig.add_trace(go.Scatter(x=noise_points['Start_Timestamp'], y=noise_points['Close'],
                             mode='markers', marker=dict(symbol='x', color='gray', size=6),
                             name='Zaj (0)'), row=1, col=1)

    # 2. OBI Z-Score
    if 'OBI_ZScore' in df_subset.columns:
        obi_colors = ['#228B22' if val >= 0 else '#B22222' for val in df_subset['OBI_ZScore']]
        fig.add_trace(go.Bar(x=df_subset['Start_Timestamp'], y=df_subset['OBI_ZScore'], marker_color=obi_colors, name='OBI Z-Score', showlegend=False), row=2, col=1)

    # 3. Price Velocity
    if 'Price_Velocity' in df_subset.columns:
        fig.add_trace(go.Scatter(x=df_subset['Start_Timestamp'], y=df_subset['Price_Velocity'], fill='tozeroy', line=dict(color='#00FFFF', width=1), name='Price Velocity'), row=3, col=1)

    # Fekete háttér és dizájn frissítés (Referencia HTML alapján)
    fig.update_layout(
        height=1000,
        width=1600,
        title_text=f"Merkava ML-Ops: Feature & Címke Elemzés ({hours} Óra)",
        xaxis_rangeslider_visible=False,
        plot_bgcolor='#111111', # Sötétszürke/fekete rajzterület
        paper_bgcolor='#000000', # Fekete teljes háttér
        font=dict(color='white')  # Fehér betűk
    )

    # Rácsvonalak halványítása a fekete háttéren
    fig.update_xaxes(showgrid=True, gridwidth=1, gridcolor='#333333', type='date')
    fig.update_yaxes(showgrid=True, gridwidth=1, gridcolor='#333333')

    fig.write_html(output_html)
    print(f"Chart saved to {output_html}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_file', nargs='?', default='/home/misi/Merkava_ML_Ops/data/processed/labeled_train_features_dollar_bars.csv')
    parser.add_argument('--output', default='/home/misi/Merkava_ML_Ops/data/processed/feature_label_chart_dark.html')
    parser.add_argument('--hours', type=int, default=24)
    args = parser.parse_args()

    generate_visualization(args.input_file, args.output, args.hours)
