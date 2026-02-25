import os
import sys
import shutil
import zipfile
import subprocess

# Configuration
DRIVE_ID = "1HzG5Jzqq2UhxthYkBo2LB7MH--yYxDQr"
TARGET_DIR = "Knowledge_Base"
TEMP_ZIP = "ULTIMATE_RAG.zip"

def install_dependencies():
    print("🔧 Installing gdown...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown", "pandas", "faiss-cpu", "sentence-transformers"])

def download_rag():
    print(f"📥 Downloading ULTIMATE RAG (ID: {DRIVE_ID})...")
    import gdown
    url = f'https://drive.google.com/uc?id={DRIVE_ID}'
    gdown.download(url, TEMP_ZIP, quiet=False)

def extract_rag():
    print(f"📦 Extracting {TEMP_ZIP}...")
    with zipfile.ZipFile(TEMP_ZIP, 'r') as zip_ref:
        zip_ref.extractall(TARGET_DIR)

    # Check what we got
    print("📂 Extracted contents:")
    for root, dirs, files in os.walk(TARGET_DIR):
        for file in files:
            print(f"  - {os.path.join(root, file)}")

def main():
    print("=== 🚀 RESTORE ENV ULTIMATE (NEW RAG DEPLOYMENT) ===")

    try:
        install_dependencies()
        download_rag()
        extract_rag()

        # Cleanup
        if os.path.exists(TEMP_ZIP):
            os.remove(TEMP_ZIP)

        print("✅ ULTIMATE RAG Environment Restored Successfully.")
        print("Next Step: Run 'python3 swat_rag_query.py' to verify access to ML_Ops and Black_Ops.")

    except Exception as e:
        print(f"❌ Critical Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
