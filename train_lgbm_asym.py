import pandas as pd
import lightgbm as lgb
import json
import joblib
import os

DATA_PATH = "data/labeled_dollar_bars_3MTF.csv"
PARAMS_PATH = "models/optuna_asymmetric_params_3MTF_v2.json"
MODEL_OUTPUT_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"

def main():
    print(f"Tanuló adathalmaz beolvasása: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Open', 'High', 'Low', 'Close', '5m_Close', '15m_Close', '30m_Close', 'Target_Label', 'Bar_Time_Seconds', 'Total_Dollar_Value', 'Bid_Volume', 'Ask_Volume', 'Total_Volume']
    features = [col for col in df.columns if col not in ignore_cols]

    X = df[features]
    y = df['Target_Label']

    if y.min() == -1:
        y = y + 1

    print(f"Jellemzők ({len(features)}): {features}")

    print(f"Paraméterek betöltése: {PARAMS_PATH}")
    with open(PARAMS_PATH, 'r') as f:
        best_params = json.load(f)

    # Ezek csak az optuna filterek, kivesszük a model initből
    threshold_short = best_params.pop('threshold_short')
    threshold_long = best_params.pop('threshold_long')
    max_noise = best_params.pop('max_noise')

    best_params['objective'] = 'multiclass'
    best_params['num_class'] = 3
    best_params['metric'] = 'multi_logloss'
    best_params['boosting_type'] = 'gbdt'
    best_params['seed'] = 42

    print("Modell tanítása a legjobb aszimmetrikus paraméterekkel a teljes adathalmazon...")
    model = lgb.LGBMClassifier(**best_params)
    model.fit(X, y)

    print(f"Modell mentése: {MODEL_OUTPUT_PATH}")
    joblib.dump(model, MODEL_OUTPUT_PATH)
    print("Kész!")

if __name__ == "__main__":
    main()
