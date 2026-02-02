import os
import sys
import zipfile
import json
import shutil
import subprocess
import time

# --- CONFIGURATION ---
DRIVE_ID = "1VV28T71DsJ4aEfQs8PcyOKTd8S39nNcI"
MASTER_ZIP_NAME = "repos_master.zip"
OUTPUT_JSONL = "knowledge_base_thiefs_library.jsonl"
EXISTING_MT_LIB = os.path.join("Knowledge_Base", "knowledge_base_mt_libs.jsonl")
FINAL_ARTIFACT_ZIP = "Jules_Knowledge_Vault_v2.zip"

# Filtering Configuration
VALID_EXTENSIONS = {
    '.py', '.pyx', '.pxd',       # Python
    '.mq5', '.mqh',              # MQL5
    '.cpp', '.c', '.h', '.hpp',  # C++
    '.rs',                       # Rust (Nautilus)
    '.md', '.rst', '.txt',       # Docs
    '.json', '.yaml', '.yml',    # Config
    '.ipynb'                     # Notebooks (common in FinRL)
}

IGNORE_DIRS = {
    '__pycache__', 'node_modules', '.git', '.github', 'dist', 'build',
    'venv', 'env', '.idea', '.vscode', 'target', 'bin', 'obj'
}

MAX_FILE_SIZE_BYTES = 1 * 1024 * 1024  # 1 MB

