import pandas as pd
import lightgbm as lgb
import joblib
import os

DATA_PATH = "data/labeled_dollar_bars_3MTF_v3.csv"
MODEL_OUTPUT_PATH = "models/lgbm_model_default.pkl"

def main():
    print(f"Tanuló adathalmaz beolvasása: {DATA_PATH}")
    df = pd.read_csv(DATA_PATH)

    ignore_cols = ['Start_Timestamp', 'End_Timestamp', 'Target_Label', 'Open', 'High', 'Low', 'Close', 'Bid_Volume', 'Ask_Volume', 'Total_Volume', 'Total_Dollar_Value', '1m_Close', 'Dist_1m', '5m_Close', '10m_Close', '15m_Close', '30m_Close', '60m_Close', 'Bar_Time_Seconds', 'P_Short', 'P_Noise', 'P_Long', 'Signal']
    features = [col for col in df.columns if col not in ignore_cols]

    X = df[features]
    y = df['Target_Label']

    if y.min() == -1:
        y = y + 1

    print(f"Jellemzők ({len(features)}): {features}")

    # SZŰZ, ALAPÉRTELMEZETT MODELL - OPTUNA NÉLKÜL
    print("Modell tanítása GYÁRI, ALAPÉRTELMEZETT paraméterekkel...")
    model = lgb.LGBMClassifier(
        objective='multiclass',
        num_class=3,
        random_state=42,
        n_jobs=-1
        # Minden más paraméter: num_leaves, max_depth, learning_rate, n_estimators az LGBMClassifier defaultja marad!
    )

    model.fit(X, y)

    print(f"Modell mentése: {MODEL_OUTPUT_PATH}")
    joblib.dump(model, MODEL_OUTPUT_PATH)
    print("Kész!")

if __name__ == "__main__":
    main()
