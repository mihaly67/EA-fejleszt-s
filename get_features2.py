import joblib
model = joblib.load("models/lgbm_model_3MTF_v2_asym.pkl")
print("Model features:", model.booster_.feature_name())
