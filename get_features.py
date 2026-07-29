import pandas as pd
import lightgbm as lgb
model = lgb.Booster(model_file="models/lgbm_model_3MTF_v2_asym.pkl")
print("Model features:", model.feature_name())
