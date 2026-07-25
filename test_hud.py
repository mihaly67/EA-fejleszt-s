import sys
sys.path.append("Merkava_ML_Ops/src/dom")
from hud_logic_prep import get_dynamic_features
import pandas as pd
df = pd.DataFrame(columns=['30m_Close', 'OBI_ZScore', 'Price_Velocity', 'Dist_1m'])
print(get_dynamic_features(df))
