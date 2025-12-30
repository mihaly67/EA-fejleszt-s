import os
import sys
import shutil
import zipfile
import sqlite3
import logging
import warnings
import subprocess
import json
import glob

# --- AUTO-INSTALL DEPENDENCIES ---
try:
    import gdown
except ImportError:
    print("⚠️ 'gdown' module not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])
    import gdown

# --- CONFIGURATION ---
# RAG Databases
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

# External Codebases
GITHUB_CODEBASE = {
    "dir": "github_codebase",
    "id": "1P_7FFJ2fIlAUJ45HofNJlFO5D1TaW908",
    "zip_name": "codebase.zip",
    "check_file": "external_codebase.jsonl"
}

# Local Assets to Process
METATRADER_LIBS_ZIP = "Metatrader _beépitett_könyvtárak.zip"
METATRADER_JSONL_OUT = os.path.join("Knowledge_Base", "metatrader_libraries.jsonl")

# Directories to ignore in Git
GIT_IGNORE_DIRS = list(DATABASES.keys()) + ["github_codebase", "downloaded_content"]

def setup_logger():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def clean_old_scripts():
    for f in ["setup_rag.sh", "jules_env_optimized_v1", "Jules_env251207"]:
        if os.path.exists(f):
            logging.info(f"Removing old script: {f}")
            os.remove(f)

def hoist_files(target_dir, check_file):
    """Moves files from subdirectories to target_dir if the check_file is nested."""
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

def report_hardware_status():
    print("\n📊 === HARDWARE STATUS REPORT ===")
    try:
        total, used, free = shutil.disk_usage(".")
        print(f"💾 Disk Usage: Used: {used // (2**30)} GB / Total: {total // (2**30)} GB (Free: {free // (2**30)} GB)")
    except Exception as e:
        print(f"⚠️ Error reading Disk info: {e}")

    try:
        with open('/proc/meminfo', 'r') as f:
            mem_info = {}
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    mem_info[parts[0].strip()] = int(parts[1].strip().split()[0])

            total_ram = mem_info.get('MemTotal', 0) / 1024
            available_ram = mem_info.get('MemAvailable', 0) / 1024
            used_ram = total_ram - available_ram
            print(f"🧠 RAM Usage: Used: {used_ram:.2f} MB / Total: {total_ram:.2f} MB (Available: {available_ram:.2f} MB)")
    except FileNotFoundError:
        print("⚠️ Could not read /proc/meminfo (Not Linux?)")
    except Exception as e:
        print(f"⚠️ Error reading RAM info: {e}")

def verify_rag_functionality():
    print("\n🔎 === RAG FUNCTIONALITY TEST (Comprehensive) ===")

    if not os.path.exists("kutato.py"):
        print("❌ CRITICAL: 'kutato.py' not found! Cannot verify RAG.")
        return

    def test_scope(scope_name, display_name, query):
        print(f"\n👉 Testing Scope: {display_name} (Query: '{query}')")
        try:
            result = subprocess.run(
                [sys.executable, "kutato.py", query, "--scope", scope_name, "--json"],
                capture_output=True,
                text=True,
                timeout=45
            )

            if result.returncode != 0:
                print(f"   ❌ Execution Failed: {result.stderr.strip()}")
                return False

            try:
                hits = json.loads(result.stdout)
                if isinstance(hits, list) and len(hits) > 0:
                    top_hit = hits[0]
                    title = top_hit.get('filename', 'Unknown')
                    snippet = top_hit.get('content', '')[:100].replace('\n', ' ')
                    print(f"   ✅ Success! Found {len(hits)} hits.")
                    print(f"   📄 Top Hit: {title}")
                    print(f"   📝 Snippet: {snippet}...")
                    return True
                else:
                    print(f"   ⚠️ No hits found.")
                    return False
            except json.JSONDecodeError:
                print(f"   ⚠️ Invalid JSON output: {result.stdout.strip()[:100]}...")
                return False

        except subprocess.TimeoutExpired:
            print(f"   ❌ Timeout.")
            return False
        except Exception as e:
            print(f"   ❌ Exception: {e}")
            return False

    # Test MQL5 (MQL5_DEV_RAG)
    test_scope('MQL5', 'MQL5_DEV_RAG', 'indicator handle')

    # Test Theory (THEORY_RAG)
    test_scope('THEORY', 'THEORY_RAG', 'market microstructure')

    # Test Code (CODEBASE_RAG)
    test_scope('CODE', 'CODEBASE_RAG', 'OnCalculate')

def process_metatrader_libs():
    print("\n📚 === PROCESSING METATRADER LIBRARIES ===")

    zip_path = METATRADER_LIBS_ZIP
    jsonl_path = METATRADER_JSONL_OUT

    if not os.path.exists(zip_path):
        print(f"⚠️ {zip_path} not found. Skipping library processing.")
        return

    if os.path.exists(jsonl_path):
        print(f"✅ {jsonl_path} already exists. Skipping.")
        return

    print(f"📦 Extracting {zip_path} to build JSONL...")
    temp_dir = "temp_mt_libs"
    os.makedirs(temp_dir, exist_ok=True)

    try:
        with zipfile.ZipFile(zip_path, 'r') as z:
            z.extractall(temp_dir)

        print(f"📝 Writing to {jsonl_path}...")
        os.makedirs(os.path.dirname(jsonl_path), exist_ok=True)

        count = 0
        with open(jsonl_path, 'w', encoding='utf-8') as outfile:
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    if file.lower().endswith(('.mq5', '.mqh', '.py', '.txt', '.md')):
                        filepath = os.path.join(root, file)
                        try:
                            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()

                            rel_path = os.path.relpath(filepath, temp_dir)

                            record = {
                                "filename": f"METATRADER_LIB/{rel_path}",
                                "code": content,
                                "source": "Metatrader_Libraries_Zip"
                            }
                            outfile.write(json.dumps(record) + '\n')
                            count += 1
                        except Exception as e:
                            print(f"   ⚠️ Failed to read {file}: {e}")

        print(f"✅ Successfully processed {count} files into {jsonl_path}.")

    except Exception as e:
        print(f"❌ Error processing libs: {e}")
    finally:
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)

