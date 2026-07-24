import pandas as pd
import numpy as np
from catboost import CatBoostClassifier
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score
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

def compute_sample_weights(df):
    class_counts = df['Target_Label'].value_counts()
    total_samples = len(df)
    weights = df['Target_Label'].map(lambda x: total_samples / (len(class_counts) * class_counts[x]))
    return weights

def train_catboost_model(data_path, model_out_dir):
    print(f"🚀 CatBoost Tanítás indítása (Purged K-Fold & Embargo): {data_path}")

    df = pd.read_csv(data_path).dropna()

    from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)
    target = 'Target_Label'

    # Szigorú Hold-Out Test set elkülönítése a valódi OOS teszthez (Utolsó 20%)
    holdout_idx = int(len(df) * 0.8)
    df_cv = df.iloc[:holdout_idx].copy()

    X = df_cv[features].values

    # Kategóriák eltolása: -1, 0, 1 -> 0, 1, 2
    y_raw = df_cv[target].values
    y = y_raw + 1

    weights = compute_sample_weights(df_cv).values
    splits = get_purged_kfold_splits(df_cv, n_splits=5, embargo_pct=0.01)

    best_model = None
    best_score = 0
    fold_scores = []

    os.makedirs(model_out_dir, exist_ok=True)

    print("\n🌲 K-Fold Keresztvalidáció indítása (CatBoost):")
    for fold, (train_idx, test_idx) in enumerate(splits):
        if len(train_idx) == 0:
            continue

        X_train, y_train, w_train = X[train_idx], y[train_idx], weights[train_idx]
        X_test, y_test = X[test_idx], y[test_idx]

        model = CatBoostClassifier(
            iterations=300,
            learning_rate=0.01,
            depth=4,
            loss_function='MultiClass',
            random_seed=42,
            verbose=False,
            thread_count=2
        )

        model.fit(
            X_train, y_train,
            sample_weight=w_train,
            eval_set=(X_test, y_test),
            early_stopping_rounds=30
        )

        preds = model.predict(X_test)
        score = accuracy_score(y_test, preds)
        fold_scores.append(score)

        print(f"  ✅ Fold {fold+1}: Accuracy = {score:.4f} (Tanító méret: {len(train_idx)}, Teszt méret: {len(test_idx)})")

        if score > best_score:
            best_score = score
            best_model = model

    print(f"\n📊 Átlagos CV (K-Fold) Accuracy: {np.mean(fold_scores):.4f}")

    if best_model is not None:
        model_path = os.path.join(model_out_dir, 'catboost_copilot_model.cbm')
        best_model.save_model(model_path)
        print(f"💾 A legjobb modell elmentve: {model_path}")

        importance = best_model.get_feature_importance()
        print("\n🔬 Feature Importance (A legjobb modell alapján):")
        for i, (feat, imp) in enumerate(zip(features, importance)):
            print(f"   - {feat}: {imp:.4f}")

    return best_model

if __name__ == '__main__':
    data_path = '/home/misi/Merkava_ML_Ops/data/processed/labeled_dollar_bars.csv'
    model_out_dir = '/home/misi/Merkava_ML_Ops/models/'

    if len(sys.argv) > 1:
        data_path = sys.argv[1]

    train_catboost_model(data_path, model_out_dir)
