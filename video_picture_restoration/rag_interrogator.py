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
    parser = argparse.ArgumentParser(description="AI PICTURE & VIDEO RESTORATION - RAG Query")
    parser.add_argument("--query", type=str, required=True, help="A koncepcionális kérdés (pl. 'How to upsample video frames')")
    parser.add_argument("--repo", type=str, default="", help="Szűrés forrás repóra (pl. 'BasicSR-master')")
    parser.add_argument("--lang", type=str, default="", help="Szűrés programnyelvre (pl. 'Python', 'C++', 'Vue')")
    parser.add_argument("--type", type=str, default="", help="Szűrés fájltípusra (pl. 'Code', 'Documentation')")
    parser.add_argument("--limit", type=int, default=5, help="Hány találatot adjon vissza")
    parser.add_argument("--neighborhood", action="store_true", help="Keresse ki a megelőző és következő ROWID-t is")
    args = parser.parse_args()

    work_dir = get_script_dir()
    db_dir = os.path.join(work_dir, "Knowledge_Base", "RAG_DB")

    index_path = os.path.join(db_dir, "video_picture_restoration_compressed.index")
    sqlite_path = os.path.join(db_dir, "video_picture_restoration_knowledge.db")
    model_name = "all-MiniLM-L6-v2"

    if not os.path.exists(index_path) or not os.path.exists(sqlite_path):
        print(f"❌ Error: A RAG adatbázis fájlok nem találhatóak a {db_dir} mappában.")
        print("💡 Próbáld meg lefuttatni a 'python3 restore_env_pv.py' scriptet!")
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
    sql_base = "SELECT id, source_repo, filepath, language, file_type, content FROM rag_data WHERE id=?"
    sql_params = []

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
            db_id, source_repo, filepath, language, file_type, content = row
            results.append({
                "id": db_id,
                "distance": dist,
                "repo": source_repo,
                "filepath": filepath,
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
            print(f"[{i+1}] 📄 FÁJL: {res['filepath']}")
            print(f"    📦 REPO: {res['repo']} | 🔤 NYELV: {res['language']} | 📋 TÍPUS: {res['type']}")
            print(f"    📏 TÁVOLSÁG: {res['distance']:.4f} | 🔑 ROWID: {res['id']}")
            print("-" * 70)

            if args.neighborhood:
                print("--- [ELŐZŐ KONTEXTUS (ROWID-1)] ---")
                cursor.execute("SELECT content FROM rag_data WHERE id=?", (res['id'] - 1,))
                prev_row = cursor.fetchone()
                if prev_row: print(prev_row[0][:300] + "...\n")

            print("--- [CÉL KONTEXTUS] ---")
            print(res['content'] + "\n")

            if args.neighborhood:
                print("--- [KÖVETKEZŐ KONTEXTUS (ROWID+1)] ---")
                cursor.execute("SELECT content FROM rag_data WHERE id=?", (res['id'] + 1,))
                next_row = cursor.fetchone()
                if next_row: print(next_row[0][:300] + "...\n")

            print("="*70 + "\n")

    conn.close()

if __name__ == "__main__":
    main()
