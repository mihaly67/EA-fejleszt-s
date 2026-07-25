import os

file_path = "Merkava_ML_Ops/src/dom/visualize_decisions.py"
with open(file_path, "r") as f:
    content = f.read()

content = content.replace("from hud_logic_prep import get_dynamic_features\n    features = get_dynamic_features(df)", """from hud_logic_prep import get_dynamic_features
    features = get_dynamic_features(df)

    # Biztonsági szűrés: csak azokat a feature-öket kérjük, amik tényleg benne vannak a df-ben
    features = [f for f in features if f in df.columns]""")

with open(file_path, "w") as f:
    f.write(content)
