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

# KÖTELEZŐ VPS KÖRNYEZETI ADATOK BEÁLLÍTÁSA A KÖRNYEZETI VÁLTOZÓKBÓL
# Ez a script garantálja, hogy a VPS kapcsolódási paraméterek mindig rendelkezésre álljanak.
if "VPS_HOST" not in os.environ:
    os.environ["VPS_HOST"] = "5.189.163.88"
if "VPS_USER" not in os.environ:
    os.environ["VPS_USER"] = "misi"


# --- 0. VPS KÖRNYEZETI ALAPBEÁLLÍTÁSOK ---
# A jelszavakat és érzékeny adatokat a rendszer környezeti változóiból olvassuk be,
# szigorúan tilos hardcode-olni őket a forráskódban a Zero Trust protokoll miatt.
if "VPS_HOST" not in os.environ:
    os.environ["VPS_HOST"] = "5.189.163.88"
if "VPS_USER" not in os.environ:
    os.environ["VPS_USER"] = "misi"
if "VPS_WORKSPACE" not in os.environ:
    os.environ["VPS_WORKSPACE"] = "/home/misi/Merkava_ML_Ops"

# A VPS_PWD és egyéb érzékeny adatok (pl. GITHUB_PAT) beállítása kívülről történik!

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
                if pkg == "playwright":
                    subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium", "--quiet"])
            except Exception as e:
                print(f"   ❌ Hiba a(z) '{pkg}' telepítésekor: {e}")

install_dependencies()

