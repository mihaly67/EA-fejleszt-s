import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import optuna
import json
import os
import sys

DATA_PATH = "data/exam_24h_volatile_3MTF.csv"
MODEL_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"
OUTPUT_JSON = "models/optuna_tuned_thresholds.json"
N_TRIALS = 1500 # Extra gyors, mert nem tanít modellt!

# Globális adatok a gyors memóriai eléréshez
df_global = None
p_short_g = None
p_noise_g = None
p_long_g = None
y_true_g = None
trends_g = None

def load_data():
    global df_global, p_short_g, p_noise_g, p_long_g, y_true_g, trends_g
    print("Előkészítés...")
    df = pd.read_csv(DATA_PATH).dropna().reset_index(drop=True)
    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    y_true = df['Target_Label'].values
    if y_true.min() == -1: y_true = y_true + 1
    y_true_g = y_true

    trends = np.full(len(df), 'Sideways', dtype=object)
    trends[df['M15_RSI_14'] > 55] = 'Uptrend'
    trends[df['M15_RSI_14'] < 45] = 'Downtrend'
    trends_g = trends

    print("Modell betöltése probabilitásokhoz...")
    try:
        model = joblib.load(MODEL_PATH)
        probs = model.predict_proba(df[features])
    except:
        model = lgb.Booster(model_file=MODEL_PATH)
        probs = model.predict(df[features])

    p_short_g = probs[:, 0]
    p_noise_g = probs[:, 1]
    p_long_g = probs[:, 2]

def objective(trial):
    up_thr_long = trial.suggest_float('up_thr_long', 0.35, 0.45)
    up_thr_short = trial.suggest_float('up_thr_short', 0.45, 0.60) # Szigorú
    up_max_noise = trial.suggest_float('up_max_noise', 0.20, 0.45)

    down_thr_long = trial.suggest_float('down_thr_long', 0.45, 0.60) # Szigorú
    down_thr_short = trial.suggest_float('down_thr_short', 0.35, 0.45)
    down_max_noise = trial.suggest_float('down_max_noise', 0.20, 0.45)

    side_thr_long = trial.suggest_float('side_thr_long', 0.35, 0.45)
    side_thr_short = trial.suggest_float('side_thr_short', 0.35, 0.45)
    side_max_noise = trial.suggest_float('side_max_noise', 0.20, 0.45)

    thr_long = np.where(trends_g == 'Uptrend', up_thr_long, np.where(trends_g == 'Downtrend', down_thr_long, side_thr_long))
    thr_short = np.where(trends_g == 'Uptrend', up_thr_short, np.where(trends_g == 'Downtrend', down_thr_short, side_thr_short))
    max_noise = np.where(trends_g == 'Uptrend', up_max_noise, np.where(trends_g == 'Downtrend', down_max_noise, side_max_noise))

    preds = np.ones_like(y_true_g)

    long_cond = (p_long_g > thr_long) & (p_long_g > p_short_g) & (p_noise_g < max_noise)
    short_cond = (p_short_g > thr_short) & (p_short_g > p_long_g) & (p_noise_g < max_noise)

    preds[long_cond] = 2
    preds[short_cond] = 0

    active_mask = (preds == 0) | (preds == 2)
    total_active = active_mask.sum()

    if total_active < 500: # Büntetjük, ha nem elég aktív a volatilis napon
        return -1000

    correct = np.sum(preds[active_mask] == y_true_g[active_mask])
    win_rate = correct / total_active

    if win_rate < 0.45: # Büntetjük ha esik a Win Rate
        return -1000

    # Számoljuk a kontratrend kötéseket (ezeket büntetni fogjuk)
    counter_trend = ((trends_g == 'Uptrend') & (preds == 0)).sum() + ((trends_g == 'Downtrend') & (preds == 2)).sum()

    # Számoljuk a kihagyott kötéseket
    missed = ((trends_g == 'Uptrend') & (y_true_g == 2) & (preds == 1)).sum() + ((trends_g == 'Downtrend') & (y_true_g == 0) & (preds == 1)).sum()

    # Kereskedési Objektív: Magas Win Rate, Magas Aktivitás, Alacsony Kontratrend, Alacsony Missed
    score = (win_rate * 1000) + (total_active * 0.1) - (counter_trend * 2) - (missed * 1)

    return score

if __name__ == "__main__":
    load_data()

    optuna.logging.set_verbosity(optuna.logging.WARNING)
    study = optuna.create_study(direction="maximize")
    print(f"Ultra-Gyors Threshold Tuner Indítása ({N_TRIALS} iteráció)...")
    study.optimize(objective, n_trials=N_TRIALS)

    print("\n=== Befejezve ===")
    print(f"Legjobb érték (Score): {study.best_value:.4f}")
    for k, v in study.best_params.items():
        print(f"  {k}: {v:.4f}")

    with open(OUTPUT_JSON, 'w') as f:
        json.dump(study.best_params, f, indent=4)
