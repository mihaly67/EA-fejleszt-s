import sqlite3

def query(search_term):
    conn = sqlite3.connect("gui_rag.db")
    c = conn.cursor()
    c.execute(f"SELECT filepath, content FROM codesearch WHERE content MATCH '{search_term}' LIMIT 10")
    for row in c.fetchall():
        print(f"\n--- {row[0]} ---\n")
        content = row[1]
        idx = content.find("def update(")
        if idx != -1:
            start = max(0, idx - 50)
            end = min(len(content), idx + 200)
            print(content[start:end])
    conn.close()

query("HorizontalLine")
