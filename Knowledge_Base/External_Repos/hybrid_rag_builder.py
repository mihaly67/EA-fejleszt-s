import os
import sqlite3
import argparse
import sys
from sentence_transformers import SentenceTransformer
import faiss
import numpy as np
import json

DB_DIR = os.path.dirname(os.path.abspath(__file__))
SQLITE_DB_PATH = os.path.join(DB_DIR, 'gui_rag.db')
FAISS_INDEX_PATH = os.path.join(DB_DIR, 'gui_rag_faiss.index')

EXTENSIONS = ('.py', '.md', '.txt', '.cpp', '.h', '.js', '.ts', '.jsx', '.tsx')
MODEL_NAME = "all-MiniLM-L6-v2"

# === 1. BUILD / INDEX ===
def build_hybrid_db(root_dir):
    print(f"🚀 Building Advanced Hybrid RAG from: {root_dir}")
    conn = sqlite3.connect(SQLITE_DB_PATH)
    c = conn.cursor()

    # Create FTS5 for Keyword Search
    c.execute("DROP TABLE IF EXISTS codesearch")
    c.execute('''CREATE VIRTUAL TABLE codesearch USING fts5(
                 repo_name, filepath, line_num UNINDEXED, chunk_id UNINDEXED, content)''')

    # Create Metadata Table for Graph/Logical relations
    c.execute("DROP TABLE IF EXISTS chunk_metadata")
    c.execute('''CREATE TABLE chunk_metadata (
                 chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
                 repo_name TEXT,
                 filepath TEXT,
                 start_line INTEGER,
                 end_line INTEGER,
                 chunk_text TEXT
                 )''')

    print(f"🧠 Loading Embedding Model: {MODEL_NAME}...")
    model = SentenceTransformer(MODEL_NAME)

    # 384 is the dimension size for all-MiniLM-L6-v2
    faiss_index = faiss.IndexFlatL2(384)

    chunk_id_counter = 1
    total_lines = 0

    print("📂 Scanning files and chunking...")
    for subdir, dirs, files in os.walk(root_dir):
        # Exclude common large/unneeded directories
        dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', '__pycache__', 'build', 'dist', 'docs', 'tests', 'test', 'examples', 'charting-library-tutorial']]

        for file in files:
            if not file.endswith(EXTENSIONS):
                continue

            # Skip massive minified JS files
            if file.endswith('.min.js') or 'min' in file:
                continue

            filepath = os.path.join(subdir, file)
            repo_name = filepath.split("External_Repos/")[-1].split("/")[0]
            rel_path = filepath.split("External_Repos/")[-1]

            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

                # Chunking strategy: 10 lines per chunk with 2 lines overlap
                chunk_size = 10
                overlap = 2

                i = 0
                while i < len(lines):
                    chunk_lines = lines[i:i + chunk_size]
                    if not chunk_lines: break

                    chunk_text = "".join(chunk_lines).strip()
                    if len(chunk_text) < 10: # Skip empty/tiny chunks
                        i += (chunk_size - overlap)
                        continue

                    # 1. Save to Metadata (Logical Layer)
                    start_line = i + 1
                    end_line = i + len(chunk_lines)
                    c.execute("INSERT INTO chunk_metadata (chunk_id, repo_name, filepath, start_line, end_line, chunk_text) VALUES (?, ?, ?, ?, ?, ?)",
                              (chunk_id_counter, repo_name, rel_path, start_line, end_line, chunk_text))

                    # 2. Save to FTS5 (Keyword Layer)
                    for j, line in enumerate(chunk_lines):
                        clean_line = line.strip()
                        if clean_line:
                            c.execute("INSERT INTO codesearch (repo_name, filepath, line_num, chunk_id, content) VALUES (?, ?, ?, ?, ?)",
                                      (repo_name, rel_path, start_line + j, chunk_id_counter, clean_line))
                            total_lines += 1

                    # 3. Vectorize and save to FAISS (Semantic Layer)
                    vec = model.encode([chunk_text])[0]
                    faiss_index.add(np.array([vec]).astype('float32'))

                    chunk_id_counter += 1
                    i += (chunk_size - overlap)

            except Exception as e:
                pass # Skip unreadable files

    conn.commit()
    conn.close()

    # Save FAISS index
    faiss.write_index(faiss_index, FAISS_INDEX_PATH)

    print(f"✅ Hybrid DB built: {total_lines} lines across {chunk_id_counter-1} semantic chunks.")
    print(f"   SQLite saved to: {SQLITE_DB_PATH}")
    print(f"   FAISS saved to: {FAISS_INDEX_PATH}")


