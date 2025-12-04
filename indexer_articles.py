import os
import json
import zipfile

SOURCE_DIR = "/tmp/research_articles"
OUTPUT_FILE = "/tmp/research_articles/research_articles_adatok.json"

def unzip_all():
    print(f"Unzipping archives in {SOURCE_DIR}...")
    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            if file.endswith(".zip"):
                path = os.path.join(root, file)
                try:
                    with zipfile.ZipFile(path, 'r') as z:
                        z.extractall(root)
                    # print(f"Unzipped {file}")
                except Exception as e:
                    print(f"Error unzipping {file}: {e}")

def index_files():
    if not os.path.exists(SOURCE_DIR):
        print(f"Source dir {SOURCE_DIR} missing.")
        return

    docs = []
    print(f"Indexing code in {SOURCE_DIR}...")

    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            if file.endswith(('.mq5', '.mq4', '.mqh', '.h')):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8', errors='replace') as f:
                        content = f.read()

                    docs.append({
                        "filename": file,
                        "source_type": "KOD",
                        "content": content,
                        "search_content": content[:5000]
                    })
                except Exception as e:
                    print(f"Error reading {file}: {e}")

    print(f"Indexed {len(docs)} files.")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(docs, f, indent=2)

    print(f"Saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    unzip_all()
    index_files()
