import json
import os
from collections import Counter

FILE_PATH = "Knowledge_Base/knowledge_base_columbo.jsonl"

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

                    # Inspect fields
                    # Schema 1: repo, file, content, source
                    # Schema 2 (Legacy): filename, code, source

                    repo = data.get("repo")
                    filename = data.get("file") or data.get("filename")
                    source = data.get("source")

                    if not repo:
                        # Fallback for legacy schema
                        # If source is "local_vps_extraction", usually 'repo' key exists.
                        # If not, try to infer from filename if it exists
                        if filename and '/' in filename:
                             repo = filename.split('/')[0]
                        else:
                             repo = source if source else "unknown"

                    repo_counts[repo] += 1

                    if total_lines == 2: # Use line 2 as sample since line 1 might be huge/anomalous
                        sample_entry = data
                except json.JSONDecodeError:
                    print(f"   ⚠️ JSON Error on line {total_lines}")

        print(f"\n📊 Statistics ({total_lines} files):")
        for repo, count in repo_counts.most_common():
            print(f"   - {repo}: {count} files")

        if sample_entry:
            print("\n📄 Sample Entry (Line 2):")
            print(f"   repo: {sample_entry.get('repo')}")
            print(f"   file: {sample_entry.get('file') or sample_entry.get('filename')}")
            print(f"   source: {sample_entry.get('source')}")

    except Exception as e:
        print(f"❌ Error reading file: {e}")

if __name__ == "__main__":
    main()
