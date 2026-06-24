import subprocess
import os
import time
env = os.environ.copy()
env["SSHPASS"] = "1104"

subprocess.run(["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "cat /tmp/vaku10.log | tail -n 30"], env=env)
