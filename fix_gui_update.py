import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./clean_v10.py"], check=True, env=env)

with open('clean_v10.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Lehetséges, hogy a GUI frissítés nem veszi figyelembe az új szöveget, mert a fókusz elvétele vagy az enter leütése hiányzik,
# de a get_safe_float minden ticknél beolvassa a qlineedit.text() értékét.
# Egy másik ok, hogy a qlineedit tartalma egy "0,03" vesszős formátumban érkezik a lokalizáció miatt, amit a float() dob.
# Nézzük meg a get_safe_float-ot.
old_safe = """    def get_safe_float(self, qlineedit, default_val):
        try:
            return float(qlineedit.text())
        except ValueError:
            return default_val"""

new_safe = """    def get_safe_float(self, qlineedit, default_val):
        try:
            val_str = qlineedit.text().replace(',', '.')
            return float(val_str)
        except Exception:
            return default_val"""
content = content.replace(old_safe, new_safe)

# És egy másik lehetséges bug, hogy az ER logikánál be van égetve a v9 makro_sens-e
# Megnézem, hogy az analyze_time_based_trend meghívásakor passzoljuk-e a dolgokat

with open('clean_v10.py', 'w', encoding='utf-8') as f:
    f.write(content)

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "./clean_v10.py", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py"], check=True, env=env)
print("PATCH OK")
