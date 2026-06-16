import subprocess
import os

env = os.environ.copy()
env["SSHPASS"] = "1104"
subprocess.run(["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88:/home/misi/Merkava_ML_Ops/vaku3_offline_validator_VPS_V10.py", "./vaku3_offline_validator_VPS_V10.py"], check=True, env=env)
