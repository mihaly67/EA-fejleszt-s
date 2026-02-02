import json
import os
from collections import Counter

FILE_PATH = "Knowledge_Base/knowledge_base_thiefs_library.jsonl"

def main():
    if not os.path.exists(FILE_PATH):
        print(f"❌ File not found: {FILE_PATH}")
        return

    print(f"🔍 Inspecting {FILE_PATH}...")

    repo_counts = Counter()
    total_lines = 0
    sample_entry = None

    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line: continue

                total_lines += 1
                try:
                    data = json.loads(line)

                    # Inspect 'source' field
                    source = data.get("source", "unknown")

                    # Inspect 'filename' to guess repo if source is generic
                    filename = data.get("filename", "")

                    # Strategy: If source is generic (like 'github'), try to split filename
                    repo = source
                    if repo == "github" or repo == "unknown":
                         # Assume filename is "repo_name/path/..."
                         parts = filename.split('/')
                         if len(parts) > 1:
                             repo = parts[0]

                    repo_counts[repo] += 1

                    if total_lines == 1:
                        sample_entry = data
                except json.JSONDecodeError:
                    print(f"   ⚠️ JSON Error on line {total_lines}")

        print(f"\n📊 Statistics ({total_lines} files):")
        for repo, count in repo_counts.most_common():
            print(f"   - {repo}: {count} files")

        if sample_entry:
            print("\n📄 Sample Entry:")
            print(f"   filename: {sample_entry.get('filename')}")
            print(f"   source: {sample_entry.get('source')}")
            # print(f"   code snippet: {sample_entry.get('code')[:100]}...") # Keep it clean

    except Exception as e:
        print(f"❌ Error reading file: {e}")

if __name__ == "__main__":
    main()