def process_github_codebase():
    """Scans github_codebase dir and creates external_codebase.jsonl."""
    print("\n🐙 === PROCESSING GITHUB CODEBASE ===")

    base_dir = GITHUB_CODEBASE["dir"]
    jsonl_path = os.path.join(base_dir, GITHUB_CODEBASE["check_file"])

    if not os.path.exists(base_dir):
        print(f"⚠️ {base_dir} not found. Skipping.")
        return

    if os.path.exists(jsonl_path):
        # Optional: check if empty?
        if os.path.getsize(jsonl_path) > 1024:
            print(f"✅ {jsonl_path} already exists. Skipping.")
            return
        else:
             print(f"⚠️ {jsonl_path} exists but is too small. Rebuilding...")

    print(f"📝 Scanning {base_dir} to build JSONL...")

    valid_exts = {'.mq5', '.mqh', '.py', '.js', '.ts', '.jsx', '.tsx', '.css', '.html', '.md', '.txt', '.json', '.cs'}
    skip_dirs = {'node_modules', '.git', '.next', 'dist', 'build', '__pycache__', 'obj', 'bin'}

    count = 0
    try:
        with open(jsonl_path, 'w', encoding='utf-8') as outfile:
            for root, dirs, files in os.walk(base_dir):
                # Filter directories
                dirs[:] = [d for d in dirs if d not in skip_dirs]

                for file in files:
                    ext = os.path.splitext(file)[1].lower()
                    if ext in valid_exts:
                        filepath = os.path.join(root, file)

                        # Skip the jsonl itself if encountered
                        if os.path.abspath(filepath) == os.path.abspath(jsonl_path):
                            continue

                        try:
                            # Skip large files > 1MB
                            if os.path.getsize(filepath) > 1 * 1024 * 1024:
                                continue

                            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()

                            rel_path = os.path.relpath(filepath, base_dir)

                            record = {
                                "filename": f"GITHUB_REPO/{rel_path}",
                                "code": content,
                                "source": "Github_Codebase_Zip"
                            }
                            outfile.write(json.dumps(record) + '\n')
                            count += 1
                        except Exception as e:
                            # logging.warning(f"Failed to read {file}: {e}")
                            pass

        print(f"✅ Successfully processed {count} files into {jsonl_path}.")

    except Exception as e:
        print(f"❌ Error processing github codebase: {e}")


