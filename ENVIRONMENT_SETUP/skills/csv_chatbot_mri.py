# Autonomous Agent Skill: CSV Chatbot (OOM-Safe Agent-to-Bot Interface)
# Memória-optimalizált nagy fájl feldolgozás Pandas chunksize használatával
# Az Agent ezt bash scripteken keresztül hívja és "chatel" vele a paramétereken keresztül.
import argparse
import pandas as pd
import time
import os

def analyze_csv(filepath: str, query: str, chunksize: int = 10000):
    if not os.path.exists(filepath):
        print(f"❌ Hiba: A fájl nem található: {filepath}")
        return

    print(f"🤖 [Agent-Bot Comms] Elemzési kérés fogadva.")
    print(f"📊 [CSV ChatBot] Fájl: {filepath}")
    print(f"📊 [CSV ChatBot] Keresés (Prompt): {query}")

    total_rows = 0
    match_count = 0

    try:
        # MRI-szintű mélyfúrás nagy CSV-khez memory leak nélkül
        for chunk in pd.read_csv(filepath, chunksize=chunksize):
            total_rows += len(chunk)

            mask = chunk.astype(str).apply(lambda x: x.str.contains(query, case=False, na=False)).any(axis=1)
            matches = chunk[mask]
            match_count += len(matches)

            print(f"⏳ Feldolgozva: {total_rows} sor... Találatok: {match_count}", flush=True)
            time.sleep(0.01)

        print(f"✅ [CSV ChatBot Válasz] Elemzés kész. Összes sor: {total_rows}, Találatok: {match_count}")
        print("🧠 [Agent Prompt] Az adatok elemzése sikeres, folytathatod a stratégiai feldolgozást.")

    except MemoryError:
        print("❌ [CSV ChatBot] MEMORY ERROR! Próbálja csökkenteni a chunksize-t!")
    except Exception as e:
        print(f"❌ [CSV ChatBot] Hiba történt: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OOM-Safe CSV Chatbot for Agent Comms")
    parser.add_argument("--file", required=True, help="A CSV fájl elérési útja")
    parser.add_argument("--query", required=True, help="A keresendő kifejezés vagy logika")
    parser.add_argument("--chunk", type=int, default=10000, help="Chunk méret")
    args = parser.parse_args()

    analyze_csv(args.file, args.query, args.chunk)
