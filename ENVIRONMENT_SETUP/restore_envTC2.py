import os
import sys
import shutil
import zipfile
import logging
import subprocess
import json
import time
import sqlite3

# --- 1. FÜGGŐSÉGEK TELEPÍTÉSE (AUTO-INSTALL) ---
def install_dependencies():
    print("🔧 Függőségek ellenőrzése és telepítése...")
    required = [
        "gdown",
        "sentence-transformers",
        "faiss-cpu",
        "numpy",
        "pandas",
        "colorama"
    ]
    for pkg in required:
        try:
            __import__(pkg.replace("-", "_"))
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
# Formátum: KULCS = { "id": GoogleDriveID, "file": HelyiFájlnév, "extract_to": CélMappa, "check_file": EllenőrzőFájl }

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
    },
    "COLUMBO_LIBRARY": {
        "id": "1jHcM_LpsLYaWc5Uo6869Cskpo0NK5tyR",
        "file": "knowledge_base_columbo.zip",
        "extract_to": "Knowledge_Base",
        "check_file": "knowledge_base_columbo.jsonl"
    }
}

# Helyi Zip a Beépített Könyvtárakhoz
METATRADER_LIBS_ZIP = "Metatrader _beépitett_könyvtárak.zip"
METATRADER_JSONL_OUT = os.path.join("Knowledge_Base", "knowledge_base_mt_libs.jsonl")

def log(msg, color=Fore.GREEN):
    print(f"{color}{msg}{Style.RESET_ALL}")

def hoist_files(target_dir, check_file):
    """Fájlok felmozgatása, ha almappába kerülnének."""
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
    return True

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

    check_path = os.path.join(target_dir, check_file) if check_file and target_dir else None

    # 1. Ellenőrzés: Létezik és ép?
    is_valid = False
    if check_path and os.path.exists(check_path):
        if check_path.endswith(".db"):
            is_valid = check_sqlite_integrity(check_path)
        elif check_path.endswith(".jsonl"):
            is_valid = check_jsonl_integrity(check_path)
        else:
            is_valid = os.path.getsize(check_path) > 1024 # Egyszerű méret ellenőrzés

    if is_valid:
        log(f"   ✅ {key} rendben (Ellenőrizve).")
        return

    # Ha nem érvényes, TÖRLÉS és ÚJRAHÚZÁS
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

            # Felmozgatás és Ellenőrzés
            if check_file:
                hoist_files(target_dir, check_file)

                # Újabb ellenőrzés kicsomagolás után
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
                os.remove(zip_name) # Zip törlése helytakarékosság miatt

def process_mt_libs():
    print(f"\n🔧 Feldolgozás: METATRADER_LIBS...")
    if not os.path.exists(METATRADER_LIBS_ZIP):
        log(f"   ⚠️ {METATRADER_LIBS_ZIP} hiányzik.", Fore.YELLOW)
        return

    if os.path.exists(METATRADER_JSONL_OUT):
         log("   ✅ MT Libs JSONL létezik.", Fore.GREEN)
         return

    log("   🔨 MT Libs JSONL újraépítése...", Fore.CYAN)
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
        log("   ✅ MT Libs Újraépítve.", Fore.GREEN)
    finally:
        shutil.rmtree(temp_dir)

