import os
import json
import time
import zipfile
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
# The script will look for ALL subfolders in the SAME directory where the script is running.

OUTPUT_FILE = "output.jsonl"
OUTPUT_ZIP = "knowledge_capsule.zip"
OUTPUT_LIST = "repo_list.txt"

# Comprehensive list of code and documentation extensions
VALID_EXTENSIONS = {
    # Python & Web
    '.py', '.pyx', '.pxd', '.js', '.ts', '.jsx', '.tsx', '.html', '.css', '.scss',
    # C/C++ family
    '.c', '.cpp', '.h', '.hpp', '.cc', '.cxx', '.cs',
    # MQL5
    '.mq5', '.mqh',
    # Rust & Go & Java
    '.rs', '.go', '.java', '.kt', '.scala',
    # Data & Config
    '.json', '.yaml', '.yml', '.xml', '.toml', '.ini',
    # Documentation
    '.md', '.rst', '.txt', '.ipynb',
    # Shell
    '.sh', '.bash', '.zsh', '.bat', '.ps1',
    # Other
    '.lua', '.rb', '.php', '.pl', '.sql'
}

IGNORE_DIRS = {
    '__pycache__', 'node_modules', '.git', '.github', 'dist', 'build',
    'venv', 'env', '.idea', '.vscode', 'target', 'bin', 'obj', 'colombo_kit',
    'coverage', 'tmp', 'temp', 'logs'
}

MAX_FILE_SIZE = 2 * 1024 * 1024  # 2 MB limit per file to avoid huge blobs

def get_script_dir():
    """Returns the directory where this script is located."""
    return os.path.dirname(os.path.abspath(__file__))

def get_repo_folders(base_path):
    """Scans for all subdirectories in the base path, excluding ignored ones."""
    repo_dirs = []
    print(f"🔍 Scanning in working directory: {base_path}")

    try:
        with os.scandir(base_path) as entries:
            for entry in entries:
                # Exclude hidden folders and ignore list
                if entry.is_dir() and entry.name not in IGNORE_DIRS and not entry.name.startswith('.'):
                     repo_dirs.append(entry.name)
    except OSError as e:
        print(f"❌ Error scanning directory: {e}")
        return []

    repo_dirs.sort()
    return repo_dirs

def collect_files_from_repos(base_path, repo_names):
    """Walks through each repo folder and collects valid files."""
    file_list = []
    found_repos = 0

    print(f"\n📂 Processing {len(repo_names)} repositories...")

    for repo in repo_names:
        repo_path = os.path.join(base_path, repo)

        if not os.path.exists(repo_path):
            continue

        found_repos += 1

        # Walk through the directory
        for root, dirs, files in os.walk(repo_path):
            # Modify dirs in-place to skip ignored directories
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith('.')]

            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in VALID_EXTENSIONS:
                    full_path = os.path.join(root, file)
                    try:
                        if os.path.getsize(full_path) <= MAX_FILE_SIZE:
                            file_list.append(full_path)
                    except OSError:
                        pass # Skip if file access error

    if found_repos == 0:
        print("❌ CRITICAL: No accessible repository folders found!")
    else:
        print(f"✅ Found {len(file_list)} valid files in {found_repos} repositories.")

    return file_list

def process_single_file(filepath):
    """Reads a single file and returns a JSON object."""
    content = None

    # Try UTF-8 first
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        # Fallback to Latin-1
        try:
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception:
            return None # Skip binary or unreadable files
    except Exception:
        return None

    if not content:
        return None

    # Calculate relative path for filename field
    script_dir = get_script_dir()
    try:
        rel_path = os.path.relpath(filepath, script_dir)
        # Extract the top-level folder as the source
        parts = Path(rel_path).parts
        source_repo = parts[0] if parts else "Unknown"
    except ValueError:
        source_repo = "External"
        rel_path = os.path.basename(filepath)

    return {
        "filename": rel_path.replace("\\", "/"), # Standardize paths
        "code": content,
        "source": source_repo
    }

def main():
    print("=== 🏗️  UNIVERSAL KNOWLEDGE CAPSULE BUILDER  ===")
    print("    (Run this next to your target repositories)    ")

    # 1. Setup Paths
    work_dir = get_script_dir()
    output_jsonl = os.path.join(work_dir, OUTPUT_FILE)
    output_zip = os.path.join(work_dir, OUTPUT_ZIP)
    output_list = os.path.join(work_dir, OUTPUT_LIST)

    # 2. Discover Repositories
    repo_names = get_repo_folders(work_dir)

    if not repo_names:
        print("❌ No repositories found in the current directory.")
        return

    # 3. Save Repo List
    print(f"📝 Saving repository list to: {OUTPUT_LIST}")
    with open(output_list, 'w', encoding='utf-8') as f:
        for repo in repo_names:
            f.write(repo + "\n")

    # 4. Gather Files
    all_files = collect_files_from_repos(work_dir, repo_names)

    if not all_files:
        print("❌ No valid files found matching criteria.")
        return

    # 5. Process Files (Parallel)
    print(f"🚀 Building JSONL from {len(all_files)} files...")
    records = []
    start_time = time.time()

    # Use ThreadPool for I/O bound task
    with ThreadPoolExecutor(max_workers=8) as executor:
        # map returns an iterator, tqdm wraps it for progress bar
        results = list(tqdm(executor.map(process_single_file, all_files), total=len(all_files), unit="file"))
        records = [r for r in results if r is not None]

    # 6. Write JSONL Output
    print(f"💾 Writing {len(records)} records to: {OUTPUT_FILE}")
    with open(output_jsonl, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

    # 7. Create ZIP Package
    print(f"📦 Creating archive: {OUTPUT_ZIP}")
    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(output_jsonl, arcname=OUTPUT_FILE)
        zf.write(output_list, arcname=OUTPUT_LIST)

    # Statistics
    elapsed = time.time() - start_time
    json_size_mb = os.path.getsize(output_jsonl) / (1024 * 1024)
    zip_size_mb = os.path.getsize(output_zip) / (1024 * 1024)

    print("\n=== ✅ BUILD COMPLETE ===")
    print(f"⏱️  Time: {elapsed:.2f}s")
    print(f"📂 Output JSONL: {json_size_mb:.2f} MB")
    print(f"📦 Final ZIP:    {zip_size_mb:.2f} MB")
    print(f"📍 Location:     {output_zip}")
    print("\n👉 Now rename 'knowledge_capsule.zip' to your desired name!")

if __name__ == "__main__":
    main()
