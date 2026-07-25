import os
file_path = "Merkava_ML_Ops/src/dom/hud_logic_prep.py"

with open(file_path, "r") as f:
    content = f.read()

# Make sure 30m_Close and others are in ignore_cols
if "'30m_Close'" not in content:
    content = content.replace("'15m_Close',", "'15m_Close', '30m_Close',")

if "'Dist_1m'" not in content:
    content = content.replace("'1m_Close',", "'1m_Close', 'Dist_1m',")

with open(file_path, "w") as f:
    f.write(content)
