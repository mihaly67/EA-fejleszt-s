import sqlite3
import argparse
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'gui_rag.db')

def expand_query(query_str):
    """Simple query expansion for common HUD/GUI terms."""
    query = query_str.lower()
    keywords = query.split()

    fts_terms = []
    for word in keywords:
        if word in ["how", "to", "what", "is", "a", "the", "in", "for", "with"]:
            continue
        fts_terms.append(f'"{word}"*')

    return " AND ".join(fts_terms)

def search_context(query_str, limit=5):
    if not os.path.exists(DB_PATH):
        print("❌ Error: gui_rag.db not found! Run gui_rag_builder.py --build first.")
        return

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    fts_query = expand_query(query_str)
    print(f"🤖 Interrogator Query: {fts_query}\n" + "="*80)

    try:
        # Search FTS5 and grab surrounding context (+/- 5 lines) by using line_num proximity
        c.execute('''
            SELECT c1.repo_name, c1.filepath, c1.line_num, c1.content
            FROM codesearch c1
            JOIN (
                SELECT repo_name, filepath, line_num, rank
                FROM codesearch
                WHERE content MATCH ?
                ORDER BY rank LIMIT ?
            ) c2 ON c1.repo_name = c2.repo_name AND c1.filepath = c2.filepath
            WHERE c1.line_num BETWEEN c2.line_num - 5 AND c2.line_num + 15
            ORDER BY c2.rank, c1.filepath, c1.line_num
        ''', (fts_query, limit))

        results = c.fetchall()

        if not results:
            print("No matches found. Try simplifying your query words.")
        else:
            current_file = ""
            for row in results:
                repo, filepath, line_num, content = row
                if filepath != current_file:
                    print(f"\n📂 [{repo}] {filepath}")
                    print("-" * 80)
                    current_file = filepath
                print(f"{line_num:4d} | {content}")

    except Exception as e:
        print(f"❌ Query failed: {e}")
        print("Tip: Avoid using special characters. Just use keywords like: QWebEngineView realtime")

    finally:
        conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Advanced Contextual RAG Interrogator for HUD GUI")
    parser.add_argument("query", nargs='+', help="Natural language query or keywords")
    parser.add_argument("--limit", type=int, default=3, help="Number of primary matches to find context for")
    args = parser.parse_args()

    search_context(" ".join(args.query), args.limit)
