# Verify local shape of the model to ensure our dummy data exactly matches what predict_proba gets
import joblib
import pandas as pd

features = [
    'Tick_Speed', 'Micro_Trend', 'Macro_Trend', 'Imbalance_L1', 'Imbalance_L2',
    'Imbalance_L3', 'Imbalance_L4', 'Imbalance_L5', 'Imbalance_L6',
    'Imbalance_L7', 'Imbalance_L8', 'Imbalance_L9', 'Imbalance_L10',
    'CVD_Raw', 'CVD_Rolling_10', 'Cancel_Rate_Rolling_10',
    'Trade_Size_Imbalance', 'Spread_ZScore',
    'ATR_Micro', 'Velocity_Micro',
    'Dist_Micro_R', 'Dist_Micro_S',
    'Dist_Sec_R', 'Dist_Sec_S',
    'Dist_Ter_R', 'Dist_Ter_S',
    'Stoch_State_M1',
    'Upper_Wick_ATR', 'Lower_Wick_ATR'
]
df = pd.DataFrame([{f: 0.0 for f in features}])
print("Shape required:", df.shape)
