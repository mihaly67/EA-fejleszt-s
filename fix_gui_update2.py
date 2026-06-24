import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./clean_v10.py"], check=True, env=env)

with open('clean_v10.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Lehetséges, hogy a PyQt5 grafikon nem rajzolja újra magát megfelelően.
# Ellenőrizzük, miként történik a makro ER és Kockázat vonalak újrarajzolása
# A risk_data és macro_data listák (Ezek fix méretű numpy array-ek).
# Ha a max_points mondjuk 500, de a visszajátszás olyan gyors, hogy a plot nem frissül
# VAGY az új ablakméret (pl. macro=1000) megváltoztatásakor nem érvényesül azonnal az új trend,
# mivel a mac_er értékek "simítva" vannak az "alpha_er" szorzóval.
# A smoothed_er nagyon lassan követi az új beállítást.

old_alpha = """        alpha_er = 0.05
        alpha_risk = 0.1"""

new_alpha = """        # Ha valaki átállítja az érzékenységet, a smoothed értékek miatt nehezen reagálhat.
        # Gyorsítsuk a simítást, hogy reszponzívabb legyen a GUI:
        alpha_er = 0.15
        alpha_risk = 0.2"""
content = content.replace(old_alpha, new_alpha)

with open('clean_v10.py', 'w', encoding='utf-8') as f:
    f.write(content)

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "./clean_v10.py", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py"], check=True, env=env)
print("PATCH OK 2")
