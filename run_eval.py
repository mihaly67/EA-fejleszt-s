import subprocess

out = subprocess.run(["python3", "vps_bridge.py", "cd /home/misi/Merkava_ML_Ops && source venv/bin/activate && PYTHONPATH=. python3 vaku3_hybrid_engine.py"], capture_output=True, text=True)
print(out.stdout)
