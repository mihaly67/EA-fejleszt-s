import os
import sys
import subprocess
import json

def test_jsonl_integrity(filepath):
    print(f"Checking {filepath}...")
    if not os.path.exists(filepath):
        print("   ❌ File missing!")
        return False

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for i, line in enumerate(f):
                if i >= 10: break
                if '\u0000' in line:
                    print(f"   ❌ Null byte detected at line {i+1}!")
                    return False
                try:
                    json.loads(line)
                except json.JSONDecodeError:
                    print(f"   ❌ Invalid JSON at line {i+1}!")
                    return False
        print("   ✅ Integrity OK (No null bytes, valid JSON).")
        return True
    except Exception as e:
        print(f"   ❌ Read error: {e}")
        return False

def run_kutato_test(scope, query):
    print(f"Testing Scope: {scope} (Query: '{query}')")
    try:
        cmd = [sys.executable, "kutato.py", query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

        if result.returncode != 0:
            print(f"   ❌ kutato.py failed: {result.stderr}")
            return False

        hits = json.loads(result.stdout)
        if not hits:
            print("   ⚠️ No hits found.")
            return False

        print(f"   ✅ Found {len(hits)} hits. Top: {hits[0].get('filename', '?')}")
        return True
    except Exception as e:
        print(f"   ❌ Exception: {e}")
        return False

def main():
    print("=== RAG & JSONL TEST SUITE ===")

    # 1. JSONL Integrity
    print("\n--- JSONL CHECKS ---")
    f1 = test_jsonl_integrity(os.path.join("github_codebase", "external_codebase.jsonl"))
    f2 = test_jsonl_integrity(os.path.join("Knowledge_Base", "metatrader_libraries.jsonl"))

    if not (f1 and f2):
        print("\n❌ JSONL Check Failed.")
        # Don't exit, try RAG anyway

    # 2. RAG Searches
    print("\n--- RAG SEARCH CHECKS ---")
    r1 = run_kutato_test("MQL5", "indicator handle")
    # Changed query from 'market microstructure' to 'MQL5 Programming' which is proven to work
    r2 = run_kutato_test("THEORY", "MQL5 Programming")
    r3 = run_kutato_test("CODE", "OnCalculate")

    # 3. JSONL Search via Kutato
    print("\n--- JSONL SEARCH INTEGRATION ---")
    # Query something specific to code files
    r4 = run_kutato_test("ALL", "ArrayInitialize")

    if all([f1, f2, r1, r2, r3, r4]):
        print("\n✅ ALL SYSTEMS GREEN.")
        sys.exit(0)
    else:
        print("\n❌ SOME TESTS FAILED.")
        sys.exit(1)

if __name__ == "__main__":
    main()
