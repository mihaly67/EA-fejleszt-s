import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import matplotlib.pyplot as plt
import os
import joblib

print("Loading processed features...")
DATA_PATH = '../data/processed/scalp_features.parquet'
MODEL_DIR = '../models/'
os.makedirs(MODEL_DIR, exist_ok=True)

df = pd.read_parquet(DATA_PATH)

# Sort strictly by time to avoid data leakage
if 'timestamp' in df.columns:
    df = df.sort_values('timestamp')
elif 'time' in df.columns:
    df = df.sort_values('time')

print(f"Data shape before filtering: {df.shape}")

# Drop rows where target is NaN
df = df.dropna(subset=['target'])

# We only train on decisive moments where target is 1 (Buy) or -1 (Sell)
# For a 3-class model (Buy/Sell/Hold), we keep 0. Let's build a 3-class model.
# Note: XGBoost expects labels 0, 1, 2 for a 3-class problem.
# Mapping: Hold(0)->0, Buy(1)->1, Sell(-1)->2
label_mapping = {0.0: 0, 1.0: 1, -1.0: 2}
df['label'] = df['target'].map(label_mapping)

print(f"Label distribution:\n{df['label'].value_counts()}")

# Features to exclude from training
exclude_cols = ['time', 'timestamp', 'target', 'label', 'open', 'high', 'low', 'close', 'tick_volume', 'spread', 'real_volume']
features = [col for col in df.columns if col not in exclude_cols]

print(f"Using {len(features)} features: {features}")

X = df[features]
y = df['label']

# 80-20 Split without shuffling! Time series rules apply.
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.20, shuffle=False)

print(f"Training set: {X_train.shape[0]} rows")
print(f"Testing set: {X_test.shape[0]} rows")


# Build the initial model to find feature importance
model_initial = xgb.XGBClassifier(
    n_estimators=100,
    learning_rate=0.1,
    max_depth=5,
    objective='multi:softprob',
    num_class=3,
    tree_method='hist',
    n_jobs=-1,
    random_state=42
)

print("Training initial model for Feature Selection...")
model_initial.fit(X_train, y_train, verbose=False)

# Get feature importances and drop the useless ones (e.g. importance < 0.01)
importance = model_initial.feature_importances_
imp_df = pd.DataFrame({'Feature': features, 'Importance': importance})
useless_features = imp_df[imp_df['Importance'] < 0.01]['Feature'].tolist()

print(f"Dropping {len(useless_features)} unimportant features (importance < 0.01): {useless_features}")

# Update features list
features = [f for f in features if f not in useless_features]
print(f"Remaining {len(features)} important features: {features}")

# Redefine X with selected features
X_train_sel = X_train[features]
X_test_sel = X_test[features]

print("Training final robust model on selected features...")
model = xgb.XGBClassifier(
    n_estimators=300,
    learning_rate=0.05,
    max_depth=6,
    subsample=0.8,
    colsample_bytree=0.8,
    objective='multi:softprob',
    num_class=3,
    eval_metric='mlogloss',
    tree_method='hist',
    n_jobs=-1,
    random_state=42
)

model.fit(
    X_train_sel, y_train,
    eval_set=[(X_train_sel, y_train), (X_test_sel, y_test)],
    verbose=50
)

print("Evaluating model...")
y_pred = model.predict(X_test_sel)


print("\nClassification Report:")
# Names for classes: 0=Hold, 1=Buy, 2=Sell
target_names = ['Hold', 'Buy', 'Sell']
print(classification_report(y_test, y_pred, target_names=target_names))

print("Saving model...")
model_path = os.path.join(MODEL_DIR, 'merkava_xgboost_m1.json')
model.save_model(model_path)
print(f"Model saved to {model_path}")

# Feature importance plot
import plotly.express as px
importance = model.feature_importances_
imp_df = pd.DataFrame({'Feature': features, 'Importance': importance})
imp_df = imp_df.sort_values(by='Importance', ascending=True).tail(20)

fig = px.bar(imp_df, x='Importance', y='Feature', orientation='h', title='Top 20 Feature Importance')
fig.write_html('../data/processed/feature_importance.html')
print("Feature importance plot saved to data/processed/feature_importance.html")
