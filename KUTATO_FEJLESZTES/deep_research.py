import subprocess
import json
import sys

def search(query, scope):
    print(f"\n[SEARCH] Scope: {scope} | Query: {query}")
    try:
        cmd = [sys.executable, "kutato.py", query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("Error:", result.stderr)
            return []
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Exception: {e}")
        return []

def main():
    print("=== DEEP RESEARCH MISSION (KUTATO v3 SIMULATION) ===")

    # Level 1: Buffer Basics
    print("\n--- LEVEL 1: Buffer Visibility ---")
    hits1 = search("iCustom CopyBuffer INDICATOR_CALCULATIONS hidden", "MQL5_DEV")
    for h in hits1[:2]: print(f"  - {h['content'][:100]}...")

    # Level 2: Indexing Logic
    print("\n--- LEVEL 2: Buffer Indexing Mismatch ---")
    hits2 = search("CopyBuffer index mismatch SetIndexBuffer", "MQL5_DEV")
    for h in hits2[:2]: print(f"  - {h['content'][:100]}...")

    # Level 3: Plot vs Buffer
    print("\n--- LEVEL 3: Plot vs Buffer Count ---")
    hits3 = search("indicator_plots vs indicator_buffers iCustom", "MQL5_DEV")
    for h in hits3[:2]: print(f"  - {h['content'][:100]}...")

if __name__ == "__main__":
    main()
