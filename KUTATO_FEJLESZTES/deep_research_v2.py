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
    print("=== DEEP RESEARCH MISSION - PHASE 2 ===")

    # buffers mixing
    hits1 = search("iCustom mixed up buffers", "MQL5_DEV")
    for h in hits1[:1]: print(f"  - {h['content'][:100]}...")

    # plotting issue
    hits2 = search("indicator plot order wrong", "MQL5_DEV")
    for h in hits2[:1]: print(f"  - {h['content'][:100]}...")

    # input group issue specific
    hits3 = search("input group parameter shift iCustom", "MQL5_DEV")
    for h in hits3[:1]: print(f"  - {h['content'][:100]}...")

if __name__ == "__main__":
    main()
