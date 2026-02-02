import os
import json
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# Try to import tqdm, if not available, define a dummy
try:
    from tqdm import tqdm
except ImportError:
    print("⚠️ 'tqdm' module not found. Installing is recommended for progress bars.")
    print("   Run: pip install tqdm")
    # Dummy wrapper to prevent crash if user ignores requirements
    def tqdm(iterable, **kwargs):
        return iterable

# --- CONFIGURATION ---
TARGET_DIRS = [
    "hummingbot",
    "FinRL",
    "vectorbt",
    "nautilus_trader",
    "context7"
]

OUTPUT_FILE = "knowledge_base_thiefs_library.jsonl"

VALID_EXTENSIONS = {
    '.py', '.pyx', '.pxd',       # Python
    '.mq5', '.mqh',              # MQL5 (if any)
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

def get_all_files(base_dirs):
    """Scans directories and returns a list of valid file paths."""
    file_list = []
    print("🔍 Scanning directories...")

    for d in base_dirs:
        if not os.path.exists(d):
            print(f"⚠️ Warning: Directory '{d}' not found. Skipping.")
            continue

        for root, dirs, files in os.walk(d):
            # In-place filtering of ignore dirs
            dirs[:] = [xd for xd in dirs if xd not in IGNORE_DIRS]

            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in VALID_EXTENSIONS:
                    full_path = os.path.join(root, file)
                    # Quick size check
                    if os.path.getsize(full_path) <= MAX_FILE_SIZE:
                        file_list.append(full_path)

    print(f"✅ Found {len(file_list)} valid files to process.")
    return file_list

def process_file(filepath):
    """Reads a single file and returns its JSON record."""
    try:
        # Try UTF-8 first
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

    except UnicodeDecodeError:
        try:
            # Fallback to Latin-1
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception:
            return None  # Binary or unreadable

    except Exception:
        return None

    # Get Repo Name (First folder in path)
    parts = Path(filepath).parts
    repo_name = parts[0] if parts else "Unknown"

    # Normalize path for JSONL
    rel_path = os.path.join(*parts) # Keep original structure

    return {
        "filename": f"{repo_name}/{rel_path}",
        "code": content,
        "source": repo_name
    }

def main():
    print("=== 🏗️ JULES KNOWLEDGE BUILDER (VPS EDITION) ===")

    # 1. Gather Files
    files = get_all_files(TARGET_DIRS)

    if not files:
        print("❌ No files found! Make sure you have unzipped the repos in this directory.")
        return

    # 2. Process with Progress Bar
    print(f"🚀 Processing {len(files)} files into {OUTPUT_FILE}...")

    records = []
    start_time = time.time()

    # Use ThreadPool for IO bound tasks (reading files)
    # 3 Cores -> 6 Threads is usually safe
    with ThreadPoolExecutor(max_workers=6) as executor:
        # Map returns an iterator, we verify results
        results = list(tqdm(executor.map(process_file, files), total=len(files), unit="file"))

        # Filter None results
        records = [r for r in results if r is not None]

    # 3. Write Output
    print(f"💾 Writing {len(records)} records to disk...")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    elapsed = time.time() - start_time
    size_mb = os.path.getsize(OUTPUT_FILE) / (1024 * 1024)

    print("\n=== ✅ BUILD COMPLETE ===")
    print(f"⏱️ Time: {elapsed:.2f} seconds")
    print(f"📦 Output: {OUTPUT_FILE}")
    print(f"📊 Size: {size_mb:.2f} MB")
    print("You can now download this JSONL file.")

if __name__ == "__main__":
    main()