def restore_github_codebase():
    print(f"\n--- Processing GitHub Codebase ---")
    cfg = GITHUB_CODEBASE
    target_dir = cfg['dir']
    check_file_path = os.path.join(target_dir, cfg['check_file'])

    # Check if folder exists
    if not os.path.exists(target_dir):
        print(f"📥 Downloading {cfg['zip_name']}...")
        try:
            os.makedirs(target_dir, exist_ok=True)
            gdown.download(id=cfg['id'], output=cfg['zip_name'], quiet=False, fuzzy=True)

            print(f"📦 Extracting {cfg['zip_name']}...")
            with zipfile.ZipFile(cfg['zip_name'], 'r') as z:
                z.extractall(target_dir)

            os.remove(cfg['zip_name'])
            print(f"✨ {target_dir} downloaded.")
        except Exception as e:
             print(f"❌ Error installing codebase: {e}")
    else:
        print(f"✅ {target_dir} exists.")

    # Always try to generate the JSONL if missing
    process_github_codebase()


def restore_environment():
    setup_logger()
    print("=== ENVIRONMENT RESTORE & VERIFICATION ===")

    # 1. Clean
    clean_old_scripts()

    # 2. Process RAG Databases
    for dir_name, config in DATABASES.items():
        print(f"\n--- Processing {dir_name} ({config['mode']}) ---")

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
                gdown.download(id=config['id'], output=config['zip_name'], quiet=False, fuzzy=True)

                print(f"📦 Extracting {config['zip_name']}...")
                with zipfile.ZipFile(config['zip_name'], 'r') as z:
                    z.extractall(dir_name)

                if not hoist_files(dir_name, config['check_file']):
                    print(f"❌ CRITICAL: {config['check_file']} not found in {config['zip_name']}!")
                    shutil.rmtree(dir_name)
                    continue

                os.remove(config['zip_name'])
                print(f"✨ {dir_name} successfully installed.")

            except Exception as e:
                print(f"❌ Error installing {dir_name}: {e}")

    # 3. Process Github Codebase
    restore_github_codebase()

    # 4. Process Metatrader Libraries
    process_metatrader_libs()

    # 5. Update .gitignore
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

    # Explicitly verify jsonl ignores
    if "Knowledge_Base/*.jsonl" not in [l.strip() for l in lines]:
        lines.append("Knowledge_Base/*.jsonl\n")
        changed = True
    if "github_codebase/*.jsonl" not in [l.strip() for l in lines]:
        lines.append("github_codebase/*.jsonl\n")
        changed = True

    if changed:
        with open(".gitignore", "w") as f:
            f.writelines(lines)
        print("✅ .gitignore updated.")
    else:
        print("✅ .gitignore already up to date.")

    # 6. Legacy Rename
    if os.path.exists("rag_mql5") and not os.path.exists("rag_mql5_dev"):
        print("🔄 Renaming legacy 'rag_mql5' to 'rag_mql5_dev'...")
        os.rename("rag_mql5", "rag_mql5_dev")

    # 7. Hardware & Tests
    report_hardware_status()
    verify_rag_functionality()

    print("\n🚀 Environment Restore Complete. Ready for work.")

if __name__ == "__main__":
    restore_environment()
