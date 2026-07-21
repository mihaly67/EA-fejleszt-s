# This script documents the preparation steps for the ML logic
# In a real model, the output uses Predict_Proba for [0, 1, 2] corresponding to [Noise, Long, Short]
# Signal = P_Long - P_Short. If P_Zero > threshold, Signal = 0.
