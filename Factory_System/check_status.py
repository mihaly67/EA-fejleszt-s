
import sys
import os

# Ensure the current directory is in the path so we can import the agent
sys.path.append(os.getcwd())

try:
    from kutato_ugynok_v3 import load_resources
except ImportError:
    print("Hiba: Nem sikerult importalni a kutato_ugynok_v3 modult.")
    sys.exit(1)

def main():
    print("--- RAG Diagnosztika Inditasa ---")
    try:
        # Update: load_resources now returns 3 values (docs, model, bm25)
        docs, model, bm25 = load_resources()
    except ValueError:
        # Fallback for backward compatibility if the file wasn't updated correctly
        try:
             docs, model = load_resources()
             print("Figyelem: Regi load_resources szignatura detektalva.")
        except:
             print("Hiba: Nem sikerult a load_resources hivas.")
             return
    except SystemExit:
        print("Hiba: A betoltes soran a script kilepett (valoszinu ures adatbazis).")
        return
    except Exception as e:
        print(f"Kritikus hiba a betoltesnel: {e}")
        return

    total_docs = len(docs)
    elmelet_count = 0
    kod_count = 0
    other_count = 0

    # Analyze sources
    sources = {}

    for doc in docs:
        stype = doc.get('source_type', 'ISMERETLEN')
        if stype == 'ELMELET':
            elmelet_count += 1
        elif stype == 'KOD':
            kod_count += 1
        else:
            other_count += 1

        # Optional: track origin files
        origin = doc.get('origin_file', 'unknown')
        sources[origin] = sources.get(origin, 0) + 1

    print("\n" + "="*40)
    print(f"RAG STATUSZ JELENTES")
    print("="*40)
    print(f"Osszes dokumentum (chunk): {total_docs}")
    print(f" - ELMELET (Theory):       {elmelet_count}")
    print(f" - KOD (Codebase):         {kod_count}")
    print(f" - EGYEB:                  {other_count}")
    print("-" * 40)
    print("Forras fajlok eloszlasa:")
    for src, count in sorted(sources.items(), key=lambda item: item[1], reverse=True)[:10]: # Top 10 files
        print(f"  - {src}: {count} db")
    if len(sources) > 10:
        print(f"  ... es tovabbi {len(sources)-10} fajl.")
    print("="*40)

if __name__ == "__main__":
    main()
