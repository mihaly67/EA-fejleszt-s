import faiss
import sqlite3
import numpy as np
import os
import sys
import argparse
from sentence_transformers import SentenceTransformer

def main():
    parser = argparse.ArgumentParser(description="SWAT RAG Interrogator - Deep Drill Edition")
    parser.add_argument("--query", type=str, required=True, help="A koncepcionális kérdés (funkció leírása, ne kód)")
    parser.add_argument("--category", type=str, default="", help="Szűrés kategóriára (pl. 'ML_Ops', 'Black_Ops')")
    parser.add_argument("--repo", type=str, default="", help="Szűrés repóra (pl. 'HellsGate')")
    parser.add_argument("--filepath", type=str, default="", help="Szűrés adott fájlnévre vagy útvonalra")
    parser.add_argument("--limit", type=int, default=3, help="Hány találatot adjon vissza (alap: 3)")
    parser.add_argument("--neighborhood", type=int, default=0, help="Hány előző és következő blokkot fűzzön hozzá a találathoz (pl. 2)")
    parser.add_argument("--expand_file", action="store_true", help="KASZKÁD FÚRÁS: Újraépíti az egész fájlt, amelyben a találat szerepel")
    args = parser.parse_args()

    # Próbáljuk megtalálni az aktuális adatbázist
    db_paths = [
        ("swat4_rag", "swat4_unified_compressed.index", "swat4_unified_knowledge.db"),
        ("Knowledge_Base/RAG_DB", "swat4_unified_compressed.index", "swat4_unified_knowledge.db"),
        ("Knowledge_Base/SWAT_DB", "SWAT4_RAG_compressed.index", "SWAT4_RAG.db")
    ]

    index_path = None
    sqlite_path = None

    for dir_name, idx_file, db_file in db_paths:
        if os.path.exists(os.path.join(dir_name, idx_file)) and os.path.exists(os.path.join(dir_name, db_file)):
            index_path = os.path.join(dir_name, idx_file)
            sqlite_path = os.path.join(dir_name, db_file)
            break

    if not index_path or not sqlite_path:
        print(f"❌ Error: Nem találtam érvényes RAG adatbázist a szokásos mappákban.")
        sys.exit(1)

    print(f"🧠 Modell betöltése (all-MiniLM-L6-v2)...")
    # Csendesebb modell betöltés
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        model = SentenceTransformer("all-MiniLM-L6-v2")

    print(f"📂 FAISS Index: {index_path}")
    index = faiss.read_index(index_path)

    print(f"🔌 SQLite DB: {sqlite_path}")
    conn = sqlite3.connect(sqlite_path)
    cursor = conn.cursor()

    # Ellenőrizzük a tábla sémáját, hogy a régi vagy az új van-e (visszafelé kompatibilitás)
    is_new_schema = ('filepath' in columns)

    print(f"🎯 Query kódolása: '{args.query}'")
    query_vector = model.encode([args.query]).astype('float32')

    k_search = max(1000, args.limit * 50)
    print(f"🔍 Vektoros keresés top {k_search} jelöltre...")
    distances, indices = index.search(query_vector, k_search)

    results = []

    # SQL alapok a séma függvényében
    if is_new_schema:
        sql_base = "SELECT id, 'Unknown', source_repo, filepath, content FROM rag_data WHERE id=?"
    else:
        sql_base = "SELECT id, 'Unknown', source, source, content FROM swat_data WHERE id=?"

    sql_params = []

    if is_new_schema:
        if args.category:
            sql_base += " AND category LIKE ?"
            sql_params.append(f"%{args.category}%")
        if args.repo:
            sql_base += " AND source_repo LIKE ?"
            sql_params.append(f"%{args.repo}%")
        if args.filepath:
            sql_base += " AND filepath LIKE ?"
            sql_params.append(f"%{args.filepath}%")

    for i in range(k_search):
        idx = int(indices[0][i])
        dist = distances[0][i]

        if idx == -1: continue

        cursor.execute(sql_base, [idx] + sql_params)
        row = cursor.fetchone()

        if row:
            db_id, category, source_repo, filepath, content = row

            # Ne adjunk vissza olyan fájlokat amiket már megtaláltunk ha expand_file aktív (deduplikáció)
            if args.expand_file and any(r['filepath'] == filepath for r in results):
                continue

            results.append({
                "id": db_id,
                "distance": dist,
                "category": category,
                "repo": source_repo,
                "filepath": filepath,
                "content": content
            })
            if len(results) >= args.limit:
                break

    print("\n" + "═"*80)
    print("🎯 RAG INTEL REPORT - DEEP DRILL EDITION 🎯")
    print("═"*80 + "\n")

    if not results:
        print("⚠️ Nem találtam egyezést a megadott vektoros és metaadat szűrőkkel.")
    else:
        for i, res in enumerate(results):
            print(f"[{i+1}] 📄 FÁJL: {res['filepath']}")
            print(f"    🏷️ KATEGÓRIA: {res['category']} | 📦 REPO: {res['repo']} | 📏 TÁVOLSÁG: {res['distance']:.4f} | 🔑 CÉL-ROWID: {res['id']}")
            print("-" * 80)

            table_name = "rag_data" if is_new_schema else "swat_data"

            # ---------------------------------------------------------
            # 1. KASZKÁD / EXPAND_FILE MÓD (A teljes fájl visszaállítása)
            # ---------------------------------------------------------
            if args.expand_file and res['filepath'] != 'Unknown':
                print(f"🔄 KASZKÁD FÚRÁS AKTÍV: A teljes '{res['filepath']}' fájl rekonstruálása...")
                # Kiszedjük az adott fájlhoz tartozó összes rekordot ROWID szerint sorbarendezve
                if is_new_schema:
                    cursor.execute(f"SELECT content FROM {table_name} WHERE filepath = ? AND source_repo = ? ORDER BY id ASC",
                                   (res['filepath'], res['repo']))
                else:
                    cursor.execute(f"SELECT content FROM {table_name} WHERE source = ? ORDER BY id ASC",
                                   (res['filepath'],))

                all_chunks = cursor.fetchall()

                if all_chunks:
                    print(f"   ✓ {len(all_chunks)} adatbázis blokk összefűzve.\n")
                    print("⬇️ --- [REKONSTRUÁLT FÁJL KEZDETE] --- ⬇️\n")

                    full_text = ""
                    for chunk in all_chunks:
                        # Ha van overlap (átfedés), egy okosabb összefűzés is lehetséges lenne, de
                        # az egyszerűség kedvéért egyelőre csak kiírjuk őket egymás után egy vizuális elválasztóval.
                        full_text += chunk[0] + "\n...[CHUNK_BOUNDARY]...\n"

                    print(full_text)
                    print("⬆️ --- [REKONSTRUÁLT FÁJL VÉGE] --- ⬆️\n")
                else:
                    print("⚠️ Hiba a fájl rekonstruálása közben.")

            # ---------------------------------------------------------
            # 2. SZOMSZÉDSÁG / NEIGHBORHOOD MÓD (Kibővített kontextus)
            # ---------------------------------------------------------
            elif args.neighborhood > 0:
                print(f"🔍 SZOMSZÉDSÁG AKTÍV (±{args.neighborhood} blokk)")

                # Előző blokkok lekérdezése
                cursor.execute(f"SELECT id, content FROM {table_name} WHERE id >= ? AND id < ? ORDER BY id ASC",
                               (res['id'] - args.neighborhood, res['id']))
                prev_rows = cursor.fetchall()

                for pr_id, pr_content in prev_rows:
                    print(f"--- [ELŐZŐ KONTEXTUS (ROWID: {pr_id})] ---")
                    print(pr_content + "\n")

                print(f"--- [🎯 CÉL KONTEXTUS (ROWID: {res['id']})] ---")
                print(res['content'] + "\n")

                # Következő blokkok lekérdezése
                cursor.execute(f"SELECT id, content FROM {table_name} WHERE id > ? AND id <= ? ORDER BY id ASC",
                               (res['id'], res['id'] + args.neighborhood))
                next_rows = cursor.fetchall()

                for nx_id, nx_content in next_rows:
                    print(f"--- [KÖVETKEZŐ KONTEXTUS (ROWID: {nx_id})] ---")
                    print(nx_content + "\n")

            # ---------------------------------------------------------
            # 3. NORMÁL MÓD (Csak a cél chunk)
            # ---------------------------------------------------------
            else:
                print("--- [CÉL KONTEXTUS] ---")
                print(res['content'] + "\n")
                print("💡 Tipp: Használd a '--neighborhood 2' vagy '--expand_file' kapcsolókat a teljesebb képért!")

            print("═"*80 + "\n")

    conn.close()

if __name__ == "__main__":
    main()
