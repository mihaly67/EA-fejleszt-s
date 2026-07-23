import pandas as pd
import numpy as np
import lightgbm as lgb
import os
import sys

def generate_meta_features(data_path, model_path, output_path):
    print(f"🔄 Meta-Feature Generálás Indítása...")
    print(f"Alap-Adat: {data_path}")
    print(f"Alap-Modell (LightGBM): {model_path}")

    df = pd.read_csv(data_path).dropna()

    base_features = [
        'OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_1m', 'Dist_5m', 'Dist_15m', 'ATR_Proxy',
        'Micro_RSI_14', 'Micro_MACD_Hist', 'Micro_BB_ZScore',
        'M15_RSI_14', 'M15_MACD_Hist', 'M15_BB_ZScore'
    ]

    X = df[base_features].values

    # 1. Alap-Modell Betöltése és Predikció
    bst = lgb.Booster(model_file=model_path)
    probs = bst.predict(X)

    # Valószínűségek kimentése (Az osztályok: 0: Short, 1: Zaj, 2: Long)
    df['P_Short'] = probs[:, 0]
    df['P_Noise'] = probs[:, 1]
    df['P_Long'] = probs[:, 2]

    # 2. Meta-Feature-ök Kiszámítása
    print("🧠 Matematikai Deriváltak számítása a Valószínűségekből...")

    # Irányított Erő (-1.0 és 1.0 között)
    df['P_Diff'] = df['P_Long'] - df['P_Short']

    # Sebesség (Első derivált - Milyen gyorsan változik az erő?)
    df['P_Velocity'] = df['P_Diff'].diff(1).fillna(0)

    # Gyorsulás (Második derivált - Növekszik vagy lassul a momentum?)
    df['P_Acceleration'] = df['P_Velocity'].diff(1).fillna(0)

    # Momentum Kimerülés (Divergencia proxy)
    # Ha a valószínűség nagyon magas (pl. P_Long > 0.8), de a gyorsulás már negatív
    df['P_Exhaustion'] = np.where((df['P_Long'] > 0.7) & (df['P_Acceleration'] < 0), 1,
                         np.where((df['P_Short'] > 0.7) & (df['P_Acceleration'] > 0), -1, 0))

    # (A Data Leakage elkerülése itt kevésbé releváns a diff() miatt az értékelésnél,
    # de a tanításhoz a múltbéli értékek kellenek. Mivel a P_Diff a KÉSZ bar adataiból számolódik ki,
    # a következő gyertya nyitásakor már rendelkezésre áll. Az egyszerűség kedvéért mi most mindent
    # a "lezárt" barokhoz rendelünk hozzá.)

    print(f"💾 Meta-Adathalmaz Mentése: {output_path} ({len(df)} sor)")
    df.to_csv(output_path, index=False)

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    model_path = '/home/misi/Merkava_ML_Ops/models/lgbm_copilot_model.txt'
    output_path = '/home/misi/Merkava_ML_Ops/data/processed/meta_features_dollar_bars.csv'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    generate_meta_features(data_path, model_path, output_path)