# === 2. SEARCH ===
def hybrid_search(query_str, limit=5, repo_filter=None):
    if not os.path.exists(SQLITE_DB_PATH) or not os.path.exists(FAISS_INDEX_PATH):
        print("❌ Database not found. Run with --build first.")
        return

    print(f"🔍 Executing Hybrid RRF Search for: '{query_str}'")

    conn = sqlite3.connect(SQLITE_DB_PATH)
    c = conn.cursor()

    # A. Semantic Search (FAISS)
    print("🧠 1/3: Running Semantic Vector Search...")
    model = SentenceTransformer(MODEL_NAME)
    query_vector = model.encode([query_str]).astype('float32')

    faiss_index = faiss.read_index(FAISS_INDEX_PATH)
    # Search top 20 to allow for RRF merging
    D, I = faiss_index.search(query_vector, 20)

    semantic_ranks = {}
    for rank, chunk_idx in enumerate(I[0]):
        if chunk_idx != -1:
            # FAISS index is 0-based, our chunk_id is 1-based
            semantic_ranks[chunk_idx + 1] = rank + 1

    # B. Keyword Search (FTS5 BM25)
    print("🔑 2/3: Running Exact Keyword Search (BM25)...")
    # Simple expansion
    words = [w for w in query_str.split() if w.lower() not in ["how", "to", "what", "is", "a", "the", "in", "for", "with"]]
    fts_query = " OR ".join([f'"{w}"*' for w in words])

    c.execute('''SELECT chunk_id, rank
                 FROM codesearch
                 WHERE content MATCH ?
                 GROUP BY chunk_id
                 ORDER BY rank LIMIT 20''', (fts_query,))

    keyword_ranks = {}
    for rank, row in enumerate(c.fetchall()):
        chunk_id = row[0]
        keyword_ranks[chunk_id] = rank + 1

    # C. Reciprocal Rank Fusion (RRF) & Logical Filtering
    print("🧬 3/3: Merging with Reciprocal Rank Fusion (RRF)...")
    k = 60 # Standard RRF constant

    combined_scores = {}
    all_chunks = set(semantic_ranks.keys()).union(set(keyword_ranks.keys()))

    for chunk_id in all_chunks:
        score = 0.0
        if chunk_id in semantic_ranks:
            score += 1.0 / (k + semantic_ranks[chunk_id])
        if chunk_id in keyword_ranks:
            score += 1.0 / (k + keyword_ranks[chunk_id])

        combined_scores[chunk_id] = score

    # Sort by RRF score descending
    sorted_chunks = sorted(combined_scores.items(), key=lambda x: x[1], reverse=True)

    # D. Display Results via Logical Metadata Table
    print("\n" + "="*80)
    print("🏆 TOP HYBRID RESULTS")
    print("="*80)

    displayed = 0
    for chunk_id, score in sorted_chunks:
        if displayed >= limit: break

        c.execute("SELECT repo_name, filepath, start_line, end_line, chunk_text FROM chunk_metadata WHERE chunk_id = ?", (chunk_id,))
        row = c.fetchone()
        if not row: continue

        repo_name, filepath, start_line, end_line, chunk_text = row

        # Apply strict logical filtering if requested
        if repo_filter and repo_filter.lower() not in repo_name.lower():
            continue

        print(f"\n📂 [{repo_name}] {filepath} (Lines {start_line}-{end_line}) | RRF Score: {score:.4f}")

        # Show origin of match
        match_types = []
        if chunk_id in semantic_ranks: match_types.append(f"Semantic (Rank {semantic_ranks[chunk_id]})")
        if chunk_id in keyword_ranks: match_types.append(f"Keyword (Rank {keyword_ranks[chunk_id]})")
        print(f"🔎 Matched via: {' + '.join(match_types)}")

        print("-" * 80)
        print(chunk_text)
        print("-" * 80)

        displayed += 1

    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Advanced Hybrid RAG for GUI Repos (Semantic + Keyword + Graph)")
    parser.add_argument("--build", action="store_true", help="Build the vector and keyword databases")
    parser.add_argument("--query", type=str, help="Natural language query")
    parser.add_argument("--repo", type=str, default=None, help="Filter by repository name (Logical layer)")
    parser.add_argument("--limit", type=int, default=3, help="Number of results to show")

    args = parser.parse_args()

    if args.build:
        build_hybrid_db(DB_DIR)

    if args.query:
        hybrid_search(args.query, args.limit, args.repo)
