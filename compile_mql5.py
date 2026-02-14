import os
import sys
import subprocess
import shutil

# --- CONFIGURATION ---
COMPILE_LOG = "compile.log"

def find_metaeditor(start_dir="."):
    """Dinamikusan megkeresi a metaeditor64.exe-t az alkönyvtárakban."""
    print(f"🔍 Keresés: metaeditor64.exe a '{start_dir}' alatt...")
    for root, dirs, files in os.walk(start_dir):
        if "metaeditor64.exe" in files:
            path = os.path.join(root, "metaeditor64.exe")
            print(f"✅ Megtalálva: {path}")
            return path
    return None

def compile_mql5(mq5_path):
    print(f"🔧 Fordítás előkészítése: {mq5_path}...")

    if not os.path.exists(mq5_path):
        print(f"❌ Hiba: Fájl nem található: {mq5_path}")
        return False

    # 1. MetaEditor Keresése
    metaeditor_path = find_metaeditor()
    if not metaeditor_path:
        print("❌ Hiba: metaeditor64.exe nem található a rendszerben!")
        return False

    # 2. Wine Ellenőrzése
    wine_cmd = shutil.which("wine")
    if not wine_cmd:
        print("⚠️ Figyelem: 'wine' parancs nem található. (Szimulációs Mód)")
        wine_available = False
    else:
        wine_available = True

    # 3. Xvfb Ellenőrzése (Opcionális)
    xvfb_cmd = shutil.which("xvfb-run")
    if xvfb_cmd:
        cmd_prefix = [xvfb_cmd, "-a"]
    else:
        cmd_prefix = []

    # 4. Parancs Összeállítása
    # wine metaeditor64.exe /portable /compile:"PATH" /log:"LOG"
    cmd = cmd_prefix + ["wine", metaeditor_path, "/portable", f"/compile:{mq5_path}", f"/log:{COMPILE_LOG}"]
    cmd_str = ' '.join(cmd)

    print(f"\n🚀 Generált Parancs:\n{cmd_str}\n")

    # 5. Futtatás vagy Szimuláció
    if wine_available:
        try:
            print("▶️ Végrehajtás...")
            subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            print(f"❌ Fordítási Hiba (Processz): {e}")
            return False
        except Exception as e:
            print(f"❌ Kivétel: {e}")
            return False

        # Log Ellenőrzése (Csak ha futott a wine)
        if os.path.exists(COMPILE_LOG):
            print("\n--- FORDÍTÁSI NAPLÓ ---")
            try:
                with open(COMPILE_LOG, 'r', encoding='utf-16') as f:
                    log_content = f.read()
                    print(log_content)
            except:
                 with open(COMPILE_LOG, 'r', encoding='utf-8', errors='ignore') as f:
                    log_content = f.read()
                    print(log_content)
            print("-----------------------")

            if "0 errors" in log_content:
                print("✅ SIKERES FORDÍTÁS!")
                return True
            else:
                print("❌ SIKERTELEN FORDÍTÁS.")
                return False
        else:
            print("⚠️ Figyelem: Nincs log fájl.")
            return False
    else:
        print("🛑 WINE hiányzik -> Parancs nem lett végrehajtva (Dry Run).")
        print("💡 Másold ki a fenti parancsot és futtasd Linuxon, ahol van Wine!")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Használat: python3 compile_mql5.py <mq5_fájl_útvonal>")
        sys.exit(1)

    mq5_path = sys.argv[1]
    compile_mql5(mq5_path)
