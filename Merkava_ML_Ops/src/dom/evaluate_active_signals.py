import pandas as pd
import numpy as np
import lightgbm as lgb
from catboost import CatBoostClassifier
import joblib
import os
from sklearn.metrics import classification_report

def evaluate_active_signals(data_path, model_dir):
    print(f"🔄 Adatok betöltése: {data_path}")
    df = pd.read_csv(data_path).dropna()
    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)
    target = 'Target_Label'

    # Eltoljuk az osztályokat 0, 1, 2-re, ahogy a modellek betanultak
    y_true = df[target].values + 1
    X = df[features].values

    # Csak OOS szimuláció: Mivel a modellek Purged K-Folddal tanultak,
    # és a mi célunk most a puszta predikció, a legegyszerűbb, ha az adathalmaz utolsó 20%-át (OOS) nézzük meg,
    # mint egy hagyományos Train/Test split esetében a végső validálásra.
    split_idx = int(len(df) * 0.8)
    X_test = X[split_idx:]
    y_test = y_true[split_idx:]

    # A 3 fa és a Meta-Modell értékelése
    models = {
        'LightGBM': os.path.join(model_dir, 'lgbm_copilot_model.txt'),
        'CatBoost': os.path.join(model_dir, 'catboost_copilot_model.cbm'),
        'XGBoost': os.path.join(model_dir, 'xgboost_copilot_model.pkl'),
        'Meta_RandomForest': os.path.join(model_dir, 'rf_meta_copilot_model.pkl')
    }

    # Meta Feature generáláshoz kell egy Booster a memóriába
    try:
        lgbm_booster = lgb.Booster(model_file=models['LightGBM'])
        meta_probs_test = lgbm_booster.predict(X_test)

        # Meta feature-ök (P_Short, P_Noise, P_Long, P_Diff, P_Velocity, P_Acceleration, P_Exhaustion) szimulálása teszt adatokra
        # (Figyelem: vektorosan számoljuk az egyszerűség kedvéért)
        p_short = meta_probs_test[:, 0]
        p_noise = meta_probs_test[:, 1]
        p_long = meta_probs_test[:, 2]
        p_diff = p_long - p_short
        p_velocity = np.insert(np.diff(p_diff), 0, 0)
        p_accel = np.insert(np.diff(p_velocity), 0, 0)
        p_exh = np.where((p_long > 0.7) & (p_accel < 0), 1, np.where((p_short > 0.7) & (p_accel > 0), -1, 0))

        X_test_meta = np.column_stack([p_short, p_noise, p_long, p_diff, p_velocity, p_accel, p_exh])

    except Exception as e:
        print(f"Hiba a Meta feature-ök generálásánál: {e}")
        X_test_meta = None

    for name, path in models.items():
        if not os.path.exists(path):
            print(f"⚠️ Modell nem található: {name} ({path})")
            continue

        print(f"\n{'='*50}\n🚀 Értékelés: {name}\n{'='*50}")

        try:
            preds = None
            if name == 'LightGBM':
                bst = lgb.Booster(model_file=path)
                # predict probability, majd argmax
                probs = bst.predict(X_test)
                preds = np.argmax(probs, axis=1)
            elif name == 'CatBoost':
                model = CatBoostClassifier().load_model(path)
                preds = model.predict(X_test).flatten()
            elif name == 'XGBoost':
                model = joblib.load(path)
                preds = model.predict(X_test)
            elif name == 'Meta_RandomForest':
                if X_test_meta is None:
                    continue
                model = joblib.load(path)
                preds = model.predict(X_test_meta)

            # Az osztályok jelentése:
            # 0: Short (-1)
            # 1: Zaj (0)
            # 2: Long (1)

            # --- Tiszta Jelzések Kiszűrése ---
            # Olyan esetek, amikor a modell azt mondta, hogy 0 (Short) vagy 2 (Long)
            active_indices = np.where((preds == 0) | (preds == 2))[0]

            if len(active_indices) == 0:
                print("❌ A modell egyáltalán nem adott belépési jelet (mindig 'Zaj'-t prediktált).")
                continue

            y_test_active = y_test[active_indices]
            preds_active = preds[active_indices]

            total_active = len(preds_active)
            correct_active = np.sum(preds_active == y_test_active)
            active_accuracy = (correct_active / total_active) * 100

            short_indices = np.where(preds_active == 0)[0]
            short_correct = np.sum(preds_active[short_indices] == y_test_active[short_indices])
            short_acc = (short_correct / len(short_indices) * 100) if len(short_indices) > 0 else 0

            long_indices = np.where(preds_active == 2)[0]
            long_correct = np.sum(preds_active[long_indices] == y_test_active[long_indices])
            long_acc = (long_correct / len(long_indices) * 100) if len(long_indices) > 0 else 0

            print(f"📊 Összes OOS Tick/Bar a teszt periódusban: {len(X_test)}")
            print(f"🎯 Modell által generált aktív jelek (Long/Short): {total_active} db ({(total_active/len(X_test)*100):.1f}%)")
            print(f"✅ TISZTA WIN RATE (Zaj nélkül, csak a belépések pontossága): {active_accuracy:.2f}%")
            print(f"   📉 Short (-1) pontosság: {short_acc:.2f}% ({len(short_indices)} jelből)")
            print(f"   📈 Long (+1) pontosság: {long_acc:.2f}% ({len(long_indices)} jelből)")

        except Exception as e:
            print(f"❌ Hiba a(z) {name} értékelésekor: {e}")

if __name__ == '__main__':
    evaluate_active_signals(
        '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv',
        '/home/misi/Merkava_ML_Ops/models/'
    )
