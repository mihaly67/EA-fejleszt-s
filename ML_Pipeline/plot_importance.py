import pandas as pd
import numpy as np
import xgboost as xgb
import matplotlib.pyplot as plt

print('Adatok betöltése...')
df = pd.read_parquet('../data/processed/scalp_features.parquet')

# Eldobjuk a 'zaj' (0) címkéket a tréninghez
df = df[df['target'] != 0].copy()

# A target most 1 és -1. Alakítsuk XGBoost bináris (1 és 0) formátumra
y = df['target'].replace(-1, 0)

drop_cols = ['target', 'TickMSC', 'Ping_MS', 'MimicMode', 'Verdict', 'ActionDetails', 'LastEvent', 'LotDir']
feature_cols = [c for c in df.columns if c not in drop_cols and df[c].dtype in [np.float64, np.float32, np.int64, np.int32]]
X = df[feature_cols]

print(f'Training XGBoost a tiszta halmazon (Sorok: {len(X)}, Feature-ök: {len(feature_cols)})...')

# XGBoost paraméterek gyors fához
model = xgb.XGBClassifier(
    n_estimators=100,
    max_depth=4,
    learning_rate=0.05,
    random_state=42,
    eval_metric='logloss',
    n_jobs=2
)
model.fit(X, y)

print('Plotting Feature Importance...')
plt.figure(figsize=(12, 10))
# Plotly helyett matplotlib, mert képet akarunk menteni a sandboxba
xgb.plot_importance(model, max_num_features=15, height=0.5, importance_type='weight', show_values=False)
plt.title('XGBoost Top 15 Legfontosabb Indikátor (Triple Barrier Setup)')
plt.tight_layout()
plt.savefig('feature_importance.png', dpi=150)
print('Kép kimentve: feature_importance.png')