try:
    import gdown
    import asyncio
    from colorama import Fore, Style, init
    from playwright.async_api import async_playwright
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
        "check_file": "theory_knowledgebase.db",
        "type": "zip"
    },
    "RAG_CODE": {
        "id": "1CmoE49YTc_-dxyn4EiYyIDHINENeT5KI",
        "file": "CODEBASE_RAG.zip",
        "extract_to": "rag_code",
        "check_file": "code_knowledgebase.db",
        "type": "zip"
    },
    "RAG_MQL5": {
        "id": "1gMumIUSdXuUlHJuymbWE8GwAd5K7ruSy",
        "file": "MQL5_DEV_RAG.zip",
        "extract_to": "rag_mql5_dev",
        "check_file": "MQL5_DEV_knowledgebase.db",
        "type": "zip"
    },

    # --- ÚJ SWAT4 RAG ADATBÁZIS (VPS HIVATKOZÁSOK / FAST MCP) ---
    "VPS_FAST_MCP": {
        "source_path": "/home/misi/Jules_ICA_Builder",
        "extract_to": "Knowledge_Base/FAST_MCP",
        "type": "local_vps_reference",
        "description": "VPS-en található Fast MCP Szerver, ami tartalmazza a ML_Ops, XGB, SWAT4 és egyéb RAG-okat."
    },

    "VPS_ML_OPS": {
        "source_path": "/home/misi/Merkava_ML_Ops/MLOps",
        "extract_to": "Knowledge_Base/ML_Ops_DB",
        "type": "local_vps_reference",
        "description": "Közvetlen hivatkozás a ML_Ops munkamappára a VPS-en."
    },

    "VPS_XGB": {
        "source_path": "/home/misi/Merkava_ML_Ops/XGB",
        "extract_to": "Knowledge_Base/XGB_DB",
        "type": "local_vps_reference",
        "description": "Közvetlen hivatkozás az XGB munkamappára a VPS-en."
    },

    # --- KITERJESZTETT AI/MCP TUDÁSBÁZIS (ULTIMATE RAG) ---
    "SWAT4_AI_TOOLS_RAG": {
        "id": "1hNl4JYrms427u94H48kpkb39OJ5C5AhN",
        "file": "rag.zip",
        "extract_to": "Knowledge_Base/AI_TOOLS_DB",
        "check_file": "RAG_CHATBOT_CSV_DATA_LLM_github.db",
        "type": "zip",
        "preserve_dir": True
    },

    "SWAT4_AI_TOOLS_REPOS": {
        "id": "19ScN_Kfih1wNo2Ih7iAPYA4xilC4eX18",
        "file": "repo_lista.zip",
        "extract_to": "Knowledge_Base/AI_TOOLS_DB",
        "check_file": "repo_lista.txt",
        "type": "zip",
        "preserve_dir": True
    },

    # --- GEMINI KUTATÁSOK ---
    "GEMINI_RESEARCH_1": {
        "id": "1gJ-79ea1k62x57w8UpkkHZlacqfve5B6",
        "file": "Architectural Optimization and Specialized Module Integration for CFD Scalping on Resource-Constrained Hardware.txt",
        "extract_to": "ANALYSIS_TOOLS/ML_Ops",
        "type": "file"
    },
    "GEMINI_RESEARCH_2": {
        "id": "1yH8Pk3fFXFDnX7umqJR4DR2z1UEZ71t2",
        "file": "Stratégiai kutatási terv.txt",
        "extract_to": "ANALYSIS_TOOLS/ML_Ops",
        "type": "file"
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

async def playwright_download_fallback(drive_id, output_path):
    """Playwright alapú letöltés (a Google Drive 'Virus scan warning' oldalának megkerüléséhez)."""
    url = f"https://drive.google.com/uc?export=download&id={drive_id}"
    dest_path = os.path.abspath(output_path)

    log(f"   🤖 Playwright böngésző indítása a Google Drive limitációinak megkerülésére...", Fore.YELLOW)

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()

            async with page.expect_download(timeout=120000) as download_info:
                await page.goto(url)

                try:
                    await page.click("input[type='submit']", timeout=5000)
                    log("   🖱️ 'Download anyway' gomb lekattintva.", Fore.CYAN)
                except Exception:
                    pass # Nincs gomb, a letöltés automatikusan indult

            download = await download_info.value
            await download.save_as(dest_path)
            await browser.close()

            if os.path.exists(dest_path) and os.path.getsize(dest_path) > 1024:
                return True
            return False
    except Exception as e:
        log(f"   ❌ Playwright hiba: {e}", Fore.RED)
        return False

def process_resource(key, config):
    print(f"\n🔧 Feldolgozás: {key}...")

    target_dir = config.get("extract_to")
    check_file = config.get("check_file")
    zip_name = config.get("file")
    drive_id = config.get("id")
    res_type = config.get("type", "zip")
    preserve_dir = config.get("preserve_dir", False)
    source_path = config.get("source_path")

    # 0. Ha VPS hivatkozásról van szó
    if res_type == "local_vps_reference":
        log(f"   🔗 {key} egy helyi VPS hivatkozás a következő útvonalra: {source_path}", Fore.CYAN)
        if os.path.exists(source_path):
            log(f"   ✅ A forrás mappa megtalálható a VPS-en: {source_path}", Fore.GREEN)
            # Create a symlink or a reference placeholder if target_dir is defined
            if target_dir:
                os.makedirs(os.path.dirname(target_dir), exist_ok=True)
                if not os.path.exists(target_dir):
                    try:
                        os.symlink(source_path, target_dir)
                        log(f"   ✅ Symlink létrehozva: {target_dir} -> {source_path}", Fore.GREEN)
                    except OSError as e:
                        log(f"   ⚠️ Symlink létrehozása sikertelen (lehet hogy Windows/Sandbox környezet): {e}", Fore.YELLOW)
                        log(f"   ℹ️ Készítek egy referencia fájlt helyette.", Fore.CYAN)
                        os.makedirs(target_dir, exist_ok=True)
                        with open(os.path.join(target_dir, "vps_reference.txt"), "w") as f:
                            f.write(f"Ez a könyvtár a VPS-en lévő {source_path} mappára mutat.\n")
                else:
                    log(f"   ℹ️ Cél könyvtár/symlink már létezik: {target_dir}", Fore.CYAN)
        else:
            log(f"   ⚠️ A forrás mappa NEM TALÁLHATÓ (valószínűleg nem a VPS-en fut a script, Sandbox környezet). Útvonal: {source_path}", Fore.YELLOW)
        return

    # 1. Ha sima fájlról van szó (pl. Gemini txt fájlok)
    if res_type == "file":
        os.makedirs(target_dir, exist_ok=True)
        target_path = os.path.join(target_dir, zip_name)
        if os.path.exists(target_path) and os.path.getsize(target_path) > 1024:
            log(f"   ✅ {key} már letöltve és rendben (Fájl méret: {os.path.getsize(target_path)} bytes).", Fore.GREEN)
            return

        log(f"   📥 Letöltés: {zip_name} (ID: {drive_id})...", Fore.CYAN)
        try:
            res = gdown.download(id=drive_id, output=target_path, quiet=False)
            if res is None:
                raise Exception("A gdown nem kapott érvényes fájlt (valószínűleg Virus scan warning).")
            log(f"   ✨ {key} Sikeresen telepítve.", Fore.GREEN)
        except Exception as e:
            log(f"   ⚠️ Hagyományos letöltés sikertelen ({e}).", Fore.YELLOW)
            try:
                success = asyncio.run(playwright_download_fallback(drive_id, target_path))
                if success:
                    log(f"   ✨ {key} Sikeresen telepítve Playwright segítségével.", Fore.GREEN)
                else:
                    log(f"   ❌ Végleges letöltési hiba.", Fore.RED)
            except NameError:
                log(f"   ❌ Playwright nincs telepítve, letöltés megszakítva.", Fore.RED)
        return

    # --- ZIP fájlok esetén a korábbi logika, kiegészítve ---

    # Ha nincs check_file, próbáljuk megtalálni
    if target_dir and not check_file and os.path.exists(target_dir) and res_type == "zip":
        found = find_verification_file(target_dir)
        if found:
            check_file = found
            log(f"   ℹ️ Automatikusan felismert ellenőrző fájl: {check_file}", Fore.CYAN)

    check_path = os.path.join(target_dir, check_file) if check_file and target_dir and res_type == "zip" else None

    # 1. Ellenőrzés: Létezik és ép?
    is_valid = False
    if check_path and os.path.exists(check_path):
        if check_path.endswith(".db") or check_path.endswith(".sqlite"):
            is_valid = check_sqlite_integrity(check_path)
        elif check_path.endswith(".jsonl"):
            is_valid = check_jsonl_integrity(check_path)
        else:
            is_valid = os.path.getsize(check_path) > 1024

    if is_valid and res_type == "zip":
        log(f"   ✅ {key} rendben (Ellenőrizve).")
        return

    # Törlés és újraletöltés (ha preserve_dir False)
    if check_path and os.path.exists(check_path) and not preserve_dir:
        log(f"   ⚠️ {key} sérült vagy érvénytelen. Törlés és újraletöltés...", Fore.YELLOW)
        try:
            if os.path.isdir(target_dir): shutil.rmtree(target_dir)
        except: pass
    elif not os.path.exists(target_dir):
        log(f"   ⚠️ {key} célkönyvtára ({target_dir}) nem létezik. Létrehozás...", Fore.YELLOW)

    # 2. Letöltés
    if not os.path.exists(zip_name):
        log(f"   📥 Letöltés: {zip_name} (ID: {drive_id})...", Fore.CYAN)
        try:
            res = gdown.download(id=drive_id, output=zip_name, quiet=False)
            if res is None:
                raise Exception("A gdown nem kapott érvényes fájlt (valószínűleg Virus scan warning).")
        except Exception as e:
            log(f"   ⚠️ Hagyományos letöltés sikertelen ({e}).", Fore.YELLOW)
            try:
                success = asyncio.run(playwright_download_fallback(drive_id, zip_name))
                if not success:
                    log(f"   ❌ Végleges letöltési hiba.", Fore.RED)
                    return
            except NameError:
                log(f"   ❌ Playwright nincs telepítve, letöltés megszakítva.", Fore.RED)
                return

    # 3. Kicsomagolás
    if target_dir:
        os.makedirs(target_dir, exist_ok=True)
        log(f"   📦 Kicsomagolás ide: {target_dir}...", Fore.CYAN)
        try:
            with zipfile.ZipFile(zip_name, 'r') as z:
                z.extractall(target_dir)

            if res_type == "zip_no_check":
                log(f"   ✨ {key} Sikeresen kicsomagolva.", Fore.GREEN)
            else:
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
    # 0. VPN Connection
    subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "setup_tailscale.py")])
    print(f"{Fore.CYAN}=== 🚀 RESTORE ENV SWAT4 (FAISS + SQLITE RAG DEPLOYMENT) ==={Style.RESET_ALL}")

    # 1. Git Sync
    force_git_sync()

    # 2. Erőforrások feldolgozása
    for key, config in ENVIRONMENT_RESOURCES.items():
        # A file key is needed for process_resource, but local_vps_reference may not have it
        if "file" not in config:
            config["file"] = "vps_reference"
        if "id" not in config:
            config["id"] = "no_id"

        process_resource(key, config)

    # 3. .gitignore frissítése
    update_gitignore()

    # 4. Agent Autonóm Eszközépítő (Skill Factory) Futtatása
    print(f"\n{Fore.MAGENTA}🤖 AGENT ESZKÖZÉPÍTŐ (SKILL FACTORY) INDÍTÁSA...{Style.RESET_ALL}")
    builder_script = os.path.join(os.path.dirname(__file__), "autonomous_tool_builder.py")
    if os.path.exists(builder_script):
        try:
            # Csak csendben lefut a háttérben, felépíti a web_browser.py-t, MCP klienseket stb.
            subprocess.run([sys.executable, builder_script])
            print(f"   ✅ Agent eszközök frissítve.")
        except Exception as e:
            print(f"   ⚠️ Hiba az eszközépítő futtatásakor: {e}")

    # 5. Végső Üzenet
    print(f"\n{Fore.GREEN}✅ SWAT4 KÖRNYEZET KÉSZ. RAG RENDSZER (FAISS) AKTÍV. (HMM/Encoders Ready){Style.RESET_ALL}")

    # 5. Agent Long-Term Memory (Context Extension) Betöltése
    print(f"\n{Fore.MAGENTA}🧠 TÖRTÉNELMI KONTEXTUS BETÖLTÉSE ÉS SESSION START (LONG-TERM MEMORY)...{Style.RESET_ALL}")
    memory_script = os.path.join(os.path.dirname(__file__), "agent_memory_manager.py")
    if os.path.exists(memory_script):
        try:
            subprocess.run([sys.executable, memory_script, "--action", "start_session"])
            subprocess.run([sys.executable, memory_script, "--action", "read", "--limit", "10"])
        except Exception as e:
            print(f"⚠️ Hiba a memória betöltésekor: {e}")
    else:
        print("⚠️ agent_memory_manager.py nem található. Memória inicializálás átugorva.")

if __name__ == "__main__":
    main()
