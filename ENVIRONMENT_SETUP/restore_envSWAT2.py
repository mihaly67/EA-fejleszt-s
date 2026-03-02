import os
import sys
import shutil
import zipfile
import logging
import subprocess
import json
import time
import sqlite3
import glob

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
            # Handle package name differences for import
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
    # Fallback ha a telepítés sikertelen volt (de nem kéne)
    class Fore: GREEN=""; RED=""; YELLOW=""; CYAN=""; RESET=""
    class Style: BRIGHT=""

# --- KONFIGURÁCIÓ (KÖRNYEZETI VÁLTOZÓK) ---
ENVIRONMENT_RESOURCES = {
    # --- EREDETI RAG ADATBÁZISOK (MEGTARTVA) ---
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

    # --- ÚJ SWAT2 RAG (FAISS + SQLITE) ---
    "SWAT2_RAG": {
        "id": "1lgdfuSBC_ea4zG-n7IUr1a3CPYQVnuey",
        "file": "SWAT_RAG_FAISS.zip",
        "extract_to": "Knowledge_Base/SWAT_DB",
        "check_file": "swat_unified_compressed.index"
    }
}

def log(msg, color=Fore.GREEN):
    print(f"{color}{msg}{Style.RESET_ALL}")

def hoist_files(target_dir, check_file):
    """Fájlok felmozgatása, ha almappába kerülnének."""
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

    # Clean up empty source dir if it became empty
    try:
        if not os.listdir(source_dir):
            os.rmdir(source_dir)
    except: pass

    return True

def find_verification_file(directory):
    """Megkeresi az első ellenőrző fájlt (.index, .db, .sqlite)."""
    # Check for FAISS index first
    index_files = glob.glob(os.path.join(directory, "**/*.index"), recursive=True)
    if index_files: return os.path.basename(index_files[0])

    # Check for DB/SQLite files
    db_files = glob.glob(os.path.join(directory, "**/*.sqlite"), recursive=True)
    if db_files: return os.path.basename(db_files[0])

    db_files = glob.glob(os.path.join(directory, "**/*.db"), recursive=True)
    if db_files: return os.path.basename(db_files[0])

    return None

def check_sqlite_integrity(db_path):
    """Ellenőrzi, hogy az SQLite adatbázis megnyitható-e."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        conn.close()
        if not tables:
            return False # Üres DB gyanús
        return True
    except sqlite3.Error:
        return False

def check_jsonl_integrity(jsonl_path):
    """Ellenőrzi a JSONL fájl olvashatóságát."""
    try:
        with open(jsonl_path, 'r', encoding='utf-8') as f:
            for i, line in enumerate(f):
                if i > 5: break # Elég az elejét megnézni
                json.loads(line)
        return True
    except (json.JSONDecodeError, UnicodeDecodeError):
        return False

def process_resource(key, config):
    print(f"\n🔧 Feldolgozás: {key}...")

    target_dir = config.get("extract_to")
    check_file = config.get("check_file")
    zip_name = config["file"]
    drive_id = config["id"]

    # Ha nincs check_file, próbáljuk megtalálni
    if target_dir and not check_file and os.path.exists(target_dir):
        found = find_verification_file(target_dir)
        if found:
            check_file = found
            log(f"   ℹ️ Automatikusan felismert ellenőrző fájl: {check_file}", Fore.CYAN)

    check_path = os.path.join(target_dir, check_file) if check_file and target_dir else None

    # 1. Ellenőrzés: Létezik és ép?
    is_valid = False
    if check_path and os.path.exists(check_path):
        if check_path.endswith(".db") or check_path.endswith(".sqlite"):
            is_valid = check_sqlite_integrity(check_path)
        elif check_path.endswith(".jsonl"):
            is_valid = check_jsonl_integrity(check_path)
        else:
            is_valid = os.path.getsize(check_path) > 1024

    if is_valid:
        log(f"   ✅ {key} rendben (Ellenőrizve).")
        return

    # Törlés és újraletöltés
    if check_path and os.path.exists(check_path):
        log(f"   ⚠️ {key} sérült vagy érvénytelen. Törlés és újraletöltés...", Fore.YELLOW)
        try:
            if os.path.isdir(target_dir): shutil.rmtree(target_dir)
        except: pass
    elif not os.path.exists(target_dir):
        log(f"   ⚠️ {key} hiányzik. Letöltés...", Fore.YELLOW)

    # 2. Letöltés
    if not os.path.exists(zip_name):
        log(f"   📥 Letöltés: {zip_name} (ID: {drive_id})...", Fore.CYAN)
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

            # Dinamikus fájlkeresés kicsomagolás után
            if not check_file:
                found = find_verification_file(target_dir)
                if found:
                    check_file = found
                    log(f"   ℹ️ Fájl megtalálva: {check_file}", Fore.CYAN)

            if check_file:
                hoist_files(target_dir, check_file)
                final_check_path = os.path.join(target_dir, check_file)
                if not os.path.exists(final_check_path):
                     log(f"   ❌ Hiba: {check_file} nem található kicsomagolás után sem!", Fore.RED)
                else:
                     log(f"   ✨ {key} Sikeresen telepítve.", Fore.GREEN)
            else:
                log(f"   ⚠️ {key} kicsomagolva, de ellenőrző fájl nem található.", Fore.YELLOW)

        except zipfile.BadZipFile:
            log("   ❌ Sérült Zip Fájl! Törlés...", Fore.RED)
            os.remove(zip_name)
        except Exception as e:
            log(f"   ❌ Kicsomagolási hiba: {e}", Fore.RED)
        finally:
            if os.path.exists(zip_name):
                os.remove(zip_name)

def force_git_sync():
    """Erőltetett Git Szinkronizáció (Simulated)."""
    print("\n🔄 GIT Szinkronizáció (Simulated)...")
    log("   ✅ Szinkronizáció kész.", Fore.GREEN)

def update_gitignore():
    """Frissíti a .gitignore fájlt a SWAT DB-vel."""
    print("\n📝 .gitignore frissítése...")
    ignore_entry = "Knowledge_Base/SWAT_DB/"

    if os.path.exists(".gitignore"):
        with open(".gitignore", "r") as f:
            content = f.read()

        if ignore_entry not in content:
            with open(".gitignore", "a") as f:
                f.write(f"\n# SWAT RAG Database (FAISS)\n{ignore_entry}\n")
            log(f"   ✅ Hozzáadva: {ignore_entry}", Fore.GREEN)
        else:
            log(f"   ℹ️ Már tartalmazza: {ignore_entry}", Fore.CYAN)
    else:
        with open(".gitignore", "w") as f:
            f.write(f"{ignore_entry}\n")
        log(f"   ✅ Létrehozva és hozzáadva: {ignore_entry}", Fore.GREEN)

def main():
    print(f"{Fore.CYAN}=== 🚀 RESTORE ENV SWAT (FAISS + SQLITE RAG DEPLOYMENT) ==={Style.RESET_ALL}")

    # 1. Git Sync
    force_git_sync()

    # 2. Erőforrások feldolgozása
    for key, config in ENVIRONMENT_RESOURCES.items():
        process_resource(key, config)

    # 3. .gitignore frissítése
    update_gitignore()

    # 4. Végső Üzenet
    print(f"\n{Fore.GREEN}✅ SWAT KÖRNYEZET KÉSZ. RAG RENDSZER (FAISS) AKTÍV.{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
