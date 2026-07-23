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
    features = ['OBI_ZScore', 'Price_Velocity', 'Tick_Speed', 'Dist_1m', 'Dist_5m', 'Dist_15m', 'ATR_Proxy']
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

    models = {
        'LightGBM': os.path.join(model_dir, 'lgbm_copilot_model.txt'),
        'CatBoost': os.path.join(model_dir, 'catboost_copilot_model.cbm'),
        'sklearn_MLP': os.path.join(model_dir, 'mlp_copilot_model.pkl'),
        'PyTorch_MLP': os.path.join(model_dir, 'pytorch_copilot_model.pt')
    }

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
            elif name == 'sklearn_MLP':
                model = joblib.load(path)
                scaler_path = os.path.join(model_dir, 'mlp_scaler.pkl')
                scaler = joblib.load(scaler_path)
                X_test_scaled = scaler.transform(X_test)
                preds_raw = model.predict(X_test_scaled)
                preds = preds_raw + 1 # -1, 0, 1 -> 0, 1, 2
            elif name == 'PyTorch_MLP':
                import torch
                from dom_model_trainer_pytorch import CopilotMLP

                model_state = torch.load(path)
                model = CopilotMLP(input_size=len(features), num_classes=3)
                model.load_state_dict(model_state)
                model.eval()

                scaler_path = os.path.join(model_dir, 'pytorch_scaler.pt')
                scaler = joblib.load(scaler_path)
                X_test_scaled = scaler.transform(X_test)

                with torch.no_grad():
                    X_test_t = torch.FloatTensor(X_test_scaled)
                    outputs = model(X_test_t)
                    _, predicted = torch.max(outputs.data, 1)
                    preds = predicted.numpy()

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
