import pandas as pd
import numpy as np
import lightgbm as lgb
from catboost import CatBoostClassifier
import joblib
import os
import sys

def evaluate_strict_oos(data_path, model_dir):
    print(f"🔄 Szigorú OOS Adatok betöltése: {data_path}")
    df = pd.read_csv(data_path).dropna()

    # Feature Engineering során az első ~100 sor automatikusan kiesik (a pd.dropna() miatt)
    # amíg a 100-as mozgóátlagok és M15 shiftek "bemelegszenek" (Warm-up).
    # Ezen a ponton ami a dataframe-ben van, az már mind tiszta, skálázható adat!

    features = [
        'OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_1m', 'Dist_5m', 'Dist_15m', 'ATR_Proxy',
        'Micro_RSI_14', 'Micro_MACD_Hist', 'Micro_BB_ZScore',
        'M15_RSI_14', 'M15_MACD_Hist', 'M15_BB_ZScore'
    ]
    target = 'Target_Label'

    # Eltoljuk az osztályokat 0, 1, 2-re, ahogy a modellek betanultak
    y_true = df[target].values + 1
    X = df[features].values

    # Szigorú OOS: Itt NINCS 80/20 vágás! Az egész fájl 100%-ban OOS adat,
    # hiszen a modellek egy teljesen másik (tanító) fájlon lettek kiképezve.
    X_test = X
    y_test = y_true

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

        print(f"\n{'='*50}\n🚀 Szigorú OOS Értékelés: {name}\n{'='*50}")

        try:
            preds = None
            if name == 'LightGBM':
                bst = lgb.Booster(model_file=path)
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

            print(f"📊 Összes OOS Tick/Bar az éles teszt periódusban: {len(X_test)}")
            print(f"🎯 Modell által generált aktív jelek (Long/Short): {total_active} db ({(total_active/len(X_test)*100):.1f}%)")
            print(f"✅ TISZTA WIN RATE (Zaj nélkül, csak a belépések pontossága): {active_accuracy:.2f}%")
            print(f"   📉 Short (-1) pontosság: {short_acc:.2f}% ({len(short_indices)} jelből)")
            print(f"   📈 Long (+1) pontosság: {long_acc:.2f}% ({len(long_indices)} jelből)")

        except Exception as e:
            print(f"❌ Hiba a(z) {name} értékelésekor: {e}")

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/exam_0720_23/exam_labeled.csv'
    model_dir = '/home/misi/Merkava_ML_Ops/models/'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    evaluate_strict_oos(data_path, model_dir)
