import os
import zipfile
import shutil
import datetime

# Configuration
SOURCE_ROOT = "MQL5"
OUTPUT_DIR = "DEPLOYMENT"
OUTPUT_ZIP_NAME = "Merkava_Payload"
IGNORE_EXTENSIONS = {".mq5", ".mqh", ".py", ".md", ".json", ".git", ".gitignore"}
INCLUDE_EXTENSIONS = {".ex5", ".dll", ".dat", ".txt", ".csv"} # Only compiled/data files

def create_deployment_package():
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_filename = f"{OUTPUT_ZIP_NAME}_{timestamp}.zip"

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    output_path = os.path.join(OUTPUT_DIR, zip_filename)

    print(f"=== Merkava Deployment Packager ===")
    print(f"Target: {output_path}")
    print(f"Mode: BINARY ONLY (Source Code Excluded)")

    files_added = 0

    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(SOURCE_ROOT):
            for file in files:
                file_path = os.path.join(root, file)
                _, ext = os.path.splitext(file)

                # Filter Logic
                if ext.lower() in INCLUDE_EXTENSIONS:
                    # Preserve MQL5 directory structure in the zip
                    # e.g., MQL5/Experts/MyEA.ex5
                    zipf.write(file_path, file_path)
                    print(f"  [+] Added: {file_path}")
                    files_added += 1
                elif ext.lower() in IGNORE_EXTENSIONS:
                    # Explicitly ignore source
                    pass
                else:
                    # Ignore unknown types by default for safety
                    pass

    print(f"===================================")
    if files_added == 0:
        print("WARNING: No compiled files (.ex5) found! Did you compile the project?")
    else:
        print(f"SUCCESS: Package created with {files_added} files.")
        print(f"INSTRUCTION: Transfer {zip_filename} to the Execution Machine (Zone B).")

if __name__ == "__main__":
    create_deployment_package()
