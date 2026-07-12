import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
from sklearn.preprocessing import LabelEncoder
import os
import joblib

def process_and_train(csv_path, model_dir):
    print(f"\n{'='*50}\n🚀 BETANÍTÁS (TRAINING) INDÍTÁSA: {os.path.basename(csv_path)}\n{'='*50}")
    df = pd.read_csv(csv_path)

    os.makedirs(model_dir, exist_ok=True)

    print("🧠 1. HMM 'Színház/Oldalazás' felismerő betanítása és mentése...")
    hmm_features = df[["Spread_ZScore", "Price_Velocity", "OBI_ZScore"]].dropna()
    scaler = StandardScaler()
    scaled_feats = scaler.fit_transform(hmm_features)

    model_hmm = hmm.GaussianHMM(n_components=3, covariance_type="full", n_iter=100, random_state=42)
    model_hmm.fit(scaled_feats)
    regimes = model_hmm.predict(scaled_feats)
    df.loc[hmm_features.index, 'Regime'] = regimes

    state_means = df.groupby('Regime')['Price_Velocity'].mean()
    sideways_state = state_means.abs().idxmin()
    df['Is_Sideways'] = (df['Regime'] == sideways_state).astype(int)
    print(f"📊 HMM Eredmény: {sideways_state}. állapot az 'Oldalazó'.")

    # Save HMM artifacts
    joblib.dump(scaler, os.path.join(model_dir, 'hmm_scaler.pkl'))
    joblib.dump(model_hmm, os.path.join(model_dir, 'hmm_model.pkl'))
    joblib.dump(sideways_state, os.path.join(model_dir, 'hmm_sideways_state.pkl'))

    features = ['OBI_ZScore', 'Spread_ZScore', 'Price_Velocity', 'Spread_Delta']
    df_clean = df.dropna(subset=features + ['Target', 'Is_Sideways'])

    df_trend = df_clean[df_clean['Is_Sideways'] == 0].copy()

    print(f"\n🌲 2. XGBoost Modell Betanítása (Trendelő Piac)...")
    if len(df_trend) < 100:
        print("❌ Nincs elég adat a Trendelő piacon a tanuláshoz.")
        return

    X = df_trend[features]
    le = LabelEncoder()
    y = le.fit_transform(df_trend['Target'])

    # Save LabelEncoder
    joblib.dump(le, os.path.join(model_dir, 'label_encoder.pkl'))

    weights = compute_sample_weight('balanced', y)
    model = xgb.XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.01, n_jobs=2, random_state=42)
    model.fit(X, y, sample_weight=weights)

    # Save XGBoost Model
    model.save_model(os.path.join(model_dir, 'xgb_trend_model.json'))

    print("✅ Betanítás sikeres. Modellek és skálázók elmentve a 'models' mappába.")

if __name__ == '__main__':
    from dom_feature_engineer import DOMFeatureEngineer
    # 1. Feature Engineering a régi (tanító) fájlon
    train_raw = 'data/raw/DOM_Data_20260706_111039.csv'
    train_features = 'data/processed/ML_TRAIN_FEATURES.csv'
    engineer = DOMFeatureEngineer(train_raw, train_features)
    engineer.process()

    # 2. Betanítás
    process_and_train(train_features, 'models/')
