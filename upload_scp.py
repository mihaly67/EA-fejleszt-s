import os
import subprocess

VPS_PWD = os.environ.get("VPS_PWD")

def push_file(local_path, remote_path):
    cmd = ["sshpass", "-e", "scp", "-o", "StrictHostKeyChecking=no", local_path, f"misi@5.189.163.88:{remote_path}"]
    env = os.environ.copy()
    env["SSHPASS"] = VPS_PWD
    try:
        subprocess.run(cmd, check=True, env=env)
        print(f"✅ {local_path} feltöltve.")
    except Exception as e:
        print(f"❌ Hiba: {e}")

push_file("dom_feature_engineer.py", "/home/misi/Merkava_ML_Ops/dom_feature_engineer.py")
push_file("dom_train_pipeline.py", "/home/misi/Merkava_ML_Ops/dom_train_pipeline.py")
push_file("dom_inference_exam.py", "/home/misi/Merkava_ML_Ops/dom_inference_exam.py")
push_file("run_pipeline.py", "/home/misi/Merkava_ML_Ops/run_pipeline.py")

print("\n>>> VPS PIPELINE INDÍTÁSA...\n")
run_cmd = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "cd /home/misi/Merkava_ML_Ops && python3 run_pipeline.py"]
env = os.environ.copy()
env["SSHPASS"] = VPS_PWD
subprocess.run(run_cmd, env=env)
