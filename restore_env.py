import os
import sys
import shutil
import zipfile
import logging
import subprocess
import json

# --- AUTO-INSTALL DEPENDENCIES ---
try:
    import gdown
except ImportError:
    print("⚠️ 'gdown' module not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])
    import gdown

# --- CONFIGURATION (ENVIRONMENT VARIABLES) ---
# Format: KEY = { "id": GoogleDriveID, "file": LocalFileName, "extract_to": TargetDir (Optional), "type": "zip/jsonl" }

ENVIRONMENT_RESOURCES = {
    "RAG_THEORY": {
        "id": "1T0etzQc1bdT89X67sa3zMbuZNZWM-Anv",
        "file": "THEORY_RAG.zip",
        "extract_to": "rag_theory",
        "check_file": "theory_knowledgebase.db"
    },
    "RAG_CODE": {
        "id": "1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI",
        "file": "CODEBASE_RAG.zip",
        "extract_to": "rag_code",
        "check_file": "code_knowledgebase.db"
    },
    "RAG_MQL5": {
        "id": "1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy",
        "file": "MQL5_DEV_RAG.zip",
        "extract_to": "rag_mql5_dev",
        "check_file": "MQL5_DEV_knowledgebase.db"
    },
    "GITHUB_CODEBASE_OLD": {
        "id": "1P_7FFJ2fIlAUJ45HofNJlFO5D1TaW908",
        "file": "codebase.zip",
        "extract_to": "github_codebase",
        "check_file": "knowledge_base_github.jsonl"
    },
    "THIEFS_LIBRARY": {
        "id": "1shtt-Q_O5nqg59jyHgRpg-Dc_8I7LxuU",
        "file": "knowledge_base_thiefs_library.zip",
        "extract_to": "Knowledge_Base",
        "check_file": "knowledge_base_thiefs_library.jsonl"
    }
}

# Local Zip for MT Libs
METATRADER_LIBS_ZIP = "Metatrader _beépitett_könyvtárak.zip"
METATRADER_JSONL_OUT = os.path.join("Knowledge_Base", "knowledge_base_mt_libs.jsonl")

def setup_logger():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def hoist_files(target_dir, check_file):
    """Moves files up if nested."""
    found_path = None
    for root, dirs, files in os.walk(target_dir):
        if check_file in files:
            found_path = os.path.join(root, check_file)
            break
    if not found_path: return False

    source_dir = os.path.dirname(found_path)
    if os.path.abspath(source_dir) == os.path.abspath(target_dir): return True

    print(f"   ⬆️ Hoisting files from {source_dir}")
    for item in os.listdir(source_dir):
        shutil.move(os.path.join(source_dir, item), os.path.join(target_dir, item))
    return True

def process_resource(key, config):
    print(f"\n🔧 Processing {key}...")

    target_dir = config.get("extract_to")
    check_file = config.get("check_file")
    zip_name = config["file"]
    drive_id = config["id"]

    # check if already installed
    if target_dir and os.path.exists(target_dir):
        if check_file and os.path.exists(os.path.join(target_dir, check_file)):
            print(f"   ✅ {key} is ready.")
            return

    # Download
    if not os.path.exists(zip_name):
        print(f"   📥 Downloading {zip_name} (ID: {drive_id})...")
        try:
            gdown.download(id=drive_id, output=zip_name, quiet=False, fuzzy=True)
        except Exception as e:
            print(f"   ❌ Download Failed: {e}")
            return

    # Extract
    if target_dir:
        os.makedirs(target_dir, exist_ok=True)
        print(f"   📦 Extracting to {target_dir}...")
        try:
            with zipfile.ZipFile(zip_name, 'r') as z:
                z.extractall(target_dir)

            # Verify and Hoist
            if check_file:
                if not hoist_files(target_dir, check_file):
                    print(f"   ⚠️ Warning: Check file {check_file} not found after extraction.")

            print(f"   ✨ {key} Installed.")
        except zipfile.BadZipFile:
            print("   ❌ Corrupted Zip File!")
        except Exception as e:
            print(f"   ❌ Extraction Error: {e}")
        finally:
            if os.path.exists(zip_name):
                os.remove(zip_name)

def process_mt_libs():
    print(f"\n🔧 Processing METATRADER_LIBS...")
    if not os.path.exists(METATRADER_LIBS_ZIP):
        print(f"   ⚠️ {METATRADER_LIBS_ZIP} missing.")
        return

    # Simple check based on file existence, rebuild if missing
    if os.path.exists(METATRADER_JSONL_OUT):
         print("   ✅ MT Libs JSONL exists.")
         return

    print("   🔨 Rebuilding MT Libs JSONL...")
    # (Simplified logic from previous scripts for brevity)
    # In a real scenario, we might want to ensure the rebuild_mt_libs logic is imported or copied here.
    # For now, let's assume if it's missing, we just skip or use a placeholder command.
    # To keep this script robust, I will include a minimal re-implementation.

    temp_dir = "temp_mt"
    os.makedirs(temp_dir, exist_ok=True)
    try:
        with zipfile.ZipFile(METATRADER_LIBS_ZIP, 'r') as z:
            z.extractall(temp_dir)

        os.makedirs(os.path.dirname(METATRADER_JSONL_OUT), exist_ok=True)
        with open(METATRADER_JSONL_OUT, 'w', encoding='utf-8') as f:
            for root, _, files in os.walk(temp_dir):
                for name in files:
                    if name.endswith(('.mq5', '.mqh')):
                        path = os.path.join(root, name)
                        try:
                            with open(path, 'r', errors='ignore') as rf:
                                content = rf.read()
                            f.write(json.dumps({
                                "filename": f"MT_LIB/{name}",
                                "code": content,
                                "source": "MT5_Standard"
                            }) + "\n")
                        except: pass
        print("   ✅ MT Libs Rebuilt.")
    finally:
        shutil.rmtree(temp_dir)

def sync_git():
    print("\n🔄 Git Sync...")
    try:
        subprocess.check_call(["git", "fetch", "--all"], stdout=subprocess.DEVNULL)
        subprocess.check_call(["git", "reset", "--hard", "origin/main"], stdout=subprocess.DEVNULL)
        print("   ✅ Synced to origin/main")
    except:
        print("   ⚠️ Git Sync Skipped/Failed")

def main():
    print("=== 🚀 RESTORE ENV v2.0 ===")

    # 1. Git
    sync_git()

    # 2. Iterate Configured Resources
    for key, config in ENVIRONMENT_RESOURCES.items():
        process_resource(key, config)

    # 3. Special Cases
    process_mt_libs()

    # 4. Generate .gitignore
    print("\n📝 Updating .gitignore...")
    ignores = set()
    if os.path.exists(".gitignore"):
        with open(".gitignore") as f:
            ignores = set(line.strip() for line in f if line.strip())

    new_ignores = {
        "__pycache__/", "*.zip", "github_codebase/", "Knowledge_Base/*.jsonl",
        "rag_theory/", "rag_code/", "rag_mql5_dev/"
    }

    if not new_ignores.issubset(ignores):
        with open(".gitignore", "a") as f:
            f.write("\n# Auto-generated by restore_env.py\n")
            for i in new_ignores - ignores:
                f.write(f"{i}\n")
        print("   ✅ .gitignore updated.")

    print("\n✅ Restore Complete.")

if __name__ == "__main__":
    main()
