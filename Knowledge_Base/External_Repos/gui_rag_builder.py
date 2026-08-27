import os
import sqlite3
import argparse

DB_PATH = os.path.join(os.path.dirname(__file__), 'gui_rag.db')
EXTENSIONS = ('.py', '.md', '.txt', '.cpp', '.h', '.js')

def build_db(root_dir):
    print(f"Building RAG Database from: {root_dir}")
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Create FTS5 virtual table
    c.execute("DROP TABLE IF EXISTS codesearch")
    c.execute('''CREATE VIRTUAL TABLE codesearch USING fts5(
                 repo_name, filepath, line_num UNINDEXED, content)''')

    count = 0
    for subdir, _, files in os.walk(root_dir):
        if '.git' in subdir: continue
        for file in files:
            if not file.endswith(EXTENSIONS): continue
            filepath = os.path.join(subdir, file)

            repo_name = filepath.split("External_Repos/")[-1].split("/")[0]
            rel_path = filepath.split("External_Repos/")[-1]

            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

                for i, line in enumerate(lines):
                    line = line.strip()
                    if not line: continue
                    # Store line by line for precise search
                    c.execute("INSERT INTO codesearch (repo_name, filepath, line_num, content) VALUES (?, ?, ?, ?)",
                              (repo_name, rel_path, i+1, line))
                    count += 1
            except Exception:
                pass

    conn.commit()
    conn.close()

    # --- AUTO-GENERATE INDEXED REPOS REPORT ---
    try:
        repos = set()
        cursor.execute("SELECT DISTINCT filepath FROM rag_data")
        for row in cursor.fetchall():
            filepath = row[0]
            if filepath:
                # Extract the top-level directory name as the repo name
                parts = filepath.split("/")
                if len(parts) > 0:
                    repos.add(parts[0])

        report_path = os.path.join(TARGET_DIR, "INDEXED_REPOS.md")
        with open(report_path, "w", encoding="utf-8") as f:
            f.write("# SWAT GUI RAG - Vektorizált Repozitóriumok\n\n")
            f.write("A legutóbbi RAG építés során az alábbi repók és mappák kerültek az adatbázisba:\n\n")
            for repo in sorted(list(repos)):
                if repo not in ['.', '..', '']:
                    f.write(f"- `{repo}`\n")

            cursor.execute("SELECT count(*) FROM rag_data")
            total_chunks = cursor.fetchone()[0]
            f.write(f"\n**Összes Vektorizált Blokk:** {total_chunks}\n")

        print(f"📄 INDEXED_REPOS.md sikeresen generálva: {report_path}")
    except Exception as e:
        print(f"⚠️ Hiba a repó lista generálásakor: {e}")

    print(f"✅ RAG Database built successfully with {count} indexable lines at {DB_PATH}")

def search_db(query):
    if not os.path.exists(DB_PATH):
        print("Database not found. Please run with --build first.")
        return

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Format query for FTS5 (AND logic)
    fts_query = " AND ".join(query)

    print(f"🔍 Searching for: {fts_query}\n" + "-"*50)

    try:
        c.execute('''SELECT repo_name, filepath, line_num, snippet(codesearch, 3, '[', ']', '...', 64)
                     FROM codesearch
                     WHERE content MATCH ?
                     ORDER BY rank LIMIT 30''', (fts_query,))

        results = c.fetchall()
        if not results:
            print("No matches found.")
        else:
            for row in results:
                print(f"[{row[0]}] {row[1]} (Line {row[2]}): {row[3]}")
    except Exception as e:
        print(f"Search error: {e}")

    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SQLite FTS5 RAG for GUI Repos")
    parser.add_argument("--build", action="store_true", help="Build the database")
    parser.add_argument("--query", nargs='+', help="Search words")

    args = parser.parse_args()

    if args.build:
        build_db(os.path.abspath(os.path.dirname(__file__)))

    if args.query:
        search_db(args.query)
