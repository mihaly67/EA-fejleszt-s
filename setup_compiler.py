import os
import sys
import shutil
import zipfile
import subprocess

# --- AUTO-INSTALL DEPENDENCIES ---
try:
    import gdown
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])
    import gdown

MT5_ZIP_ID = "1-FXaBgsGtpYMZGxY3FU-y_fZiit8Uefz"
MT5_ZIP_NAME = "MT5_Portable.zip"
MT5_DIR = "MT5_Portable"

def install_mt5():
    print(f"📥 Letöltés: {MT5_ZIP_NAME} (ID: {MT5_ZIP_ID})...")
    if not os.path.exists(MT5_ZIP_NAME):
        try:
            gdown.download(id=MT5_ZIP_ID, output=MT5_ZIP_NAME, quiet=False, fuzzy=True)
        except Exception as e:
            print(f"❌ Letöltési hiba: {e}")
            return False

    print(f"📦 Kicsomagolás ide: {MT5_DIR}...")
    if os.path.exists(MT5_DIR):
        shutil.rmtree(MT5_DIR)
    os.makedirs(MT5_DIR, exist_ok=True)

    try:
        with zipfile.ZipFile(MT5_ZIP_NAME, 'r') as z:
            z.extractall(MT5_DIR)
        print("✅ MT5 Portable Telepítve (Kicsomagolva).")
        return True
    except Exception as e:
        print(f"❌ Kicsomagolási hiba: {e}")
        return False
    finally:
        if os.path.exists(MT5_ZIP_NAME):
            os.remove(MT5_ZIP_NAME)

if __name__ == "__main__":
    install_mt5()
