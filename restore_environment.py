import os
import sys
import shutil
import zipfile
import sqlite3
import logging
import warnings
import subprocess

# --- AUTO-INSTALL DEPENDENCIES ---
try:
    import gdown
except ImportError:
    print("⚠️ 'gdown' module not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])
    import gdown

# --- CONFIGURATION ---
# User-provided mappings:
# THEORY_RAG.zip  (Books)     -> 1T0etzQc1bdT89X67sa3zMbuZNZWM-Anv  -> RAM (Index+Data)
# CODEBASE_RAG.zip (Snippets) -> 1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI  -> DISK (MMAP)
# MQL5_DEV_RAG.zip (Articles) -> 1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy  -> DISK (MMAP)

DATABASES = {
    "rag_theory": {
        "id": "1T0etzQc1bdT89X67sa3zMbuZNZWM-Anv",
        "zip_name": "THEORY_RAG.zip",
        "check_file": "theory_knowledgebase.db",
        "mode": "MEMORY"
    },
    "rag_code": {
        "id": "1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI",
        "zip_name": "CODEBASE_RAG.zip",
        "check_file": "code_knowledgebase.db",
        "mode": "DISK"
    },
    "rag_mql5_dev": {
        "id": "1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy",
        "zip_name": "MQL5_DEV_RAG.zip",
        "check_file": "MQL5_DEV_knowledgebase.db",
        "mode": "DISK"
    }
}

# Directories to ignore in Git
GIT_IGNORE_DIRS = list(DATABASES.keys())

def setup_logger():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def clean_old_scripts():
    for f in ["setup_rag.sh", "jules_env_optimized_v1", "Jules_env251207"]:
        if os.path.exists(f):
            logging.info(f"Removing old script: {f}")
            os.remove(f)

def hoist_files(target_dir, check_file):
    """Moves files from subdirectories to target_dir if the check_file is nested."""
    # Find the check_file
    found_path = None
    for root, dirs, files in os.walk(target_dir):
        if check_file in files:
            found_path = os.path.join(root, check_file)
            break

    if not found_path:
        return False

    source_dir = os.path.dirname(found_path)
    if os.path.abspath(source_dir) == os.path.abspath(target_dir):
        return True # Already in place

    logging.info(f"Hoisting files from {source_dir} to {target_dir}")
    for item in os.listdir(source_dir):
        src_item = os.path.join(source_dir, item)
        dst_item = os.path.join(target_dir, item)
        if os.path.exists(dst_item):
            if os.path.isdir(dst_item):
                shutil.rmtree(dst_item)
            else:
                os.remove(dst_item)
        shutil.move(src_item, dst_item)

    return True

def restore_environment():
    setup_logger()
    print("=== ENVIRONMENT RESTORE & VERIFICATION ===")

    # 1. Clean old scripts
    clean_old_scripts()

    # 2. Process Databases
    for dir_name, config in DATABASES.items():
        print(f"\n--- Processing {dir_name} ({config['mode']}) ---")

        # Check if exists and valid
        is_installed = False
        if os.path.exists(dir_name):
            if os.path.exists(os.path.join(dir_name, config['check_file'])):
                print(f"✅ {dir_name} exists and seems valid.")
                is_installed = True
            else:
                print(f"⚠️ {dir_name} exists but is missing {config['check_file']}. Reinstalling...")
                shutil.rmtree(dir_name)

        if not is_installed:
            print(f"📥 Downloading {config['zip_name']}...")
            try:
                os.makedirs(dir_name, exist_ok=True)
                # Download to temp file
                gdown.download(id=config['id'], output=config['zip_name'], quiet=False, fuzzy=True)

                print(f"📦 Extracting {config['zip_name']}...")
                with zipfile.ZipFile(config['zip_name'], 'r') as z:
                    z.extractall(dir_name)

                # Hoist
                if not hoist_files(dir_name, config['check_file']):
                    print(f"❌ CRITICAL: {config['check_file']} not found in {config['zip_name']}!")
                    # Cleanup failed install
                    shutil.rmtree(dir_name)
                    continue

                # Cleanup Zip
                os.remove(config['zip_name'])
                print(f"✨ {dir_name} successfully installed.")

            except Exception as e:
                print(f"❌ Error installing {dir_name}: {e}")

    # 3. Update .gitignore
    print("\n📝 Updating .gitignore...")
    if os.path.exists(".gitignore"):
        with open(".gitignore", "r") as f:
            lines = f.readlines()
    else:
        lines = []

    existing_ignores = [l.strip().strip("/") for l in lines]
    changed = False
    for d in GIT_IGNORE_DIRS:
        if d not in existing_ignores:
            lines.append(f"{d}/\n")
            changed = True

    if changed:
        with open(".gitignore", "w") as f:
            f.writelines(lines)
        print("✅ .gitignore updated.")
    else:
        print("✅ .gitignore already up to date.")

    # 4. Handle "rag_mql5" -> "rag_mql5_dev" rename if old exists
    if os.path.exists("rag_mql5") and not os.path.exists("rag_mql5_dev"):
        print("🔄 Renaming legacy 'rag_mql5' to 'rag_mql5_dev'...")
        os.rename("rag_mql5", "rag_mql5_dev")

    print("\n🚀 Environment Restore Complete. Ready for work.")

if __name__ == "__main__":
    restore_environment()
