import faiss
import sqlite3
import numpy as np
import os
import sys
import argparse
from sentence_transformers import SentenceTransformer

def main():
    parser = argparse.ArgumentParser(description="SWAT RAG Query")
    parser.add_argument("--query", type=str, required=True, help="A koncepcionális kérdés (funkció leírása, nem szintaxis)")
    parser.add_argument("--source", type=str, default="", help="SQL Szűrés a 'source' oszlopra (pl. 'Black_Ops', '.c')")
    parser.add_argument("--limit", type=int, default=5, help="Hány találatot adjon vissza")
    parser.add_argument("--neighborhood", action="store_true", help="Keresse ki a megelőző és következő ROWID-t is a teljes kontextushoz")
    args = parser.parse_args()

    db_dir = "Knowledge_Base/SWAT_DB"
    index_path = os.path.join(db_dir, "swat_unified_compressed.index")
    sqlite_path = os.path.join(db_dir, "swat_unified.db")
    model_name = "all-MiniLM-L6-v2"

    if not os.path.exists(index_path):
        print(f"❌ Error: Index file nem található: {index_path}")
        sys.exit(1)
    if not os.path.exists(sqlite_path):
        print(f"❌ Error: SQLite DB nem található: {sqlite_path}")
        sys.exit(1)

    print(f"🧠 Modell betöltése: {model_name}...")
    model = SentenceTransformer(model_name)

    print(f"📂 FAISS Index betöltése: {index_path}...")
    index = faiss.read_index(index_path)

    print(f"🔌 Kapcsolódás SQLite-hoz: {sqlite_path}...")
    conn = sqlite3.connect(sqlite_path)
    cursor = conn.cursor()

    print(f"🎯 Query kódolása: '{args.query}'")
    query_vector = model.encode([args.query]).astype('float32')

    # FAISS Keresés (a hibrid szűrést utólag kell csinálnunk FAISS-nál, ezért sokat kérünk le)
    k_search = max(500, args.limit * 10)
    print(f"🔍 Vektoros keresés top {k_search} jelöltre...")
    distances, indices = index.search(query_vector, k_search)

    results = []

    for i in range(k_search):
        idx = int(indices[0][i])
        dist = distances[0][i]

        if idx == -1: continue

        # Metaadat szűrés SQL-ben (Hibrid Szűrő Taktika 1. pont)
        if args.source:
            cursor.execute("SELECT id, source, content FROM swat_data WHERE id=? AND source LIKE ?", (idx, f"%{args.source}%"))
        else:
            cursor.execute("SELECT id, source, content FROM swat_data WHERE id=?", (idx,))

        row = cursor.fetchone()
        if row:
            db_id, source, content = row
            results.append({
                "id": db_id,
                "distance": dist,
                "source": source,
                "content": content
            })
            if len(results) >= args.limit:
                break

    print("\n" + "="*50)
    print("=== 🎯 RAG INTEL REPORT ===")
    print("="*50 + "\n")

    if not results:
        print("⚠️ Nem találtam egyezést a megadott szűrőkkel.")
    else:
        for i, res in enumerate(results):
            print(f"\n[{i+1}] 📄 SOURCE: {res['source']} | DISTANCE: {res['distance']:.4f} | ROWID: {res['id']}")
            print("-" * 40)

            # Szomszédság lekérdezése (Taktika 3. pont)
            if args.neighborhood:
                print("--- [ELŐZŐ KONTEXTUS (ROWID-1)] ---")
                cursor.execute("SELECT content FROM swat_data WHERE id=?", (res['id'] - 1,))
                prev_row = cursor.fetchone()
                if prev_row:
                    print(prev_row[0][:300] + "...\n")

            print("--- [CÉL KONTEXTUS] ---")
            print(res['content'] + "\n")

            if args.neighborhood:
                print("--- [KÖVETKEZŐ KONTEXTUS (ROWID+1)] ---")
                cursor.execute("SELECT content FROM swat_data WHERE id=?", (res['id'] + 1,))
                next_row = cursor.fetchone()
                if next_row:
                    print(next_row[0][:300] + "...\n")

            print("="*50)

    conn.close()

if __name__ == "__main__":
    main()
