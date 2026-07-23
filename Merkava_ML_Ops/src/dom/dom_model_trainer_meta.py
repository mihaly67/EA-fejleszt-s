import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score
import joblib
import os
import sys

def get_purged_kfold_splits(df, n_splits=5, embargo_pct=0.01):
    kf = KFold(n_splits=n_splits, shuffle=False)
    embargo_size = int(len(df) * embargo_pct)

    splits = []
    for train_idx, test_idx in kf.split(df):
        test_start = test_idx[0]
        test_end = test_idx[-1]

        train_idx_purged = [i for i in train_idx if i < (test_start - embargo_size) or i > (test_end + embargo_size)]
        splits.append((np.array(train_idx_purged), test_idx))

    return splits

def train_meta_model(data_path, model_out_dir):
    print(f"🚀 Meta-Modell (Random Forest) Tanítás indítása: {data_path}")

    df = pd.read_csv(data_path).dropna()

    # Szigorú Hold-Out Test set elkülönítése a valódi OOS teszthez (Utolsó 20%)
    holdout_idx = int(len(df) * 0.8)
    df_cv = df.iloc[:holdout_idx].copy()

    # A Bemenet SZIGORÚAN csak a LightGBM "agyából" származó Meta-Feature-ök (plusz az eredeti Target)
    meta_features = ['P_Short', 'P_Noise', 'P_Long', 'P_Diff', 'P_Velocity', 'P_Acceleration', 'P_Exhaustion']
    target = 'Target_Label'

    X = df_cv[meta_features].values

    # Kategóriák eltolása: -1, 0, 1 -> 0, 1, 2
    y_raw = df_cv[target].values
    y = y_raw + 1

    splits = get_purged_kfold_splits(df_cv, n_splits=5, embargo_pct=0.01)

    best_model = None
    best_score = 0
    fold_scores = []

    os.makedirs(model_out_dir, exist_ok=True)

    print("\n🌲 K-Fold Keresztvalidáció indítása (Meta Random Forest):")
    for fold, (train_idx, test_idx) in enumerate(splits):
        if len(train_idx) == 0:
            continue

        X_train, y_train = X[train_idx], y[train_idx]
        X_test, y_test = X[test_idx], y[test_idx]

        # A Random Forest nagyon masszív a Meta-Labelinghez, mert nem overfittel könnyen
        # és imádja az ilyen "zajos, de erős" jeleket kiválogatni.
        model = RandomForestClassifier(
            n_estimators=200,
            max_depth=5,            # Nagyon sekély fa, hogy ne tanulja túl az "Alap Modell" hibáit
            class_weight='balanced',
            random_state=42,
            n_jobs=-1               # CPU összes magja
        )

        model.fit(X_train, y_train)

        preds = model.predict(X_test)
        score = accuracy_score(y_test, preds)
        fold_scores.append(score)

        print(f"  ✅ Fold {fold+1}: Accuracy = {score:.4f} (Tanító: {len(train_idx)}, Teszt: {len(test_idx)})")

        if score > best_score:
            best_score = score
            best_model = model

    print(f"\n📊 Átlagos CV (K-Fold) Accuracy (Meta-Modell): {np.mean(fold_scores):.4f}")

    if best_model is not None:
        model_path = os.path.join(model_out_dir, 'rf_meta_copilot_model.pkl')
        joblib.dump(best_model, model_path)
        print(f"💾 A legjobb Meta-Modell elmentve: {model_path}")

        importance = best_model.feature_importances_
        print("\n🔬 Meta-Feature Importance (A legjobb modell alapján):")
        for i, (feat, imp) in enumerate(zip(meta_features, importance)):
            print(f"   - {feat}: {imp:.4f}")

    return best_model

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/meta_features_dollar_bars.csv'
    model_out_dir = '/home/misi/Merkava_ML_Ops/models/'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    train_meta_model(data_path, model_out_dir)
