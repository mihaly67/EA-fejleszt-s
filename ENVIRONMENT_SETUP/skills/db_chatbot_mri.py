# Autonomous Agent Skill: Database Chatbot (SQLite OOM-Safe Agent-to-Bot Interface)
# Memória-optimalizált adatbázis lekérdező (Fetchall elkerülése!)
# Az Agent ezen a felületen keresztül tud nagy RAG / EA tudásbázisokat queryzni.
import argparse
import sqlite3
import time
import os

def query_database(db_path: str, table: str, condition: str, batch_size: int = 500):
    if not os.path.exists(db_path):
        print(f"❌ Hiba: Az adatbázis nem található: {db_path}")
        return

    print(f"🤖 [Agent-Bot Comms] Adatbázis lekérdezés fogadva.")
    print(f"🗄️ [DB ChatBot] Bázis: {db_path}, Tábla: {table}, Feltétel: {condition}")

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        offset = 0
        total_fetched = 0

        while True:
            # Deterministic ordering is critical for OFFSET
            query = f"SELECT * FROM {table} WHERE {condition} ORDER BY rowid LIMIT ? OFFSET ?"
            cursor.execute(query, (batch_size, offset))

            rows = cursor.fetchall()
            if not rows:
                break

            total_fetched += len(rows)
            offset += batch_size

            print(f"⏳ [DB ChatBot] Batched Fetch (Memória kímélése): {total_fetched} sor...", flush=True)
            time.sleep(0.05)

        print(f"✅ [DB ChatBot Válasz] Lekérdezés befejezve. Összesen vizsgált sor: {total_fetched}")

    except sqlite3.Error as e:
        print(f"❌ [DB ChatBot] SQLite Hiba: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OOM-Safe Database Chatbot for Agent Comms")
    parser.add_argument("--db", required=True, help="Az SQLite adatbázis fájl")
    parser.add_argument("--table", required=True, help="A vizsgálandó tábla")
    parser.add_argument("--condition", default="1=1", help="SQL WHERE feltétel (alap: 1=1)")
    parser.add_argument("--batch", type=int, default=500, help="Batch/Limit méret")
    args = parser.parse_args()

    query_database(args.db, args.table, args.condition, args.batch)
