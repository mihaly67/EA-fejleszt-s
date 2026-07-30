import pandas as pd
import lightgbm as lgb
import json
import joblib

DATA_PATH = "data/labeled_dollar_bars_3MTF.csv"
PARAMS_PATH = "models/optuna_architecture_params.json"
MODEL_OUTPUT_PATH = "models/lgbm_model_3MTF_v2_asym.pkl"

def main():
    print(f"Tanuló adathalmaz beolvasása: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'OBI_Raw', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X = df[features]
    y = df['Target_Label']

    if y.min() == -1:
        y = y + 1

    with open(PARAMS_PATH, 'r') as f:
        best_params = json.load(f)

    n_estimators = best_params.pop('n_estimators')

    best_params['objective'] = 'multiclass'
    best_params['num_class'] = 3
    best_params['metric'] = 'multi_error'
    best_params['boosting_type'] = 'gbdt'
    best_params['seed'] = 42
    best_params['n_estimators'] = n_estimators

    print("Modell tanítása a legjobb architektúra paraméterekkel...")
    model = lgb.LGBMClassifier(**best_params)
    model.fit(X, y)

    print(f"Modell mentése: {MODEL_OUTPUT_PATH}")
    joblib.dump(model, MODEL_OUTPUT_PATH)
    print("Kész!")

if __name__ == "__main__":
    main()
