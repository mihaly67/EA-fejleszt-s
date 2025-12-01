#!/usr/bin/env python
import os
import sys
import subprocess
import time

def ensure_rag_data():
    if os.path.exists("/tmp/rag_theory") and os.path.exists("/tmp/rag_code"):
        return

    print("[START]: RAG adatbazis letoltese /tmp-be...")
    try:
        import gdown, zipfile
        links = {
            'rag_theory': 'https://drive.google.com/uc?id=1UZgIItTO5a-Kspzdg2MozvqqiF16f3H3',
            'rag_code': 'https://drive.google.com/uc?id=1OM_4ucQj40PvWPRBajC6faMXktCvdRZq'
        }
        for k, v in links.items():
            dest_dir = f'/tmp/{k}'
            if not os.path.exists(dest_dir):
                print(f'Downloading {k}...')
                gdown.download(v, f'/tmp/{k}.zip', quiet=True, fuzzy=True)
                print(f'Unzipping {k}...')
                os.makedirs(dest_dir, exist_ok=True)
                with zipfile.ZipFile(f'/tmp/{k}.zip', 'r') as z: z.extractall(dest_dir)
                os.remove(f'/tmp/{k}.zip')
    except Exception as e:
        print(f"[START]: HIBA a letoltesnel: {e}")

def start_manager():
    print("[START]: Project Manager inditasa...")
    # Inditas hatterben, logolassal
    with open("factory.log", "a") as log:
        proc = subprocess.Popen(
            [sys.executable, "-u", "project_manager.py"],
            stdout=log,
            stderr=log
        )

    with open("factory.pid", "w") as f:
        f.write(str(proc.pid))

    print(f"[START]: Manager elindult. PID: {proc.pid}")

if __name__ == "__main__":
    ensure_rag_data()
    start_manager()
