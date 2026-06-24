import os
import shutil
import zipfile
import requests
import sys

# CONFIGURATION - UPDATE THIS LINK AFTER UPLOADING TO DRIVE
KNOWLEDGE_VAULT_URL = "PLACEHOLDER_DRIVE_LINK_FOR_JULES_KNOWLEDGE_VAULT_ZIP"

def download_file(url, dest_path):
    if "PLACEHOLDER" in url:
        print("⚠️  Knowledge Vault Link is missing. Skipping download.")
        return False

    print(f"📥 Downloading Knowledge Vault from {url}...")
    try:
        # Handle Google Drive confirm=t logic if needed, simple wget for now
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            with open(dest_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=1024):
                    if chunk:
                        f.write(chunk)
            print("✅ Download complete.")
            return True
        else:
            print(f"❌ Failed to download. Status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error downloading: {e}")
        return False

def extract_vault(zip_path, extract_to):
    print(f"📦 Extracting {zip_path} to {extract_to}...")
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        print("✅ Extraction successful.")
    except Exception as e:
        print(f"❌ Error extracting: {e}")

def main():
    print("=== KNOWLEDGE VAULT RESTORE ===")

    kb_dir = "Knowledge_Base"
    zip_path = "Jules_Knowledge_Vault.zip"

    if not os.path.exists(kb_dir):
        os.makedirs(kb_dir)

    # Check if we have the zip locally (from git) or need to download
    if not os.path.exists(zip_path):
        if not download_file(KNOWLEDGE_VAULT_URL, zip_path):
            print("⚠️  Could not restore Knowledge Vault. Proceeding without it.")
            return

    extract_vault(zip_path, ".")

    print("\n📚 Knowledge Base Status:")
    for f in os.listdir(kb_dir):
        if f.endswith(".jsonl"):
            size = os.path.getsize(os.path.join(kb_dir, f)) / (1024*1024)
            print(f"   - {f}: {size:.2f} MB")

if __name__ == "__main__":
    main()
