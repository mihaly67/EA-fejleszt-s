import os
import subprocess
import zipfile
import shutil

# Install gdown if needed
try:
    import gdown
except ImportError:
    subprocess.check_call(["pip", "install", "gdown"])
    import gdown

DATA_DIR = "analysis_input"
os.makedirs(DATA_DIR, exist_ok=True)

FILES = {
    "session_bad": {
        "id": "1apd_WQJ5RSyqrIoXxO6G5zaX1fEggv6o", # First link
        "filename": "bad_data.zip",
        "extract_to": "session_bad"
    },
    "session_better": {
        "id": "19z4K9lFr857gXuHyqd8-HEXIn23oxnaD", # Second link
        "filename": "better_data.zip",
        "extract_to": "session_better"
    }
}

def fetch_and_extract():
    for name, config in FILES.items():
        print(f"Downloading {name}...")
        zip_path = os.path.join(DATA_DIR, config["filename"])

        try:
            gdown.download(id=config["id"], output=zip_path, quiet=False, fuzzy=True)
        except Exception as e:
            print(f"Failed to download {name}: {e}")
            continue

        extract_path = os.path.join(DATA_DIR, config["extract_to"])
        os.makedirs(extract_path, exist_ok=True)

        print(f"Extracting to {extract_path}...")
        try:
            with zipfile.ZipFile(zip_path, 'r') as z:
                z.extractall(extract_path)
            print("Done.")
        except Exception as e:
            print(f"Failed to extract {name}: {e}")

        # Cleanup zip
        if os.path.exists(zip_path):
            os.remove(zip_path)

if __name__ == "__main__":
    fetch_and_extract()
