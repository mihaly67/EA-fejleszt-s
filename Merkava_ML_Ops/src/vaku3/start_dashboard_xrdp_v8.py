import subprocess
import os

env = os.environ.copy()
env['DISPLAY'] = ':10.0'

print("Műszerfal V8 indítása az XRDP képernyőn (Display :10.0)...")
try:
    subprocess.Popen(
        ["/home/misi/Merkava_ML_Ops/venv/bin/python3", "/home/misi/Merkava_ML_Ops/vaku3_dashboard.py"],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    print("Siker! A VAKU 3.0 Műszerfal V8 megjelent a távoli asztalodon!")
except Exception as e:
    print(f"Hiba: {e}")
