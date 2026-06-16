import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./clean_v10.py"], check=True, env=env)

with open('clean_v10.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Mi a helyzet a get_price_at_tick_offset-el?
# A history_prices-ból hátrafelé számol. Ha az "offset" 1000, akkor:
# idx = len(self.history_prices) - 1 - 1000
# Igen, ez pontos.

# Hogyan cserélődött a Volatilitás szorzó?
# vol = (raw_vol / current_price) * 100.0 if current_price > 0 else 0.01
# micro_sens mondjuk 0.02.
# vol_mult mondjuk 1.5.
# Ha a vol pl 0.1%, akkor dyn_micro_sens = 0.02 + 0.15 = 0.17%. Ezt írja ki a GUI-ra? Igen.

print("Kódszintű elemzés...")
import re
print("Regime String frissítés megvan-e:")
if 'regime_str += "Makro: UP<br>"' in content:
    print("YES")
