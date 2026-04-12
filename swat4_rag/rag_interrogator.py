import faiss
import sqlite3
import numpy as np
import os
import sys
import argparse
from sentence_transformers import SentenceTransformer

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def main():
    parser = argparse.ArgumentParser(description="SWAT4 (ML-OPS, BLACK_OPS) - RAG Query")
    parser.add_argument("--query", type=str, required=True, help="A koncepcionális kérdés (pl. 'How to hook NtAllocateVirtualMemory')")
    parser.add_argument("--category", type=str, default="", help="Szűrés kategóriára (pl. 'ML_Ops', 'Black_Ops', 'Thief', 'Colombo')")
    parser.add_argument("--repo", type=str, default="", help="Szűrés forrás repóra (pl. 'HellsGate')")
    parser.add_argument("--lang", type=str, default="", help="Szűrés programnyelvre (pl. 'Python', 'C++', 'Vue')")
    parser.add_argument("--type", type=str, default="", help="Szűrés fájltípusra (pl. 'Code', 'Documentation')")
    parser.add_argument("--limit", type=int, default=5, help="Hány találatot adjon vissza")
    parser.add_argument("--expand_file", action="store_true", help="SZÉLESSÉGI KERESÉS: Rekonstruálja az EGÉSZ FÁJLT a megtalált chunk alapján")
    parser.add_argument("--neighborhood", action="store_true", help="Keresse ki a megelőző és következő CHUNK-ot is")
    args = parser.parse_args()

    work_dir = get_script_dir()
    db_dir = os.path.join(work_dir, "Knowledge_Base", "RAG_DB")

    index_path = os.path.join(db_dir, "swat4_unified_compressed.index")
    sqlite_path = os.path.join(db_dir, "swat4_unified_knowledge.db")
    model_name = "all-MiniLM-L6-v2"

    if not os.path.exists(index_path) or not os.path.exists(sqlite_path):
        print(f"❌ Error: A RAG adatbázis fájlok nem találhatóak a {db_dir} mappában.")
        print("💡 Próbáld meg lefuttatni a 'python3 restore_envSWAT4.py' scriptet!")
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

    k_search = max(1000, args.limit * 20) # Nagyobb merítés kell a sok metadata szűrés miatt
    print(f"🔍 Vektoros keresés top {k_search} jelöltre...")
    distances, indices = index.search(query_vector, k_search)

    results = []

    # Dinamikus SQL felépítése a szűrőkhöz
    sql_base = "SELECT id, category, source_repo, filepath, chunk_index, language, file_type, content FROM rag_data WHERE id=?"
    sql_params = []

    if args.category:
        sql_base += " AND category LIKE ?"
        sql_params.append(f"%{args.category}%")
    if args.repo:
        sql_base += " AND source_repo LIKE ?"
        sql_params.append(f"%{args.repo}%")
    if args.lang:
        sql_base += " AND language LIKE ?"
        sql_params.append(f"%{args.lang}%")
    if args.type:
        sql_base += " AND file_type LIKE ?"
        sql_params.append(f"%{args.type}%")

    for i in range(k_search):
        idx = int(indices[0][i])
        dist = distances[0][i]

        if idx == -1: continue

        cursor.execute(sql_base, [idx] + sql_params)
        row = cursor.fetchone()

        if row:
            db_id, category, source_repo, filepath, chunk_index, language, file_type, content = row

            # Hogy ne adjuk vissza ugyanazt a fájlt (másik chunk-ját) többször is,
            # szűrjük, ha az elérési út már szerepel a limitált listában:
            if not any(r['filepath'] == filepath for r in results):
                results.append({
                    "id": db_id,
                    "distance": dist,
                    "category": category,
                    "repo": source_repo,
                    "filepath": filepath,
                    "chunk_index": chunk_index,
                    "language": language,
                    "type": file_type,
                    "content": content
                })

                if len(results) >= args.limit:
                    break

    print("\n" + "="*70)
    print("=== 🎯 RAG INTEL REPORT ===")
    print("="*70 + "\n")

    if not results:
        print("⚠️ Nem találtam egyezést a megadott (metaadat) szűrőkkel.")
    else:
        for i, res in enumerate(results):
            print(f"[{i+1}] 📄 FÁJL: {res['filepath']} (Chunk: {res['chunk_index']})")
            print(f"    🏷️ KATEGÓRIA: {res['category']} | 📦 REPO: {res['repo']}")
            print(f"    🔤 NYELV: {res['language']} | 📋 TÍPUS: {res['type']} | 📏 TÁVOLSÁG: {res['distance']:.4f} | 🔑 ROWID: {res['id']}")
            print("-" * 70)

            if args.expand_file:
                # Kaszkád Keresés: Lekérjük az EGÉSZ fájlt a megtalált filepath alapján
                print("--- [SZÉLESSÉGI KERESÉS: TELJES FÁJL REKONSTRUKCIÓ] ---")
                cursor.execute("SELECT content FROM rag_data WHERE filepath=? ORDER BY chunk_index ASC", (res['filepath'],))
                all_chunks = cursor.fetchall()
                full_file_text = "\n[...]\n".join([chunk[0] for chunk in all_chunks])
                print(full_file_text + "\n")

            else:
                if args.neighborhood:
                    print("--- [ELŐZŐ CHUNK KONTEXTUS] ---")
                    # Lekérjük a megelőző chunk-ot ugyanabból a fájlból
                    cursor.execute("SELECT content FROM rag_data WHERE filepath=? AND chunk_index=?", (res['filepath'], res['chunk_index'] - 1))
                    prev_chunk = cursor.fetchone()
                    if prev_chunk: print(prev_chunk[0][:500] + "...\n")

                print(f"--- [CÉL KONTEXTUS (CHUNK {res['chunk_index']})] ---")
                print(res['content'] + "\n")

                if args.neighborhood:
                    print("--- [KÖVETKEZŐ CHUNK KONTEXTUS] ---")
                    # Lekérjük a következő chunk-ot ugyanabból a fájlból
                    cursor.execute("SELECT content FROM rag_data WHERE filepath=? AND chunk_index=?", (res['filepath'], res['chunk_index'] + 1))
                    next_chunk = cursor.fetchone()
                    if next_chunk: print(next_chunk[0][:500] + "...\n")

            print("="*70 + "\n")

    conn.close()

if __name__ == "__main__":
    main()
