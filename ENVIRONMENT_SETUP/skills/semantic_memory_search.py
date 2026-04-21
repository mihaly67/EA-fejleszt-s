# Autonomous Agent Skill: Semantic Memory Retriever (Anti-Hallucination)
import argparse
import os
import json
import re

MEMORY_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "Knowledge_Base", "agent_memory.jsonl")

def search_memory(keyword: str, days_ago: int = None, limit: int = 10):
    """
    Szemantikus / Kulcsszavas keresés az Agent Hosszútávú memóriájában (agent_memory.jsonl).
    Lehetővé teszi, hogy a lineáris (zavaros) chat history helyett csak azokat
    a korábbi 'Condense' (Sűrített) stratégiai lépéseket olvassa fel az Agent,
    amelyek egy specifikus feladathoz (pl. 'VapourSynth' vagy 'FFmpeg') tartoztak hetekkel ezelőtt.
    """
    if not os.path.exists(MEMORY_FILE):
        print("❌ [Memory Search] A memória fájl még nem létezik.")
        return

    print(f"🧠 [Memory Search] Keresés a memóriában: '{keyword}'...")

    results = []
    pattern = re.compile(re.escape(keyword), re.IGNORECASE)

    try:
        with open(MEMORY_FILE, 'r', encoding='utf-8') as f:
            lines = f.readlines()

            # Időbeli szűrést (days_ago) is be lehet építeni a `timestamp` mező alapján
            # de a kulcsszavas keresés (Regex) a leghatékonyabb a Condense blokkokban.
            for line in reversed(lines):
                if not line.strip(): continue
                try:
                    entry = json.loads(line)
                    if entry.get("category") == "SESSION_MARKER":
                        continue

                    content = entry.get("content", "")
                    category = entry.get("category", "")

                    # Ha a tartalom vagy a kategória tartalmazza a kulcsszót
                    if pattern.search(content) or pattern.search(category):
                        results.append(entry)

                    if len(results) >= limit:
                        break
                except json.JSONDecodeError:
                    continue

    except Exception as e:
        print(f"❌ [Memory Search] Hiba a memória olvasása közben: {e}")
        return

    if not results:
        print("⚠️ [Memory Search] Nem találtam releváns bejegyzést a múltból ezzel a kulcsszóval.")
        return

    print("\n--- 🎯 TALÁLATOK A MÚLTBÓL (Szemantikus Fókusz) ---\n")
    for idx, res in enumerate(results, 1):
        print(f"[{idx}] ⏱️ {res.get('timestamp', '')[:16]} | 🏷️ {res.get('category', '')}")
        print(f"   📝 {res.get('content', '')}")
        print("-" * 60)

    print("\n🧠 [Agent Prompt] A fenti információk a múltbeli fókuszált kontextust jelentik. Építsd be a jelenlegi feladatodba!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Agent Memory Search (Time-Travel / Keyword RAG)")
    parser.add_argument("--keyword", required=True, help="A keresendő kifejezés vagy funkció (pl. 'Tiling Engine')")
    parser.add_argument("--limit", type=int, default=5, help="Maximum hány találatot adjon vissza")
    args = parser.parse_args()

    search_memory(args.keyword, limit=args.limit)
