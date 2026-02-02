import os
import json
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# Try to import tqdm
try:
    from tqdm import tqdm
except ImportError:
    print("⚠️ 'tqdm' module not found. Run: pip install tqdm")
    def tqdm(iterable, **kwargs):
        return iterable

# --- CONFIGURATION ---
# The script will look for these folders in the SAME directory where the script is running.
TARGET_REPOS = [
    "hummingbot-master",
    "FinRL-master",
    "vectorbt-master",
    "nautilus_trader-develop",
    "context7-master"
]

OUTPUT_FILE = "knowledge_base_thiefs_library.jsonl"

VALID_EXTENSIONS = {
    '.py', '.pyx', '.pxd',       # Python
    '.mq5', '.mqh',              # MQL5
    '.cpp', '.c', '.h', '.hpp',  # C++
    '.rs',                       # Rust
    '.md', '.rst', '.txt',       # Docs
    '.json', '.yaml', '.yml',    # Config
    '.ipynb'                     # Notebooks
}

IGNORE_DIRS = {
    '__pycache__', 'node_modules', '.git', '.github', 'dist', 'build',
    'venv', 'env', '.idea', '.vscode', 'target', 'bin', 'obj'
}

MAX_FILE_SIZE = 1 * 1024 * 1024  # 1 MB

def get_script_dir():
    """Returns the directory where this script is located."""
    return os.path.dirname(os.path.abspath(__file__))

def get_all_files(base_path, repo_names):
    """Scans for repo folders relative to the script and collects files."""
    file_list = []
    print(f"🔍 Scanning in working directory: {base_path}")

    found_repos = 0

    for repo in repo_names:
        # Construct full path: ./Github repo/hummingbot
        repo_path = os.path.join(base_path, repo)

        if not os.path.exists(repo_path):
            print(f"   ⚠️  SKIPPING: '{repo}' folder not found here.")
            continue

        print(f"   ✅ FOUND: '{repo}'")
        found_repos += 1

        for root, dirs, files in os.walk(repo_path):
            dirs[:] = [xd for xd in dirs if xd not in IGNORE_DIRS]

            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in VALID_EXTENSIONS:
                    full_path = os.path.join(root, file)
                    if os.path.getsize(full_path) <= MAX_FILE_SIZE:
                        file_list.append(full_path)

    if found_repos == 0:
        print("\n❌ CRITICAL: No repo folders found! Are they unzipped next to this script?")
    else:
        print(f"\n📄 Collected {len(file_list)} valid files from {found_repos} repositories.")

    return file_list

def process_file(filepath):
    """Reads a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception:
            return None
    except Exception:
        return None

    # Calculate path relative to the script directory (e.g., "hummingbot/strategy/...")
    script_dir = get_script_dir()
    try:
        rel_path = os.path.relpath(filepath, script_dir)
        # Verify it starts with the repo name
        parts = Path(rel_path).parts
        repo_name = parts[0]
    except ValueError:
        repo_name = "Unknown"
        rel_path = os.path.basename(filepath)

    return {
        "filename": rel_path.replace("\\", "/"), # Ensure consistent forward slashes
        "code": content,
        "source": repo_name
    }

def main():
    print("=== 🏗️ JULES AUTO-BUILDER ===")

    # 1. Setup Paths
    work_dir = get_script_dir()
    output_path = os.path.join(work_dir, OUTPUT_FILE)

    # 2. Gather Files
    files = get_all_files(work_dir, TARGET_REPOS)

    if not files:
        return

    # 3. Process
    print(f"🚀 Building Knowledge Base...")
    records = []
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=6) as executor:
        results = list(tqdm(executor.map(process_file, files), total=len(files), unit="file"))
        records = [r for r in results if r is not None]

    # 4. Write Output
    print(f"💾 Saving to: {OUTPUT_FILE}")
    with open(output_path, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    elapsed = time.time() - start_time
    size_mb = os.path.getsize(output_path) / (1024 * 1024)

    print("\n=== ✅ SUCCESS ===")
    print(f"⏱️  Duration: {elapsed:.2f}s")
    print(f"📂 Location: {output_path}")
    print(f"📊 Final Size: {size_mb:.2f} MB")

if __name__ == "__main__":
    main()
