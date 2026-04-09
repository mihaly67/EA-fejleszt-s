import os
import sys
import shutil
import zipfile
import subprocess
import sqlite3

# --- 1. FÜGGŐSÉGEK TELEPÍTÉSE (AUTO-INSTALL) ---
def install_dependencies():
    print("🔧 Függőségek ellenőrzése és telepítése...")
    required = [
        "gdown",
        "faiss-cpu",
        "sentence-transformers",
        "numpy",
        "pandas",
        "colorama"
    ]
    for pkg in required:
        try:
            module_name = pkg
            if pkg == "sentence-transformers":
                module_name = "sentence_transformers"
            elif pkg == "faiss-cpu":
                module_name = "faiss"

            __import__(module_name.replace("-", "_"))
        except ImportError:
            print(f"   ⚠️ '{pkg}' hiányzik. Telepítés...")
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", pkg], stdout=subprocess.DEVNULL)
                print(f"   ✅ '{pkg}' telepítve.")
            except Exception as e:
                print(f"   ❌ Hiba a(z) '{pkg}' telepítésekor: {e}")

install_dependencies()

try:
    import gdown
    from colorama import Fore, Style, init
    init(autoreset=True)
except ImportError:
    class Fore: GREEN=""; RED=""; YELLOW=""; CYAN=""; RESET=""
    class Style: BRIGHT=""

# --- KONFIGURÁCIÓ ---
ENVIRONMENT_RESOURCES = {
    "VIDEO_PICTURE_RESTORATION_RAG": {
        "id": "1FQzexlqLs2HXj0VMnW-OYAfTREwJ1wI7",
        "file": "video_picture_restoration_RAG.zip",
        "extract_to": "Knowledge_Base/RAG_DB",
        "check_file": "video_picture_restoration_knowledge.db",
        "type": "zip",
        "preserve_dir": False
    }
}

def log(msg, color=Fore.GREEN):
    print(f"{color}{msg}{Style.RESET_ALL}")

def hoist_files(target_dir, check_file):
    if not check_file: return False

    found_path = None
    for root, dirs, files in os.walk(target_dir):
        if check_file in files:
            found_path = os.path.join(root, check_file)
            break
    if not found_path: return False

    source_dir = os.path.dirname(found_path)
    if os.path.abspath(source_dir) == os.path.abspath(target_dir): return True

    log(f"   ⬆️ Fájlok felmozgatása innen: {source_dir}", Fore.CYAN)
    for item in os.listdir(source_dir):
        try:
            shutil.move(os.path.join(source_dir, item), os.path.join(target_dir, item))
        except: pass

    try:
        if not os.listdir(source_dir):
            os.rmdir(source_dir)
    except: pass

    return True

def check_sqlite_integrity(db_path):
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        conn.close()
        return bool(tables)
    except sqlite3.Error:
        return False

def process_resource(key, config):
    print(f"\n🔧 Feldolgozás: {key}...")

    # Resolving absolute path relative to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    target_dir = os.path.join(script_dir, config.get("extract_to"))

    check_file = config.get("check_file")
    zip_name = os.path.join(script_dir, config["file"])
    drive_id = config["id"]
    preserve_dir = config.get("preserve_dir", False)

    check_path = os.path.join(target_dir, check_file) if check_file and target_dir else None

    # 1. Ellenőrzés: Létezik és ép?
    is_valid = False
    if check_path and os.path.exists(check_path):
        if check_path.endswith(".db") or check_path.endswith(".sqlite"):
            is_valid = check_sqlite_integrity(check_path)
        else:
            is_valid = os.path.getsize(check_path) > 1024

    if is_valid:
        log(f"   ✅ {key} rendben (Ellenőrizve).")
        return

    # Törlés és újraletöltés
    if check_path and os.path.exists(check_path) and not preserve_dir:
        log(f"   ⚠️ {key} sérült vagy érvénytelen. Törlés és újraletöltés...", Fore.YELLOW)
        try:
            if os.path.isdir(target_dir): shutil.rmtree(target_dir)
        except: pass
    elif not os.path.exists(target_dir):
        log(f"   ⚠️ {key} célkönyvtára ({target_dir}) nem létezik. Létrehozás...", Fore.YELLOW)

    # 2. Letöltés
    if not os.path.exists(zip_name):
        log(f"   📥 Letöltés: {config['file']} (ID: {drive_id})...", Fore.CYAN)
        try:
            gdown.download(id=drive_id, output=zip_name, quiet=False, fuzzy=True)
        except Exception as e:
            log(f"   ❌ Letöltési hiba: {e}", Fore.RED)
            return

    # 3. Kicsomagolás
    if target_dir:
        os.makedirs(target_dir, exist_ok=True)
        log(f"   📦 Kicsomagolás ide: {target_dir}...", Fore.CYAN)
        try:
            with zipfile.ZipFile(zip_name, 'r') as z:
                z.extractall(target_dir)

            if check_file:
                hoist_files(target_dir, check_file)
                final_check_path = os.path.join(target_dir, check_file)
                if not os.path.exists(final_check_path):
                     log(f"   ❌ Hiba: {check_file} nem található kicsomagolás után sem!", Fore.RED)
                else:
                     log(f"   ✨ {key} Sikeresen telepítve.", Fore.GREEN)

        except zipfile.BadZipFile:
            log("   ❌ Sérült Zip Fájl! Törlés...", Fore.RED)
            os.remove(zip_name)
        except Exception as e:
            log(f"   ❌ Kicsomagolási hiba: {e}", Fore.RED)
        finally:
            if os.path.exists(zip_name):
                os.remove(zip_name)

def main():
    print(f"{Fore.CYAN}=== 🚀 AI VIDEO/PICTURE RESTORATION RAG DEPLOYMENT ==={Style.RESET_ALL}")

    for key, config in ENVIRONMENT_RESOURCES.items():
        process_resource(key, config)

    print(f"\n{Fore.GREEN}✅ KÖRNYEZET KÉSZ. RAG RENDSZER AKTÍV.{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
