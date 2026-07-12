import os
import subprocess

def push_file(local_path, remote_path):
    with open(local_path, "r") as f:
        content = f.read()

    content = content.replace("'", "'\\''")
    cmd = f"cat << 'EOF_INTERNAL' > {remote_path}\n{content}\nEOF_INTERNAL"

    ssh_cmd = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", cmd]
    env = os.environ.copy()

    try:
        subprocess.run(ssh_cmd, check=True, env=env)
        print(f"✅ {local_path} feltöltve.")
    except Exception as e:
        print(f"❌ Hiba {local_path}: {e}")

push_file("dom_feature_engineer.py", "/home/misi/Merkava_ML_Ops/dom_feature_engineer.py")
push_file("dom_train_pipeline.py", "/home/misi/Merkava_ML_Ops/dom_train_pipeline.py")
push_file("dom_inference_exam.py", "/home/misi/Merkava_ML_Ops/dom_inference_exam.py")
push_file("run_pipeline.py", "/home/misi/Merkava_ML_Ops/run_pipeline.py")

print("\n>>> VPS PIPELINE INDÍTÁSA...\n")
run_cmd = ["sshpass", "-e", "ssh", "-o", "StrictHostKeyChecking=no", "misi@5.189.163.88", "cd /home/misi/Merkava_ML_Ops && python3 run_pipeline.py"]
subprocess.run(run_cmd, env=os.environ.copy())
