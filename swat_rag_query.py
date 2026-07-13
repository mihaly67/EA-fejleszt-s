import faiss
import sqlite3
import numpy as np
import os
import sys
from sentence_transformers import SentenceTransformer

def main():
    print("=== 🕵️ SWAT RAG SNIPER QUERY SYSTEM (FAISS ENGINE) ===")

    # Configuration
    db_dir = "Knowledge_Base/SWAT_DB"
    index_path = os.path.join(db_dir, "swat_unified_compressed.index")
    sqlite_path = os.path.join(db_dir, "swat_unified.db")
    model_name = "all-MiniLM-L6-v2"

    # Sniper Configuration
    target_source = "Black_Ops" # Filter by source if needed, or set to None
    query_text = "Frida hook GetCursorPos intercept hardware ID spoofing MT5 Windows API"

    # Validation
    if not os.path.exists(index_path):
        print(f"❌ Error: Index file not found at {index_path}")
        sys.exit(1)
    if not os.path.exists(sqlite_path):
        print(f"❌ Error: SQLite DB not found at {sqlite_path}")
        sys.exit(1)

    try:
        # 1. Load Model
        print(f"🧠 Loading Embedding Model: {model_name}...")
        model = SentenceTransformer(model_name)

        # 2. Load FAISS Index
        print(f"📂 Loading FAISS Index from: {index_path}...")
        index = faiss.read_index(index_path)
        print(f"   Index size: {index.ntotal} vectors")

        # 3. Connect to SQLite
        print(f"🔌 Connecting to SQLite DB: {sqlite_path}...")
        conn = sqlite3.connect(sqlite_path)
        cursor = conn.cursor()

        # 4. Embed Query
        print(f"🎯 Encoding Query: '{query_text}'")
        query_vector = model.encode([query_text])
        # FAISS expects float32
        query_vector = np.array(query_vector).astype('float32')

        # 5. Search (Retrieve top 50 candidates to allow for filtering)
        k = 50
        print(f"🔍 Searching top {k} candidates...")
        # Faiss search returns distances and indices
        distances, indices = index.search(query_vector, k)

        # 6. Filter & Fetch Results
        print(f"🔎 Applying Sniper Filter (source LIKE '%{target_source}%')...")

        # Prepare result list
        final_results = []

        # Check candidates
        for i in range(k):
            idx = indices[0][i]
            dist = distances[0][i]

            if idx == -1: continue # Invalid index

            # Fetch metadata from DB
            # Corrected table name: swat_data
            # Corrected columns: id, source, content (filename is missing in schema)
            cursor.execute("SELECT source, content FROM swat_data WHERE id=?", (int(idx),))
            row = cursor.fetchone()

            if row:
                source, content = row
                # Sniper Filter
                if target_source and target_source.lower() not in str(source).lower():
                    continue

                final_results.append({
                    "distance": dist,
                    "source": source,
                    "content": content
                })
                if len(final_results) >= 3:
                    break # Found top 3 matching criteria

        # 7. Display Results
        print("\n=== 🎯 INTELLIGENCE REPORT ===\n")

        if not final_results:
            print(f"⚠️ NO INTEL FOUND matching filter '{target_source}'.")
            print("   (Try widening the search or checking the source name in the DB).")
        else:
            for i, res in enumerate(final_results):
                # Convert L2 distance to similarity score if needed, or just display raw
                # FAISS usually returns L2 (smaller is better) or Inner Product (larger is better).
                # Assuming L2 for standard IndexFlatL2 or IVFFlat.
                dist = res['distance']

                # Loose signal strength interpretation for L2
                # This depends heavily on the vector space normalization.
                status = "UNKNOWN"
                if dist < 0.5: status = "✅ [CONFIRMED INTEL]"
                elif dist < 1.0: status = "⚠️ [POSSIBLE INTEL]"
                else: status = "❌ [WEAK SIGNAL]"

                print(f"--- Result {i+1} (Distance: {dist:.4f}) ---")
                print(f"STATUS: {status}")
                print(f"📄 Source: {res['source']}")
                print(f"📝 Content Snippet:\n{str(res['content'])[:1000]}...")
                print("-" * 50)

        conn.close()

    except Exception as e:
        print(f"❌ An error occurred: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
