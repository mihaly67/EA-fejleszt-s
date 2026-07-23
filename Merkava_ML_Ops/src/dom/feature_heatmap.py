import pandas as pd
import numpy as np
import os
import sys
import plotly.express as px

def generate_heatmap(data_path, output_dir):
    print(f"🔄 Betöltés a Heatmap generáláshoz: {data_path}")

    # Megpróbáljuk betölteni a 'labeled_dollar_bars.csv'-t, hogy a Target_Label is benne legyen.
    # Ha ez a fájl nem létezik (mert még nem futott le a labeler az új feature-ökre),
    # akkor csak a feature_dollar_bars.csv-t elemezzük a feature-ök egymás közötti korrelációjára.
    df = pd.read_csv(data_path).dropna()

    features = [
        'OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_1m', 'Dist_5m', 'Dist_15m', 'ATR_Proxy',
        'Micro_RSI_14', 'Micro_MACD_Hist', 'Micro_BB_ZScore',
        'M15_RSI_14', 'M15_MACD_Hist', 'M15_BB_ZScore'
    ]

    if 'Target_Label' in df.columns:
        features.append('Target_Label')

    df_features = df[features]

    print("🧮 Pearson Korrelációs Mátrix számítása...")
    corr_matrix = df_features.corr(method='pearson')

    print("📈 Plotly HTML generálása...")
    fig = px.imshow(
        corr_matrix,
        text_auto=".2f",
        aspect="auto",
        color_continuous_scale='RdBu_r',
        title="ML Feature Correlation Heatmap (Micro vs Macro)"
    )

    html_path = os.path.join(output_dir, 'feature_heatmap.html')
    fig.write_html(html_path)
    print(f"💾 Heatmap HTML elmentve: {html_path}")

    # Próbáljuk meg PNG-ként is elmenteni kaleido-val
    try:
        png_path = os.path.join(output_dir, 'feature_heatmap.png')
        fig.write_image(png_path, width=1200, height=800)
        print(f"💾 Heatmap PNG elmentve: {png_path}")
    except Exception as e:
        print(f"⚠️ Nem sikerült PNG formátumban menteni (kaleido hiányzik?): {e}")

if __name__ == '__main__':
    # Alapértelmezésben a már felcímkézett adathalmazt keressük, hogy a Target korreláció is benne legyen.
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    output_dir = os.path.dirname(data_path)
    generate_heatmap(data_path, output_dir)
