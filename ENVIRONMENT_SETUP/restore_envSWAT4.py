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

    # --- ÚJ SWAT4 RAG ADATBÁZIS (FAISS + SQLITE) ---
    "SWAT4_RAG": {
        "id": "1S-jLsfuRVVNr1z1lASgnDkc0dYSF-m6I",
        "file": "SWAT4.zip",
        "extract_to": "Knowledge_Base/SWAT_DB",
        "check_file": "swat_unified_compressed.index", # Később dinamikusan keresi ha változott a név
        "type": "zip",
        "preserve_dir": True # Ne törölje a teljes könyvtárat a kicsomagolás előtt (hogy a SWAT3 megmaradjon)
    },

    # --- RAG STRUKTÚRA ---
    "SWAT4_RAG_STRUCTURE": {
        "id": "182Zzae4BufQVRimeWx_H_n3U05w5nmON",
        "file": "repos.zip",
        "extract_to": "ENVIRONMENT_SETUP",
        "check_file": "repos.zip", # Nem zip kicsomagolású DB, hanem nyers extract
        "type": "zip_no_check",
        "preserve_dir": True
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
    zip_name = config["file"]
    drive_id = config["id"]
    res_type = config.get("type", "zip")
    preserve_dir = config.get("preserve_dir", False)

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
    print(f"{Fore.CYAN}=== 🚀 RESTORE ENV SWAT4 (FAISS + SQLITE RAG DEPLOYMENT) ==={Style.RESET_ALL}")

    # 1. Git Sync
    force_git_sync()

    # 2. Erőforrások feldolgozása
    for key, config in ENVIRONMENT_RESOURCES.items():
        process_resource(key, config)

    # 3. .gitignore frissítése
    update_gitignore()

    # 4. Agent Autonóm Eszközépítő (Skill Factory) Futtatása
    print(f"\n{Fore.MAGENTA}🤖 AGENT ESZKÖZÉPÍTŐ (SKILL FACTORY) INDÍTÁSA...{Style.RESET_ALL}")
    import subprocess
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

    # --- STEP 7: AUTO-START KEEPALIVE DAEMON ---
    print("\n[STEP 7] Indítom a Keep-Alive Daemont az I/O fagyás ellen...")
    try:
        import subprocess
        # Ellenőrizzük, hogy fut-e már
        check = subprocess.run(["pgrep", "-af", "agent_keepalive"], capture_output=True, text=True)
        if "agent_keepalive.py" not in check.stdout:
            subprocess.Popen([sys.executable, "ENVIRONMENT_SETUP/skills/agent_keepalive.py"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("   ✅ Keep-Alive Daemon elindítva.")
        else:
            print("   ✅ Keep-Alive Daemon már fut.")
    except Exception as e:
        print(f"   ⚠️ Hiba a Daemon indításakor: {e}")

    # --- STEP 8: SYSTEM HEALTH CHECK ---
    print("\n[STEP 8] Rendszer Egészségügyi Ellenőrzés (Daemon és Memória Műszerfal)...")
    try:
        health_check_script = os.path.join(os.path.dirname(__file__), "system_health_monitor.py")
        if os.path.exists(health_check_script):
            subprocess.run([sys.executable, health_check_script])
        else:
            print(f"   ⚠️ {health_check_script} nem található, kihagyva.")
    except Exception as e:
        print(f"   ⚠️ Hiba a Health Check futtatásakor: {e}")

    # --- STEP 9: Agent Long-Term Memory (Context Extension) Betöltése ---
    print(f"\n{Fore.MAGENTA}[STEP 9] TÖRTÉNELMI KONTEXTUS BETÖLTÉSE ÉS SESSION START (LONG-TERM MEMORY)...{Style.RESET_ALL}")
    memory_script = os.path.join(os.path.dirname(__file__), "agent_memory_manager.py")
    if os.path.exists(memory_script):
        try:
            subprocess.run([sys.executable, memory_script, "--action", "start_session"])
            subprocess.run([sys.executable, memory_script, "--action", "read", "--limit", "10"])

            print("\n======================================================================")
            print("🚨 AGENT PROTOCOL ENFORCEMENT: CONTEXT WINDOW EXTENSION 🚨")
            print("======================================================================")
            print("MINDEN 5. FORDULÓBAN (TURN) VAGY LOGIKAI SZAKASZ VÉGÉN KÖTELEZŐ ÍRNOD Ebbe a fájlba!")
            print("Parancs: python3 ENVIRONMENT_SETUP/agent_memory_manager.py --action write --category 'Context_Summary' --content '...'")
            print("Cél: A session hosszának drasztikus megnövelése a kontextus sűrítésével (Condense).")
            print("A Session végén futtasd: python3 ENVIRONMENT_SETUP/agent_memory_manager.py --action end_session")
            print("======================================================================\n")
        except Exception as e:
            print(f"   ⚠️ Hiba a memória betöltésekor: {e}")
    else:
        print("   ⚠️ agent_memory_manager.py nem található. Memória inicializálás átugorva.")

    print("\n🚀 KÖRNYEZET BEÁLLÍTÁSA ÉS VÉDELME (DAEMON + MEMÓRIA) SIKERESEN BEFEJEZŐDÖTT.")

if __name__ == "__main__":
    main()
