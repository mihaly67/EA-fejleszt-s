
import faiss
import sqlite3
import numpy as np
import os
import sys
import argparse
from sentence_transformers import SentenceTransformer

def fetch_file_content(cursor, filepath, source_repo):
    try:
        cursor.execute("SELECT chunk_text FROM chunk_metadata WHERE filepath = ? ORDER BY chunk_id ASC", (filepath,))
        all_chunks = cursor.fetchall()
        if all_chunks:
            full_text = ""
            for chunk in all_chunks:
                full_text += chunk[0] + "\n"
            return full_text
    except Exception as e:
        pass
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", type=str, required=True)
    parser.add_argument("--deep_drill", action="store_true")
    parser.add_argument("--limit", type=int, default=3)
    args = parser.parse_args()

    index_path = "Knowledge_Base/External_Repos/gui_rag_faiss.index"
    sqlite_path = "Knowledge_Base/External_Repos/gui_rag.db"

    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        model = SentenceTransformer("all-MiniLM-L6-v2")

    index = faiss.read_index(index_path)
    conn = sqlite3.connect(sqlite_path)
    cursor = conn.cursor()

    query_vector = model.encode([args.query]).astype('float32')
    distances, indices = index.search(query_vector, max(50, args.limit * 10))

    results = []
    seen = set()

    for i in range(len(indices[0])):
        idx = int(indices[0][i])
        # FAISS 0-based indexing maps to chunk_id 1-based
        # Actually FAISS might map to exactly the ID inserted.
        cursor.execute("SELECT chunk_id, filepath, repo_name, chunk_text FROM chunk_metadata WHERE chunk_id=?", (idx,))
        row = cursor.fetchone()
        if not row:
            cursor.execute("SELECT chunk_id, filepath, repo_name, chunk_text FROM chunk_metadata WHERE chunk_id=?", (idx + 1,))
        row = cursor.fetchone()

        if row:
            db_id, filepath, repo, content = row
            if filepath in seen: continue
            seen.add(filepath)

            if args.deep_drill:
                full = fetch_file_content(cursor, filepath, repo)
                if full: content = full

            results.append({"filepath": filepath, "repo": repo, "content": content})
            if len(results) >= args.limit:
                break

    print("\n" + "═"*80)
    print(f"🎯 DEEP RAG RESULTS FOR: '{args.query}'")
    print("═"*80 + "\n")

    for i, res in enumerate(results):
        print(f"[{i+1}] 📄 FÁJL: {res['filepath']} | 📦 REPO: {res['repo']}")
        print("-" * 80)
        c = res['content']
        if len(c) > 3000:
            print(c[:3000] + "\n... [TRUNCATED] ...")
        else:
            print(c)
        print("═"*80 + "\n")

    conn.close()

if __name__ == "__main__":
    main()
