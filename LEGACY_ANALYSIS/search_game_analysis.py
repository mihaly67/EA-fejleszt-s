import json
import re

FILE_PATH = "Knowledge_Base/knowledge_base_thiefs_library.jsonl"
OUTPUT_FILE = "GAME_ANALYSIS_FINDINGS.md"

KEYWORDS = [
    "adversarial", "anomaly", "outlier", "mistake", "error",
    "drawdown", "sharpe", "sortino", "calmar", # Performance metrics
    "regime", "volatility", "cluster", # Market state
    "opponent", "game", "chess" # Direct metaphors (unlikely but possible in docs)
]

def main():
    print(f"🕵️ Scanning Thief's Library for Analytical Tools...")

    findings = []

    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line: continue

            try:
                data = json.loads(line)
                filename = data.get("filename", "").lower()
                code = data.get("code", "")
                source = data.get("source", "")

                # Check for keywords
                found_keys = [k for k in KEYWORDS if k in filename or k in code.lower()]

                if found_keys:
                    # Filter for substantial code (not just imports)
                    if "class" in code or "def" in code:
                        snippet = code[:300].replace("\n", " ")
                        findings.append({
                            "source": source,
                            "file": filename,
                            "keys": found_keys,
                            "snippet": snippet
                        })
            except: pass

    # Sort by relevance (number of keywords found)
    findings.sort(key=lambda x: len(x['keys']), reverse=True)

    # Write Report
    with open(OUTPUT_FILE, 'w') as f:
        f.write("# Thief's Library: Analytical Tools Findings\n\n")

        current_source = ""
        for item in findings[:50]: # Top 50 hits
            if item['source'] != current_source:
                f.write(f"\n## {item['source']}\n")
                current_source = item['source']

            f.write(f"- **{item['file']}** (Keys: {', '.join(item['keys'])})\n")
            # f.write(f"  > `{item['snippet']}...`\n")

    print(f"✅ Search Complete. Found {len(findings)} matches. Report: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
