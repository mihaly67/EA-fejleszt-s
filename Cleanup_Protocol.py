import os
import shutil

# Configuration
TARGET_ROOT = "MQL5"
DANGEROUS_EXTENSIONS = {".mq5", ".mqh", ".py", ".md"}

def cleanup_protocol():
    print("=== Merkava Emergency Cleanup Protocol ===")
    print("WARNING: This will DELETE all source code in the MQL5 directory.")
    print("Use this ONLY on the Execution Machine (Zone B) to sanitize the environment.")

    confirm = input("Type 'BURN' to confirm immediate deletion: ")
    if confirm != "BURN":
        print("Abort.")
        return

    deleted_count = 0

    for root, dirs, files in os.walk(TARGET_ROOT):
        for file in files:
            _, ext = os.path.splitext(file)
            if ext.lower() in DANGEROUS_EXTENSIONS:
                file_path = os.path.join(root, file)
                try:
                    os.remove(file_path)
                    print(f"  [!] Deleted: {file_path}")
                    deleted_count += 1
                except Exception as e:
                    print(f"  [ERROR] Failed to delete {file_path}: {e}")

    print(f"==========================================")
    print(f"Cleanup Complete. {deleted_count} files destroyed.")
    print("The environment is now sterile (Binaries only).")

if __name__ == "__main__":
    cleanup_protocol()
