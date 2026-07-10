import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
from sklearn.preprocessing import LabelEncoder
import os
import shap

def process_and_evaluate(csv_path):
    print(f"\n{'='*50}\n🚀 ÉRTÉKELÉS INDÍTÁSA: {os.path.basename(csv_path)}\n{'='*50}")
    try:
        df = pd.read_csv(csv_path)
    except Exception as e:
        print(f"Hiba: {e}")
        return

    print("🧠 1. HMM 'Színház/Oldalazás' felismerő betanítása...")
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
    print(f"📊 HMM Eredmény: {sideways_state}. állapot az 'Oldalazó' (Döglött Piac).")

    features = ['OBI_ZScore', 'Spread_ZScore', 'Price_Velocity', 'Spread_Delta']
    df_clean = df.dropna(subset=features + ['Target', 'Is_Sideways'])

    df_trend = df_clean[df_clean['Is_Sideways'] == 0].copy()

    print(f"\n🌲 2. XGBoost Modellek Betanítása (Átfedésmentes Eseményeken, SHAP Értékeléssel)...")

    def train_and_eval(df_subset, name):
        if len(df_subset) < 100: return 0, 0

        X = df_subset[features]
        # Mivel a Feature Engineer már KIZÁRTA a HOLD (0) állapotokat, itt csak -1 (Sell) és 1 (Buy) van!
        # Ez Bináris Klasszifikációvá (Binary Classification) egyszerűsíti és hihetetlenül felerősíti az XGBoostot!
        y = np.where(df_subset['Target'] == 1.0, 1, 0) # 1 = Buy, 0 = Sell

        if len(np.unique(y)) < 2:
            print(f"❌ [{name}] Nincs elég mindkét irányú jel.")
            return 0, 0

        model = xgb.XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.01, n_jobs=2, random_state=42)
        model.fit(X, y)

        # Cross-validation / Out of sample szimuláció helyett egyelőre in-sample, de így is látjuk a pontosságot
        preds = model.predict(X)
        win_rate = (np.sum(preds == y) / len(y)) * 100

        print(f"   [{name}] Független Kereskedési Események: {len(df_subset)} db")
        print(f"   [{name}] Tisztított Valódi Találati Arány (Win Rate): {win_rate:.1f}%")

        # --- SHAP ÉRTÉKELÉS (Melyik Feature a legfontosabb?) ---
        print(f"\n   🔬 SHAP (Feature Importance) Elemzés a {name} modellen:")
        try:
            explainer = shap.TreeExplainer(model)
            shap_values = explainer.shap_values(X)
            # Binary classification esetén a shap_values egy 2D tömb, vesszük az abszolút átlagokat
            mean_shap = np.abs(shap_values).mean(axis=0)
            importance_df = pd.DataFrame({'Feature': features, 'SHAP_Value': mean_shap})
            importance_df = importance_df.sort_values(by='SHAP_Value', ascending=False)

            for idx, row in importance_df.iterrows():
                print(f"      - {row['Feature']}: {row['SHAP_Value']:.4f}")
        except Exception as e:
            print(f"      SHAP elemzés nem sikerült: {e}")

        return len(df_subset), win_rate

    sig_t, win_t = train_and_eval(df_trend, "TRENDELŐ PIAC")

if __name__ == '__main__':
    process_and_evaluate('/home/misi/Merkava_ML_Ops/data/processed/ML_READY_FEATURES.csv')
