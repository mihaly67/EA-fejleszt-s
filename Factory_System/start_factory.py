#!/usr/bin/env python
import os
import sys
import subprocess
import time

def ensure_rag_data():
    print("[START]: Tudasbazisok ellenorzese...")
    try:
        import gdown, zipfile

        # 1. Alap RAG (Zip)
        links_zip = {
            'rag_theory': 'https://drive.google.com/uc?id=1UZgIItTO5a-Kspzdg2MozvqqiF16f3H3',
            'rag_code': 'https://drive.google.com/uc?id=1OM_4ucQj40PvWPRBajC6faMXktCvdRZq'
        }
        for k, v in links_zip.items():
            dest_dir = f'/tmp/{k}'
            if not os.path.exists(dest_dir):
                print(f'Downloading {k}...')
                gdown.download(v, f'/tmp/{k}.zip', quiet=True, fuzzy=True)
                print(f'Unzipping {k}...')
                os.makedirs(dest_dir, exist_ok=True)
                with zipfile.ZipFile(f'/tmp/{k}.zip', 'r') as z: z.extractall(dest_dir)
                os.remove(f'/tmp/{k}.zip')

        # 2. Kulso Folder Linkek (gdown --folder)
        # Ez bonyolultabb pythonbol, ezert subprocess hivas
        folder_links = {
            'new_knowledge': 'https://drive.google.com/drive/folders/1tBsbrW3ksozyLTFWsaEaXfk5FfjDEfeU?usp=sharing',
            'research_articles': 'https://drive.google.com/drive/folders/1wM3fsaqxBrKDVkV_eXgw8rkN03jxd1r8'
        }

        for k, url in folder_links.items():
            dest_dir = f'/tmp/{k}'
            if not os.path.exists(dest_dir):
                print(f'Downloading Folder {k}...')
                os.makedirs(dest_dir, exist_ok=True)
                # Keresunk egy gdown binarist vagy python modult
                cmd = [sys.executable, "-m", "gdown", "--folder", url, "--output", dest_dir, "--remaining-ok", "--fuzzy"]
                subprocess.run(cmd, check=False) # Nem dobunk hibat ha reszleges

                # Indexeles
                if k == 'new_knowledge' and os.path.exists("indexer.py"):
                    print(f"Indexing {k}...")
                    subprocess.run([sys.executable, "indexer.py"], check=False)
                if k == 'research_articles' and os.path.exists("indexer_articles.py"):
                    print(f"Indexing {k}...")
                    subprocess.run([sys.executable, "indexer_articles.py"], check=False)

    except Exception as e:
        print(f"[START]: HIBA a letoltesnel: {e}")

def start_manager():
    print("[START]: Project Manager inditasa...")
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
