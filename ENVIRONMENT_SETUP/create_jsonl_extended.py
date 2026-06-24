import os
import json
import argparse

# Default Extensions
VALID_EXTENSIONS = {
    '.mq5', '.mqh',       # MQL5
    '.py', '.pyx', '.pxd', # Python/Cython
    '.cpp', '.c', '.h', '.hpp', # C++
    '.md', '.txt', '.rst',      # Docs
    '.json', '.ini',      # Config
    '.js', '.ts', '.tsx', '.jsx', # Web/Panel
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
    parser = argparse.ArgumentParser(description="Create JSONL from codebase")
    parser.add_argument("--path", type=str, required=True, help="Source directory")
    parser.add_argument("--output", type=str, required=True, help="Output JSONL file")

    args = parser.parse_args()

    source_dir = args.path
    output_file = args.output

    print(f"Scanning {source_dir}...")
    count = 0
    skipped_binary = 0
    skipped_ext = 0

    with open(output_file, 'w', encoding='utf-8') as outfile:
        for root, dirs, files in os.walk(source_dir):
            # Modify dirs in-place to skip ignored directories
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

            for file in files:
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

                    # Store relative path
                    rel_path = os.path.relpath(filepath, source_dir)

                    entry = {
                        "path": rel_path,
                        "extension": ext,
                        "repo": os.path.basename(source_dir),
                        "content": content
                    }
                    outfile.write(json.dumps(entry) + "\n")
                    count += 1

                except Exception as e:
                    print(f"Error reading {filepath}: {e}")

    print(f"Done. Processed {count} files.")
    print(f"Skipped {skipped_ext} by extension, {skipped_binary} binary files.")
    print(f"Output saved to {output_file}")

if __name__ == "__main__":
    main()