def install_gdown():
    """Ensures gdown is installed."""
    try:
        import gdown
    except ImportError:
        print("⚠️ 'gdown' not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "gdown"])

def download_file(file_id, output_path):
    """Downloads file from Google Drive using gdown."""
    import gdown
    if os.path.exists(output_path):
        os.remove(output_path)

    print(f"📥 Downloading Drive ID: {file_id} -> {output_path}")
    # using fuzzy=True to handle potential redirect issues or name mismatches
    output = gdown.download(id=file_id, output=output_path, quiet=False, fuzzy=True)

    if not output or not os.path.exists(output_path):
        raise Exception("Download failed or file not found.")
    return output_path

def is_text_file(filepath):
    """Checks if a file is text (not binary)."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            f.read(1024)
        return True
    except UnicodeDecodeError:
        return False
    except Exception:
        return False

def process_directory_to_jsonl(source_dir, jsonl_handle, repo_name):
    """Walks a directory and appends file contents to the open JSONL file handle."""
    count = 0
    skipped = 0

    print(f"   🔎 Scanning {source_dir}...")

    for root, dirs, files in os.walk(source_dir):
        # Modify dirs in-place to skip ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext not in VALID_EXTENSIONS:
                continue

            filepath = os.path.join(root, file)

            # Size check
            try:
                if os.path.getsize(filepath) > MAX_FILE_SIZE_BYTES:
                    skipped += 1
                    continue
            except OSError:
                continue

            # Content check
            if not is_text_file(filepath):
                skipped += 1
                continue

            try:
                with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()

                # Relative path for the knowledge base
                # Format: REPO_NAME/path/to/file
                rel_path = os.path.relpath(filepath, source_dir)
                full_virtual_path = f"{repo_name}/{rel_path}"

                record = {
                    "filename": full_virtual_path,
                    "code": content,
                    "source": f"Repo_Zip_{repo_name}"
                }

                jsonl_handle.write(json.dumps(record) + "\n")
                count += 1

            except Exception as e:
                print(f"   ❌ Error reading {file}: {e}")

    print(f"   ✅ Processed {count} files (Skipped {skipped} binary/large).")
    return count

def main():
    print("=== 🚀 TURBO RESCUE SCRIPT STARTED ===")
    start_time = time.time()

    # 1. Install Dependencies
    install_gdown()

    # 2. Download Master Zip
    try:
        download_file(DRIVE_ID, MASTER_ZIP_NAME)
    except Exception as e:
        print(f"❌ Critical Error Downloading: {e}")
        return

    # 3. Setup JSONL Output
    print(f"\n📝 creating {OUTPUT_JSONL}...")
    if os.path.exists(OUTPUT_JSONL):
        os.remove(OUTPUT_JSONL)

    temp_master_dir = "temp_master_extract"
    temp_inner_dir = "temp_inner_extract"

    total_files_processed = 0

    try:
        with open(OUTPUT_JSONL, 'w', encoding='utf-8') as jsonl_out:

            # 4. Extract Master Zip
            print(f"📦 Extracting {MASTER_ZIP_NAME}...")
            if os.path.exists(temp_master_dir):
                shutil.rmtree(temp_master_dir)
            os.makedirs(temp_master_dir)

            with zipfile.ZipFile(MASTER_ZIP_NAME, 'r') as z_master:
                z_master.extractall(temp_master_dir)

            # 5. Iterate through Inner Zips
            inner_files = [f for f in os.listdir(temp_master_dir) if f.lower().endswith('.zip')]
            print(f"🔹 Found {len(inner_files)} repository archives: {inner_files}")

            for zip_file in inner_files:
                repo_name = os.path.splitext(zip_file)[0]
                full_zip_path = os.path.join(temp_master_dir, zip_file)

                print(f"\n⚙️ Processing REPO: {repo_name}")

                # Clear inner temp dir
                if os.path.exists(temp_inner_dir):
                    shutil.rmtree(temp_inner_dir)
                os.makedirs(temp_inner_dir)

                # Extract Inner Zip
                try:
                    with zipfile.ZipFile(full_zip_path, 'r') as z_inner:
                        z_inner.extractall(temp_inner_dir)

                    # Process Contents
                    count = process_directory_to_jsonl(temp_inner_dir, jsonl_out, repo_name)
                    total_files_processed += count

                except zipfile.BadZipFile:
                    print(f"   ❌ ERROR: {zip_file} is corrupted!")
                except Exception as e:
                    print(f"   ❌ ERROR processing {zip_file}: {e}")
                finally:
                    # CLEANUP INNER (Streamed Processing)
                    # "Don't swallow the elephant" - free up space immediately
                    if os.path.exists(temp_inner_dir):
                        shutil.rmtree(temp_inner_dir)

    except Exception as e:
        print(f"❌ Fatal Error in processing loop: {e}")
        return
    finally:
        # Cleanup Master
        if os.path.exists(temp_master_dir):
            shutil.rmtree(temp_master_dir)
        if os.path.exists(MASTER_ZIP_NAME):
            os.remove(MASTER_ZIP_NAME)

    print(f"\n✅ All Repos Processed. Total Files: {total_files_processed}")

    # 6. Verify and Pack Final Artifact
    print(f"\n🎁 Packaging {FINAL_ARTIFACT_ZIP}...")

    files_to_pack = [OUTPUT_JSONL]

    if os.path.exists(EXISTING_MT_LIB):
        print(f"   ➕ Found existing MT Libs: {EXISTING_MT_LIB}")
        files_to_pack.append(EXISTING_MT_LIB)
    else:
        print(f"   ⚠️ WARNING: {EXISTING_MT_LIB} not found! The vault will be incomplete.")

    try:
        with zipfile.ZipFile(FINAL_ARTIFACT_ZIP, 'w', zipfile.ZIP_DEFLATED) as zf:
            for f in files_to_pack:
                print(f"   Adding {f}...")
                zf.write(f, os.path.basename(f))

        print(f"\n✨ SUCCESS! {FINAL_ARTIFACT_ZIP} created.")
        print(f"   Size: {os.path.getsize(FINAL_ARTIFACT_ZIP) / (1024*1024):.2f} MB")

    except Exception as e:
        print(f"❌ Error creating final zip: {e}")

    elapsed = time.time() - start_time
    print(f"=== 🏁 OPERATION COMPLETE ({elapsed:.2f}s) ===")

if __name__ == "__main__":
    main()
