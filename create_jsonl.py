import os
import json

SOURCE_DIR = "github_codebase"
OUTPUT_FILE = "github_codebase/external_codebase.jsonl"

# Extensions to include
VALID_EXTENSIONS = {
    '.mq5', '.mqh',       # MQL5
    '.py',                # Python
    '.cpp', '.c', '.h', '.hpp', # C++
    '.md', '.txt',        # Docs
    '.json', '.ini',      # Config
    '.js', '.ts', '.tsx', '.jsx', # Web/Panel
    '.rst'                # Docs
}

# Directories to ignore
IGNORE_DIRS = {
    '__pycache__', 'node_modules', '.git', '.github', 'dist', 'build', 'venv', 'env', '.idea', '.vscode'
}

def is_text_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            f.read(1024)
        return True
    except UnicodeDecodeError:
        return False
    except Exception:
        return False

def main():
    print(f"Scanning {SOURCE_DIR}...")
    count = 0
    skipped_binary = 0
    skipped_ext = 0

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        for root, dirs, files in os.walk(SOURCE_DIR):
            # Modify dirs in-place to skip ignored directories
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

            for file in files:
                if file == "codebase.zip" or file == "external_codebase.jsonl":
                    continue

                ext = os.path.splitext(file)[1].lower()
                if ext not in VALID_EXTENSIONS:
                    skipped_ext += 1
                    continue

                filepath = os.path.join(root, file)

                # Size check (skip > 1MB)
                if os.path.getsize(filepath) > 1024 * 1024:
                    continue

                if not is_text_file(filepath):
                    skipped_binary += 1
                    continue

                try:
                    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
                        content = f.read()

                    entry = {
                        "path": filepath,
                        "extension": ext,
                        "content": content
                    }
                    outfile.write(json.dumps(entry) + "\n")
                    count += 1

                except Exception as e:
                    print(f"Error reading {filepath}: {e}")

    print(f"Done. Processed {count} files.")
    print(f"Skipped {skipped_ext} by extension, {skipped_binary} binary files.")
    print(f"Output saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
