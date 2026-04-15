import os
import json
import argparse
import datetime
from pathlib import Path

# A memória fájl helye (A Git repó része lesz, így a sessionök között perzisztens marad)
MEMORY_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "Knowledge_Base", "agent_memory.jsonl")

def init_memory_file():
    """Létrehozza a memóriafájlt, ha még nem létezik."""
    os.makedirs(os.path.dirname(MEMORY_FILE), exist_ok=True)
    if not os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE, 'w', encoding='utf-8') as f:
            pass # Létrehoz egy üres fájlt
        print(f"✅ Memória fájl inicializálva: {MEMORY_FILE}")

def write_memory(category: str, content: str):
    """
    Soronkénti (append) írás a lemezre. O(1) RAM használat.
    A Git így csak az új sorokat fogja diff-ként tárolni, nem bloat-olja a repót.
    """
    init_memory_file()

    entry = {
        "timestamp": datetime.datetime.now().isoformat(),
        "category": category,
        "content": content
    }

    with open(MEMORY_FILE, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry) + "\n")

    print(f"🧠 Memória elmentve a lemezre! Kategória: {category}")

def read_memory(limit: int = 10, category_filter: str = None):
    """
    Visszaolvassa a memóriát. O(1) közeli futás, ha limitált számú sort olvasunk.
    Kereshetünk konkrét kategóriára is.
    """
    init_memory_file()

    results = []
    # Fájl visszafelé olvasása (tail), hogy a legfrissebb emlékeink legyenek elöl
    # Mivel a fájl kicsi lesz (<10MB), egyelőre betöltjük a sorokat, majd reverse.
    # Gigabájtos méretnél ezt optimalizálni kell igazi file-pointer tailinggel.
    try:
         with open(MEMORY_FILE, 'r', encoding='utf-8') as f:
            lines = f.readlines()

            for line in reversed(lines):
                if not line.strip(): continue
                try:
                    entry = json.loads(line)
                    if category_filter and entry.get("category") != category_filter:
                        continue

                    results.append(entry)
                    if len(results) >= limit:
                        break
                except json.JSONDecodeError:
                    continue
    except Exception as e:
         print(f"Hiba a memória olvasásakor: {e}")
         return []

    return results

def format_memory_for_agent(entries):
    """Emberi/Agent által olvasható formátumba önti a JSON kimenetet."""
    if not entries:
        return "A memória jelenleg üres vagy nem található releváns bejegyzés."

    output = "🧠 === AGENT HOSSZÚTÁVÚ MEMÓRIA === 🧠\n"
    for idx, entry in enumerate(entries, 1):
        output += f"[{idx}] {entry.get('timestamp', '')[:10]} | Téma: {entry.get('category', 'Általános')}\n"
        output += f"    Tartalom: {entry.get('content', '')}\n"
        output += "-" * 50 + "\n"
    return output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Agent Long-Term Memory Manager")
    parser.add_argument("--action", choices=["write", "read"], required=True, help="Írás vagy olvasás")
    parser.add_argument("--category", type=str, default="General", help="A memória kategóriája (pl. MLOps, RAG, Strategy)")
    parser.add_argument("--content", type=str, help="A memóriába írandó tartalom (csak --action write esetén)")
    parser.add_argument("--limit", type=int, default=5, help="Hány utolsó emléket olvassunk vissza (csak --action read esetén)")

    args = parser.parse_args()

    if args.action == "write":
        if not args.content:
            print("❌ Hiba: Írás esetén kötelező a --content megadása!")
        else:
            write_memory(args.category, args.content)

    elif args.action == "read":
        entries = read_memory(limit=args.limit, category_filter=args.category if args.category != "General" else None)
        print(format_memory_for_agent(entries))
