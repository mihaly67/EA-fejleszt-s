import os
import json
import argparse
import time
import zipfile

def generate_filemap(root_dir, output_file):
    file_map = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "root_directory": root_dir,
        "structure": {}
    }

    print(f"Generating file map for: {root_dir}")
    print(f"Scanning directories...")

    total_files = 0
    total_dirs = 0

    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Calculate relative path from root
        rel_path = os.path.relpath(dirpath, root_dir)
        if rel_path == ".":
            rel_path = ""

        # Normalize path separators to forward slash (Linux/Windows compatibility)
        rel_path = rel_path.replace("\\", "/")

        # Store directory info
        current_node = file_map["structure"]
        if rel_path:
            path_parts = rel_path.split("/")
            for part in path_parts:
                if part not in current_node:
                    current_node[part] = {"_type": "dir", "_content": {}}
                current_node = current_node[part]["_content"]

        # Add files to the current directory node
        for f in filenames:
            file_path = os.path.join(dirpath, f)
            try:
                stat = os.stat(file_path)
                current_node[f] = {
                    "_type": "file",
                    "size": stat.st_size,
                    "modified": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(stat.st_mtime))
                }
                total_files += 1
            except Exception as e:
                print(f"Error accessing file {f}: {e}")
                current_node[f] = {"_type": "error", "message": str(e)}

        total_dirs += 1

    # Save JSON
    print(f"Saving file map to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(file_map, f, indent=2)

    print(f"Completed! Scanned {total_dirs} directories and {total_files} files.")

    # Create ZIP archive
    zip_filename = output_file + ".zip"
    print(f"Creating ZIP archive: {zip_filename}")
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(output_file, os.path.basename(output_file))

    print(f"Done. Please upload '{zip_filename}' to the agent.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a file map (JSON) of a directory structure.")
    parser.add_argument("directory", nargs="?", default="MQL5", help="The root directory to scan (default: MQL5)")
    parser.add_argument("--output", default="MQL5_FileMap.json", help="Output JSON filename (default: MQL5_FileMap.json)")

    args = parser.parse_args()

    if not os.path.exists(args.directory):
        print(f"Error: Directory '{args.directory}' not found.")
        print("Usage: python3 generate_mql5_filemap.py [directory]")
        exit(1)

    generate_filemap(args.directory, args.output)
