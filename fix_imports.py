import re

with open("vaku3_offline_validator_VPS_new.py", "r", encoding="utf-8") as f:
    content = f.read()

# Make sure the import is at the top of the file
if "from sklearn.preprocessing import StandardScaler" not in content[:500]:
    content = "from sklearn.preprocessing import StandardScaler\n" + content

with open("vaku3_offline_validator_VPS_new.py", "w", encoding="utf-8") as f:
    f.write(content)
