import pandas as pd
import numpy as np
import xgboost as xgb
from hmmlearn import hmm
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
import os

def process_and_evaluate(csv_path):
    print(f"\n{'='*50}\n🚀 ÉRTÉKELÉS INDÍTÁSA: {os.path.basename(csv_path)}\n{'='*50}")

    try:
        df = pd.read_csv(csv_path)
    except FileNotFoundError:
        print(f"❌ Nem találom a fájlt: {csv_path}. Futtasd le előbb a feature engineert!")
        return

    # 1. HMM (Kaufman / Oldalazás szűrés)
    # A Vaku3 alapján az oldalazást (Sideways) a volatilitás és sebesség hiánya definiálja
    print("🧠 1. HMM 'Színház/Oldalazás' felismerő betanítása (Spread és Tick Sebesség alapján)...")
    hmm_features = df[["Spread_ZScore", "Price_Velocity", "OBI_ZScore"]].dropna()
    scaler = StandardScaler()
    scaled_feats = scaler.fit_transform(hmm_features)

    # 3 Állapot: Normál, Volatilis, Oldalazás
    model_hmm = hmm.GaussianHMM(n_components=3, covariance_type="full", n_iter=100, random_state=42)
    model_hmm.fit(scaled_feats)
    regimes = model_hmm.predict(scaled_feats)

    df.loc[hmm_features.index, 'Regime'] = regimes

    # Megkeressük melyik a legkisebb volatilitású (legkisebb velocity-jű) állapot = Oldalazás
    state_means = df.groupby('Regime')['Price_Velocity'].mean()
    sideways_state = state_means.abs().idxmin()

    df['Is_Sideways'] = (df['Regime'] == sideways_state).astype(int)
    print(f"📊 HMM Eredmény: {sideways_state}. állapot az 'Oldalazó' (Döglött Piac).")

    # 2. XGBoost Betanítás
    features = ['OBI_ZScore', 'Spread_ZScore', 'Price_Velocity', 'ATR_Proxy', 'Spread', 'Spread_Delta']
    df_clean = df.dropna(subset=features + ['Target', 'Is_Sideways'])

    df_trend = df_clean[df_clean['Is_Sideways'] == 0].copy()
    df_side = df_clean[df_clean['Is_Sideways'] == 1].copy()

    print(f"\n🌲 2. XGBoost Modellek Betanítása (Kétágú fa: Trendelő vs Oldalazó piacokra)...")

    def train_and_eval(df_subset, name):
        if len(df_subset) < 100:
            print(f"❌ Nincs elég adat a {name} modellhez.")
            return None, 0, 0

        X = df_subset[features]

        # XGBoost requires labels to be tightly packed integers starting at 0
        from sklearn.preprocessing import LabelEncoder
        le = LabelEncoder()
        y = le.fit_transform(df_subset['Target'])

        # Mivel a 0 (Hold) dominál, kötelező a Sample Weight (Cost-Sensitive Learning)
        # Ez kényszeríti az AI-t, hogy komolyan vegye a Buy/Sell jeleket a zajban is.
        weights = compute_sample_weight('balanced', y)

        # OOM védelem a felhőben/VPS-en: n_jobs=2 a max
        model = xgb.XGBClassifier(n_estimators=100, max_depth=4, learning_rate=0.05, n_jobs=2, random_state=42)
        model.fit(X, y, sample_weight=weights)

        preds = model.predict(X)

        # Visszaalakítás (-1: Sell, 0: Hold, 1: Buy)
        preds_mapped = le.inverse_transform(preds)
        actual = df_subset['Target'].values

        total_signals = np.sum(preds_mapped != 0)
        correct_signals = np.sum((preds_mapped != 0) & (preds_mapped == actual))
        win_rate = (correct_signals / total_signals * 100) if total_signals > 0 else 0

        print(f"   [{name}] Vizsgált adatsor: {len(df_subset)} tick")
        print(f"   [{name}] Generált Szignálok (Buy/Sell): {total_signals} db")
        print(f"   [{name}] Találati Arány (Win Rate): {win_rate:.1f}%")

        return model, total_signals, win_rate

    _, sig_trend, win_trend = train_and_eval(df_trend, "TRENDELŐ PIAC")
    _, sig_side, win_side = train_and_eval(df_side, "OLDALAZÓ PIAC")

    print(f"\n✅ ÖSSZEGZÉS: A modell {(sig_trend + sig_side)} predikciót (belépési jelet) tett a {len(df)} tick-es ablakban.")

if __name__ == '__main__':
    # Alapértelmezett fájl a VPS-en (vagy cseréld le a sajátodra)
    # Itt most a korábban általunk generalt es lefeature-özött teszt fájlra fut
    process_and_evaluate("ML_READY_FEATURES.csv")
