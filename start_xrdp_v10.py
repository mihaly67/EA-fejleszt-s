import subprocess
import os

env = os.environ.copy()
env["SSHPASS"] = "1104"
ssh_cmd = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88",
           "export DISPLAY=:10.0 && source /home/misi/ML_Ops/venv/bin/activate && cd /home/misi/Merkava_ML_Ops && python3 vaku3_offline_validator_VPS_V10.py > /tmp/vaku10.log 2>&1 & sleep 2"]

# Use Popen to not block
process = subprocess.Popen(ssh_cmd, env=env)
print("Elindítva a VPS háttérben.")