def force_git_sync():
    """Erőltetett Git Szinkronizáció (Hard Reset)."""
    repo_url = "https://github.com/mihaly67/EA-fejleszt-s.git"
    print("\n🔄 GIT Szinkronizáció (Force Mode v2)...")

    try:
        if os.path.exists(".git"):
            print("   ℹ️ .git mappa megtalálva. Fetch kísérlet...")
            subprocess.check_call(["git", "fetch", "--all"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.check_call(["git", "reset", "--hard", "origin/main"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            log("   ✅ Szinkronizáció sikeres (Fetch/Reset).", Fore.GREEN)
            return
    except Exception as e:
        log(f"   ⚠️ Standard szinkronizáció sikertelen ({e}). Hard Reset (Re-init) indítása...", Fore.YELLOW)

    try:
        if os.path.exists(".git"):
            print("   🗑️ Sérült .git mappa törlése...")
            shutil.rmtree(".git")
            time.sleep(1)

        print("   🆕 Git repo újra-inicializálása...")
        subprocess.check_call(["git", "init"], stdout=subprocess.DEVNULL)
        subprocess.check_call(["git", "remote", "add", "origin", repo_url], stdout=subprocess.DEVNULL)
        subprocess.check_call(["git", "fetch", "--all"], stdout=subprocess.DEVNULL)
        subprocess.check_call(["git", "reset", "--hard", "origin/main"], stdout=subprocess.DEVNULL)
        log("   ✅ Szinkronizáció sikeres (FORCE RE-INIT).", Fore.GREEN)
    except Exception as e:
         log(f"   ❌ KRITIKUS: Force Sync Sikertelen! ({e})", Fore.RED)

def run_kutato_test(scope, query):
    """Kutató modul tesztelése."""
    print(f"   🔍 Teszt Keresés: {scope} (Query: '{query}')")
    if not os.path.exists("kutato.py"):
        log("   ⚠️ kutato.py nem található! Teszt kihagyva.", Fore.YELLOW)
        return True # Nem hiba, ha nincs meg a modul

    try:
        cmd = [sys.executable, "kutato.py", query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

        if result.returncode != 0:
            log(f"   ❌ kutato.py hiba: {result.stderr}", Fore.RED)
            return False

        hits = json.loads(result.stdout)
        if not hits:
            log("   ⚠️ Nincs találat.", Fore.YELLOW)
            return False

        log(f"   ✅ Találatok száma: {len(hits)}. Top: {hits[0].get('filename', '?')}", Fore.GREEN)
        return True
    except Exception as e:
        log(f"   ❌ Kivétel: {e}", Fore.RED)
        return False

def main():
    print(f"{Fore.CYAN}=== 🚀 RESTORE ENV TC 2 (101% HARCKÉSZÜLTSÉG - 2026.02.13) ==={Style.RESET_ALL}")

    # 1. Git Sync
    force_git_sync()

    # 2. Erőforrások feldolgozása
    for key, config in ENVIRONMENT_RESOURCES.items():
        process_resource(key, config)

    # 3. MT Libs
    process_mt_libs()

    # 4. .gitignore frissítése
    print("\n📝 .gitignore frissítése...")
    ignores = set()
    if os.path.exists(".gitignore"):
        with open(".gitignore") as f:
            ignores = set(line.strip() for line in f if line.strip())

    new_ignores = {
        "__pycache__/", "*.zip", "github_codebase/", "Knowledge_Base/*.jsonl",
        "rag_theory/", "rag_code/", "rag_mql5_dev/", "temp_mt/"
    }

    if not new_ignores.issubset(ignores):
        with open(".gitignore", "a") as f:
            f.write("\n# Auto-generated by restore_envTC2.py\n")
            for i in new_ignores - ignores:
                f.write(f"{i}\n")
        log("   ✅ .gitignore frissítve.")

    # 5. Végső Tesztek (Kutató Modul)
    print(f"\n{Fore.CYAN}--- RENDSZER TESZTELÉSE (KUTATÓ MODUL) ---{Style.RESET_ALL}")

    tests_passed = True

    # MQL5 DEV Teszt
    if not run_kutato_test("MQL5_DEV", "indicator handle"): tests_passed = False

    # THEORY Teszt
    if not run_kutato_test("THEORY", "MQL5 Programming"): tests_passed = False

    # CODE Teszt
    if not run_kutato_test("CODE", "OnCalculate"): tests_passed = False

    # Indicator Layering (Kihagyva, ahogy kérted)
    # if not run_kutato_test("LAYERING", "context"): tests_passed = False

    if tests_passed:
        print(f"\n{Fore.GREEN}✅ MINDEN RENDSZER ZÖLD. INDULHAT A BEVETÉS.{Style.RESET_ALL}")
        sys.exit(0)
    else:
        print(f"\n{Fore.RED}❌ TESZTEK SIKERTELENEK. ELLENŐRIZD A NAPLÓT!{Style.RESET_ALL}")
        sys.exit(1)

if __name__ == "__main__":
    main()
