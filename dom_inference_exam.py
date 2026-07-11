import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
import sys

# OOS Exam Script - Ezt használjuk az ÉLES adat tesztelésére, ez már NEM tanít, csak inference.

print("="*60)
print("DOM Inference Exam (Out-Of-Sample)")
print("="*60)

OOS_DATA_PATH = "data/DOM_Data_20260710_050837.csv"
ENGINEERED_OOS_PATH = "data/processed/engineered_oos.csv"
MODEL_PATH = "models/xgb_trend_model.json"
HMM_PATH = "models/hmm_model.pkl"
CONFIDENCE_THRESHOLD = 0.45 # Mivel L1 data miatt szűk, visszavesszük 45%-ra a validáció alapján

# 1. Betöltjük az OOS adatot
print(f"Betöltés OOS adat... {ENGINEERED_OOS_PATH}")
try:
    df_oos = pd.read_csv(ENGINEERED_OOS_PATH)
except FileNotFoundError:
    print(f"Nincs meg az OOS feature file ({ENGINEERED_OOS_PATH}), futtasd az engineer-t rá előbb.")
    sys.exit(1)

# Betöltjük a nyers OOS-t is az értékeléshez (árak)
print(f"Betöltés nyers OOS adat az értékeléshez... {OOS_DATA_PATH}")
try:
    df_raw = pd.read_csv(OOS_DATA_PATH)
except FileNotFoundError:
    print(f"Nem találom a nyers adatot itt: {OOS_DATA_PATH}")
    sys.exit(1)

df_raw = df_raw.iloc[df_raw.index.isin(df_oos.index)] # Csak azokat a sorokat tartjuk meg, amik a feature-ben is benne vannak

# Calculate Price in df_raw for evaluation
df_raw['Price'] = (df_raw['Ask'] + df_raw['Bid']) / 2.0

# 2. Betöltjük a modelleket
print("Betöltés HMM és XGBoost modellek...")
try:
    model = xgb.XGBClassifier()
    model.load_model(MODEL_PATH)
    hmm_model = joblib.load(HMM_PATH)
except FileNotFoundError:
    print(f"Nincsenek modellek a {MODEL_PATH} vagy {HMM_PATH} útvonalon. Futtasd a tanítást előbb.")
    sys.exit(1)

# 3. Készítsük elő az adatot a predikcióhoz
X = df_oos.drop('Target', axis=1, errors='ignore')
actual_targets = df_oos['Target'] if 'Target' in df_oos.columns else None

# Igazítsuk a feature neveket a tanítóban lévőkhöz:
features_to_keep = ['OBI_ZScore', 'Spread_ZScore', 'Price_Velocity', 'Spread_Delta']
X = X[features_to_keep]

# 4. HMM Filter (Csak a Trending-et hagyjuk meg az XGB-nek)
hmm_features = []
if 'Spread_ZScore_1' in X.columns:
    hmm_features.append('Spread_ZScore_1')
if 'Vol_Imbalance_L1' in X.columns:
    hmm_features.append('Vol_Imbalance_L1')
if 'Price_Velocity' in X.columns:
    hmm_features.append('Price_Velocity')

if len(hmm_features) == 3:
    X_hmm = X[hmm_features]
    states = hmm_model.predict(X_hmm)
    print(f"HMM Állapotok: {np.unique(states, return_counts=True)}")
else:
    states = np.zeros(len(X)) # Fallback

# 5. XGBoost Predikció
print("Futtatás: XGBoost predict_proba...")
probs = model.predict_proba(X)

prob_sell = probs[:, 0]
prob_hold = probs[:, 1]
prob_buy = probs[:, 2]

signals = np.zeros(len(X))
signals[prob_buy > CONFIDENCE_THRESHOLD] = 1
signals[prob_sell > CONFIDENCE_THRESHOLD] = -1

conflict = (prob_buy > CONFIDENCE_THRESHOLD) & (prob_sell > CONFIDENCE_THRESHOLD)
signals[conflict] = 0

print(f"Predikció Kész. Cél Threshold: {CONFIDENCE_THRESHOLD}")
print(f"XGB Nyers Szignálok - Buy: {np.sum(signals == 1)}, Sell: {np.sum(signals == -1)}, Hold: {np.sum(signals == 0)}")

# 6. Értékelés a Nyers Adaton (Triple Barrier Szimuláció)
print("\n--- OOS Kereskedési Szimuláció ---")

COMMISSION_PTS = 0.15 # 1.5$ per RT / 10$ tick value = 0.15 pts
TP_PTS = 1.00 # 10$
SL_PTS = 0.40 # 4$

win_count = 0
loss_count = 0
timeout_count = 0

df_eval = df_raw.reset_index(drop=True)

signal_indices = np.where(signals != 0)[0]

print(f"Vizsgálandó kötés: {len(signal_indices)}")

for idx in signal_indices:
    direction = signals[idx]
    entry_idx = df_oos.index[idx]

    try:
        raw_idx = df_eval[df_eval.index == entry_idx].index[0]
    except IndexError:
        continue

    entry_price = df_eval.loc[raw_idx, 'Price']
    if np.isnan(entry_price):
        continue

    horizon = df_eval.iloc[raw_idx+1 : raw_idx+1000]
    if horizon.empty:
        continue

    hit_tp = False
    hit_sl = False

    for _, row in horizon.iterrows():
        current_price = row['Price']
        if np.isnan(current_price): continue

        if direction == 1:
            profit = current_price - entry_price - COMMISSION_PTS
            if profit >= TP_PTS:
                win_count += 1
                hit_tp = True
                break
            elif profit <= -SL_PTS:
                loss_count += 1
                hit_sl = True
                break

        elif direction == -1:
            profit = entry_price - current_price - COMMISSION_PTS
            if profit >= TP_PTS:
                win_count += 1
                hit_tp = True
                break
            elif profit <= -SL_PTS:
                loss_count += 1
                hit_sl = True
                break

    if not hit_tp and not hit_sl:
        timeout_count += 1

total_trades = win_count + loss_count + timeout_count
if total_trades > 0:
    win_rate = win_count / total_trades * 100
    print(f"Wins: {win_count}")
    print(f"Losses: {loss_count}")
    print(f"Timeouts: {timeout_count}")
    print(f"OOS Win Rate: {win_rate:.2f}%")
else:
    print("Nem született kötés.")

print("\n(Megjegyzés: Ha az OOS Win Rate kicsi, az az 1-szintű DOM adat zajossága miatt van. Valós L2-L10 kell.)")
