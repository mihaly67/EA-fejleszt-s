import json

FILE_PATH = "Knowledge_Base/knowledge_base_thiefs_library.jsonl"
OUTPUT_FILE = "STORYTELLING_FINDINGS.md"

KEYWORDS = [
    "journal", "narrative", "history", "replay", "event_stream",
    "reporter", "summary", "audit", "trace", "lifecycle",
    "plot", "story", "visualizer"
]

def main():
    print(f"🕵️ Scanning Thief's Library for Storytelling/Journaling Tools...")

    findings = []

    try:
        with open(FILE_PATH, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line: continue

                try:
                    data = json.loads(line)
                    filename = data.get("filename", "").lower()
                    code = data.get("code", "")

                    found_keys = [k for k in KEYWORDS if k in filename or k in code.lower()]

                    if found_keys:
                        # Prioritize files that seem to be about "Reporting" or "History"
                        findings.append({
                            "source": data.get("source", ""),
                            "file": filename,
                            "keys": found_keys
                        })
                except: pass
    except Exception as e:
        print(f"❌ Error: {e}")
        return

    findings.sort(key=lambda x: len(x['keys']), reverse=True)

    with open(OUTPUT_FILE, 'w') as f:
        f.write("# Thief's Library: Storytelling & Journaling Findings\n\n")
        for item in findings[:50]:
            f.write(f"- **{item['file']}** (Keys: {', '.join(item['keys'])})\n")

    print(f"✅ Search Complete. Found {len(findings)} matches. Report: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
