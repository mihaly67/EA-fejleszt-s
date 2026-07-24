import joblib
import numpy as np
import os
import sys

def analyze_mlp(model_path):
    print(f"🔄 Betöltés: {model_path}")
    if not os.path.exists(model_path):
        print("❌ Hiba: A modell fájl nem található!")
        return

    try:
        model = joblib.load(model_path)
    except Exception as e:
        print(f"❌ Hiba a modell betöltésekor: {e}")
        return

    # Dinamikus dummy dataframe a feature nevekhez (mert az MLP nem menti el őket)
    # Figyelem: feltételezi, hogy van egy training data file.
    train_path = '/home/misi/Merkava_ML_Ops/data/processed/features_dollar_bars.csv'
    try:
        import pandas as pd
        from hud_logic_prep import get_dynamic_features
        df = pd.read_csv(train_path, nrows=5)
        features = get_dynamic_features(df)
    except Exception as e:
        print(f"Hiba a feature nevek betöltésekor: {e}")
        features = [f"Feature_{i}" for i in range(model.coefs_[0].shape[0])]

    if not hasattr(model, 'coefs_'):
        print("❌ Hiba: A betöltött modellnek nincsenek súlymátrixai (nem MLPClassifier).")
        return

    print("\n🔍 --- MLP Belső Súly Mátrix (Input -> 1. Rejtett Réteg) Elemzése ---")

    # model.coefs_[0] egy (n_features, n_hidden_nodes) méretű mátrix
    # Ez megmutatja, hogy a bemeneti feature-ök hogyan kapcsolódnak az első réteg neuronjaihoz.
    input_weights = model.coefs_[0]

    # Ha kiszámoljuk a súlyok abszolút értékének átlagát minden feature-re (soronként),
    # az egy jó közelítést ad a feature "fontosságára" a hálózaton belül.
    importance = np.mean(np.abs(input_weights), axis=1)

    # Normalizáljuk, hogy százalékos legyen
    importance_pct = (importance / np.sum(importance)) * 100

    # Párosítjuk a neveket az értékekkel és sorbarendezzük
    feature_importance = list(zip(features, importance_pct))
    feature_importance.sort(key=lambda x: x[1], reverse=True)

    print("\n📊 'Proxy' Feature Importance a Neurális Hálóban (Abszolút súlyok átlaga):")
    for feat, imp in feature_importance:
        print(f"   - {feat}: {imp:.2f}%")

    print("\n💡 Struktúra információk:")
    print(f"   Bemeneti feature-ök száma: {len(features)}")
    print(f"   1. Rejtett réteg neuronjainak száma: {input_weights.shape[1]}")
    if len(model.coefs_) > 1:
        print(f"   2. Rejtett réteg neuronjainak száma: {model.coefs_[1].shape[1]}")
    print(f"   Összes aktiválási iteráció: {model.n_iter_}")

if __name__ == '__main__':
    model_path = '/home/misi/Merkava_ML_Ops/models/mlp_copilot_model.pkl'
    if len(sys.argv) > 1:
        model_path = sys.argv[1]

    analyze_mlp(model_path)
