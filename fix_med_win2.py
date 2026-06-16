import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"
subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./clean_v10.py"], check=True, env=env)

with open('clean_v10.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Úgy tűnik az elző diffben a med_window_ms megmaradt a get_price_at_time hívásnál.
content = content.replace('med_start_price = self.get_price_at_time(current_time, med_window_ms)', 'med_start_price = self.get_price_at_tick_offset(med_window_ticks)')

with open('clean_v10.py', 'w', encoding='utf-8') as f:
    f.write(content)

subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "./clean_v10.py", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py"], check=True, env=env)

# Újraindítjuk a VPS-en
ssh_cmd_kill = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "pkill -f vaku3_offline_validator_VPS_V10.py || true"]
subprocess.run(ssh_cmd_kill, env=env)

ssh_cmd_start = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "export DISPLAY=:10.0 && source /home/misi/ML_Ops/venv/bin/activate && cd /home/misi/Merkava_ML_Ops && python3 vaku3_offline_validator_VPS_V10.py > /tmp/vaku10.log 2>&1 & sleep 2"]
subprocess.Popen(ssh_cmd_start, env=env)
