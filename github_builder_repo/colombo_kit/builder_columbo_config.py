import os
import json
import zipfile
import time
from datetime import datetime

# --- CONFIGURATION ---
# Base directory is assumed to be the current directory where this script runs
# Structure: ./repo_folder/
REPO_DIRS = [
    "alibi-detect-master",
    "causalml-master",
    "chaosmonkey-master",
    "dowhy-main",
    "mlfinlab-master",
    "open_spiel-master",
    "perspective-master",
    "PettingZoo-master",
    "pyod-master",
    "quantstats-main",
    "swift-composable-architecture-main"
]

OUTPUT_JSONL = "knowledge_base_columbo.jsonl"
OUTPUT_ZIP = "knowledge_base_columbo.zip"

# Extensions to INCLUDE in the Knowledge Base
ALLOWED_EXTENSIONS = {
    # Core Logic
    '.py', '.ipynb', '.js', '.ts', '.cpp', '.hpp', '.h', '.c', '.go', '.rs', '.java', '.swift',
    # Documentation
    '.md', '.rst', '.txt'
}

# Max file size to include (text only) - 1MB
MAX_FILE_SIZE = 1 * 1024 * 1024

def is_binary(file_path):
    """Simple check if file is likely binary."""
    try:
        with open(file_path, 'tr') as check_file:
            check_file.read(1024)
            return False
    except:
        return True

def build_knowledge_base():
    print(f"🏗️ COLUMBO BUILDER: Starting Extraction...")
    print(f"   Target Repos: {len(REPO_DIRS)}")

    entries_count = 0
    start_time = time.time()

    # We will write directly to ZIP to save space?
    # Or write JSONL then Zip. JSONL is safer for appending.

    with open(OUTPUT_JSONL, 'w', encoding='utf-8') as outfile:

        for repo_name in REPO_DIRS:
            repo_path = os.path.join(".", repo_name)

            if not os.path.exists(repo_path):
                print(f"⚠️ WARNING: Repo folder not found: {repo_path} (Skipping)")
                continue

            print(f"   Processing: {repo_name}...")

            for root, dirs, files in os.walk(repo_path):
                # Ignore hidden dirs (.git, .github, etc.)
                dirs[:] = [d for d in dirs if not d.startswith('.')]

                for file in files:
                    ext = os.path.splitext(file)[1].lower()

                    if ext in ALLOWED_EXTENSIONS:
                        file_path = os.path.join(root, file)

                        # Check size
                        try:
                            size = os.path.getsize(file_path)
                            if size > MAX_FILE_SIZE:
                                # Skip huge files
                                continue

                            # Read content
                            content = ""
                            try:
                                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                                    content = f.read()
                            except Exception as e:
                                print(f"     Error reading {file}: {e}")
                                continue

                            if not content.strip():
                                continue

                            # Create Entry
                            # Relative path from repo root
                            rel_path = os.path.relpath(file_path, repo_path)

                            entry = {
                                "repo": repo_name,
                                "file": rel_path,
                                "ext": ext,
                                "content": content,
                                "source": "local_vps_extraction"
                            }

                            # Write JSON Line
                            outfile.write(json.dumps(entry) + "\n")
                            entries_count += 1

                            if entries_count % 1000 == 0:
                                print(f"     -> Processed {entries_count} files...")

                        except Exception as e:
                            pass

    print(f"\n✅ JSONL Generation Complete. Total Entries: {entries_count}")

    # Zip it
    print(f"📦 Zipping to {OUTPUT_ZIP}...")
    with zipfile.ZipFile(OUTPUT_ZIP, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.write(OUTPUT_JSONL, arcname=OUTPUT_JSONL)

    # Cleanup JSONL to save space? Optional. User might want to inspect.
    # os.remove(OUTPUT_JSONL)

    elapsed = time.time() - start_time
    print(f"🎉 DONE! Time: {elapsed:.1f}s. Artifact ready: {OUTPUT_ZIP}")

if __name__ == "__main__":
    build_knowledge_base()
