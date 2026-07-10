import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
from sklearn.preprocessing import LabelEncoder
import os

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

    # Kivettem az 'ATR_Proxy', 'Spread', 'Spread_Delta' nyers formáit, amiket a Leak védelem miatt eldobtunk,
    # de a Spread_ZScore és OBI maradt.
    features = ['OBI_ZScore', 'Spread_ZScore', 'Price_Velocity']
    df_clean = df.dropna(subset=features + ['Target', 'Is_Sideways'])

    # KIZÁRÓLAG Trendelő piacon kereskedünk
    df_trend = df_clean[df_clean['Is_Sideways'] == 0].copy()

    print(f"\n🌲 2. XGBoost Modellek Betanítása (Költség-terhelt Targetekkel, Csak Trendelő Piac)...")

    def train_and_eval(df_subset, name, confidence_threshold=0.60):
        if len(df_subset) < 100: return 0, 0

        X = df_subset[features]
        le = LabelEncoder()
        y = le.fit_transform(df_subset['Target'])

        if len(np.unique(y)) < 2:
            print(f"❌ [{name}] Nincs mit tanulni, a spread megölte a piacot.")
            return 0, 0

        weights = compute_sample_weight('balanced', y)
        model = xgb.XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.01, n_jobs=2, random_state=42)
        model.fit(X, y, sample_weight=weights)

        probs = model.predict_proba(X)
        hold_class = le.transform([0.0])[0]
        preds = np.full(len(probs), hold_class)

        for i, p_arr in enumerate(probs):
            max_p = np.max(p_arr)
            pred_class = np.argmax(p_arr)
            if pred_class != hold_class and max_p >= confidence_threshold:
                preds[i] = pred_class

        preds_mapped = le.inverse_transform(preds)
        actual = df_subset['Target'].values

        total_signals = np.sum(preds_mapped != 0)
        correct_signals = np.sum((preds_mapped != 0) & (preds_mapped == actual))
        win_rate = (correct_signals / total_signals * 100) if total_signals > 0 else 0

        print(f"   [{name}] Vizsgált adatsor: {len(df_subset)} tick")
        print(f"   [{name}] Generált Szignálok (Konfidencia > {confidence_threshold*100}%): {total_signals} db")
        print(f"   [{name}] Valódi Találati Arány (Win Rate): {win_rate:.1f}%")

        return total_signals, win_rate

    sig_t, win_t = train_and_eval(df_trend, "TRENDELŐ PIAC", 0.60)

    print(f"\n✅ ÖSSZEGZÉS: A modell {sig_t} db 'Mesterlövész' predikciót tett a Trendelő piacon.")

if __name__ == '__main__':
    process_and_evaluate('/home/misi/Merkava_ML_Ops/data/processed/ML_READY_FEATURES.csv')
