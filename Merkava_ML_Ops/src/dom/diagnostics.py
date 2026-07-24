import pandas as pd
import numpy as np
import lightgbm as lgb
import os
import sys

def run_diagnostics(train_path, exam_path, model_path):
    print("="*50)
    print("🔍 DIAGNOSZTIKA: TANÍTÓ VS VIZSGA ADAT")
    print("="*50)

    df_train = pd.read_csv(train_path).dropna()
    df_exam = pd.read_csv(exam_path).dropna()

    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df_train)

    print("\n1. FEATURE ELOSZLÁSOK ÖSSZEHASONLÍTÁSA (Átlag és Szórás)")
    print(f"{'Feature':<20} | {'Tanító Átlag':<15} | {'Vizsga Átlag':<15} | {'Eltérés (%)':<15}")
    print("-" * 75)

    for feat in features:
        train_mean = df_train[feat].mean()
        exam_mean = df_exam[feat].mean()
        diff_pct = (exam_mean - train_mean) / (train_mean + 1e-9) * 100
        print(f"{feat:<20} | {train_mean:<15.4f} | {exam_mean:<15.4f} | {diff_pct:>8.2f}%")

    print("\n2. VALÓSZÍNŰSÉGEK ELOSZLÁSA AZ ÉLES (VIZSGA) ADATON (LightGBM)")
    bst = lgb.Booster(model_file=model_path)
    X_exam = df_exam[features].values
    probs = bst.predict(X_exam)

    p_short = probs[:, 0]
    p_noise = probs[:, 1]
    p_long = probs[:, 2]

    print(f"Átlagos Short Valószínűség: {np.mean(p_short):.4f} (Max: {np.max(p_short):.4f})")
    print(f"Átlagos Zaj Valószínűség:   {np.mean(p_noise):.4f} (Max: {np.max(p_noise):.4f})")
    print(f"Átlagos Long Valószínűség:  {np.mean(p_long):.4f} (Max: {np.max(p_long):.4f})")

    preds = np.argmax(probs, axis=1)

    # Kiszámoljuk, hányszor nyert a Zaj éppen csak egy hajszállal
    noise_wins_narrowly = np.sum((preds == 1) & (p_noise < 0.40))
    print(f"\nHajszálon múlt zaj-győzelmek (Zaj < 40%, de mégis nyert): {noise_wins_narrowly} eset")

if __name__ == '__main__':
    train_feat = '/home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv'
    exam_feat = '/home/misi/Merkava_ML_Ops/data/exam_0720_23/exam_features.csv'
    model = '/home/misi/Merkava_ML_Ops/models/lgbm_copilot_model.txt'

    run_diagnostics(train_feat, exam_feat, model)
