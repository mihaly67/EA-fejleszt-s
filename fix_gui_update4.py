import re
import os
import subprocess

env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "pkill -f vaku3_offline_validator_VPS_V10.py || true"], env=env)

subprocess.run(["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "export DISPLAY=:10.0 && source /home/misi/ML_Ops/venv/bin/activate && cd /home/misi/Merkava_ML_Ops && python3 vaku3_offline_validator_VPS_V10.py > /tmp/vaku10.log 2>&1 & sleep 2"], env=env)
