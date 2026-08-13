import pandas as pd
import numpy as np
import lightgbm as lgb
import joblib
import shap
import warnings
import sys
warnings.filterwarnings('ignore')

def main():
    print("🧠 --- BETA SHAP ANALYZER (FOCUS: STOCHASTIC) ---")

    # 1. Load Model
    model_path = "../../models/lgbm_model_fusion_v5_tuned.pkl"
    try:
        clf = joblib.load(model_path)
        print("✅ Loaded V5 Fusion Model.")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    features = [
        'Tick_Speed', 'Dist_Micro_R', 'Dist_Micro_S',
        'Dist_Sec_R', 'Dist_Sec_S',
        'Dist_Ter_R', 'Dist_Ter_S',
        'Stoch_State_M1',
        'Upper_Wick_ATR', 'Lower_Wick_ATR'
    ]

    # Generate a synthetic background dataset to evaluate internal tree splits.
    # For tree models, SHAP path-dependent feature importance can be approximated with random normal data
    # to trigger different decision paths inside the booster.
    np.random.seed(42)
    synthetic_data = np.random.randn(2000, 10)
    X_sample = pd.DataFrame(synthetic_data, columns=features)

    print(f"\n⏳ Initializing SHAP TreeExplainer on {len(X_sample)} samples...")
    explainer = shap.TreeExplainer(clf)
    shap_values = explainer.shap_values(X_sample)

    # shap_values is a list of arrays: [Class 0 (Short), Class 1 (Noise), Class 2 (Long)]
    class_names = ['Class 0 (Short)', 'Class 1 (Noise)', 'Class 2 (Long)']

    for i, c_name in enumerate(class_names):
        print(f"\n📊 Feature Importance for {c_name}:")

        # Calculate mean absolute SHAP value for each feature
        vals = np.abs(shap_values[i]).mean(0)
        feature_importance = pd.DataFrame(list(zip(features, vals)), columns=['col_name', 'feature_importance_vals'])
        feature_importance.sort_values(by=['feature_importance_vals'], ascending=False, inplace=True)

        for idx, row in feature_importance.iterrows():
            marker = "⚠️" if row['col_name'] == 'Stoch_State_M1' else "  "
            print(f"  {marker} {row['col_name']:<20}: {row['feature_importance_vals']:.6f}")

    print("\n🔍 STOCHASTIC CONCLUSION:")
    # Find rank of Stoch
    stoch_ranks = []
    for i in range(3):
        vals = np.abs(shap_values[i]).mean(0)
        fi = pd.DataFrame(list(zip(features, vals)), columns=['col_name', 'imp'])
        fi.sort_values(by='imp', ascending=False, inplace=True)
        fi.reset_index(drop=True, inplace=True)
        matches = fi[fi['col_name'] == 'Stoch_State_M1'].index
        rank = matches[0] + 1 if len(matches) > 0 else 99
        stoch_ranks.append(rank)

        print(f"\nFull Feature Importance Rank for Class {i}:")
        for idx, row in fi.iterrows():
            print(f"{idx+1}. {row['col_name']:<18} ({row['imp']:.5f})")

    print(f"Rank of Stoch_State_M1 in Short decisions: {stoch_ranks[0]}/10")
    print(f"Rank of Stoch_State_M1 in Long decisions:  {stoch_ranks[2]}/10")

    if stoch_ranks[0] <= 3 or stoch_ranks[2] <= 3:
        print("-> It is highly influential (Top 3). If Win Rate is low, it might be heavily skewing trades too early!")
    elif stoch_ranks[0] >= 8 and stoch_ranks[2] >= 8:
        print("-> It has very little influence (Bottom 3). It is mostly ignored by the model.")
    else:
        print("-> It is a moderate supporting feature. It confirms geometry but does not dictate it.")

if __name__ == "__main__":
    main()
