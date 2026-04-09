import os
import glob
import json
import sqlite3
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer
import time

try:
    from tqdm import tqdm
except ImportError:
    print("⚠️ 'tqdm' module not found. Futtatás anélkül...")
    def tqdm(iterable, **kwargs): return iterable

os.environ["OMP_NUM_THREADS"] = "2"
os.environ["MKL_NUM_THREADS"] = "2"

DB_FILE = "ai_restoration_knowledge.db"
INDEX_FILE = "ai_restoration_compressed.index"
REPORT_FILE = "rag_build_report.txt"
BATCH_SIZE = 100

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def init_database(db_path):
    """Létrehozza a strukturált SQLite adatbázist."""
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # A tábla felkészítve a strukturált metaadatok fogadására
    cursor.execute('''
        CREATE TABLE rag_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_repo TEXT,
            filepath TEXT,
            language TEXT,
            file_type TEXT,
            content TEXT
        )
    ''')

    # Indexek a gyorsabb kereséshez
    cursor.execute('CREATE INDEX idx_source_repo ON rag_data (source_repo)')
    cursor.execute('CREATE INDEX idx_language ON rag_data (language)')
    conn.commit()
    return conn, cursor

def process_jsonl_files(work_dir):
    jsonl_files = glob.glob(os.path.join(work_dir, "*.jsonl"))

    if not jsonl_files:
        print("❌ HIBA: Egyetlen .jsonl fájl sem található a mappában!")
        return []

    print(f"📄 {len(jsonl_files)} db JSONL fájlt találtam:")
    for f in jsonl_files:
        print(f"  - {os.path.basename(f)} ({os.path.getsize(f) / (1024*1024):.2f} MB)")

    return jsonl_files

def main():
    print("=== 🧠 AI PICTURE & VIDEO RESTORATION - FAISS/SQLITE RAG BUILDER ===")

    work_dir = get_script_dir()
    jsonl_files = process_jsonl_files(work_dir)
    if not jsonl_files:
        return

    db_path = os.path.join(work_dir, DB_FILE)
    index_path = os.path.join(work_dir, INDEX_FILE)
    report_path = os.path.join(work_dir, REPORT_FILE)

    print("\n⏳ Adatbázis inicializálása...")
    conn, cursor = init_database(db_path)

    print("🧠 MiniLM Vektor modell betöltése (all-MiniLM-L6-v2)...")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    dim = model.get_sentence_embedding_dimension()
    index = faiss.IndexIDMap(faiss.IndexFlatL2(dim))

    total_inserted = 0

    # Jelentés írása
    with open(report_path, "w", encoding="utf-8") as rf:
        rf.write("=== RAG ÉPÍTÉSI JELENTÉS ===\n\n")

        for filepath in jsonl_files:
            file_name = os.path.basename(filepath)
            print(f"\n📂 Fájl feldolgozása: {file_name}")
            rf.write(f"Fájl: {file_name}\n")

            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except UnicodeDecodeError:
                 with open(filepath, 'r', encoding='latin-1') as f:
                    lines = f.readlines()

            file_inserted = 0

            # Batch feldolgozás
            for i in tqdm(range(0, len(lines), BATCH_SIZE), desc=f"Darálás [{file_name}]"):
                batch_lines = lines[i:i+BATCH_SIZE]

                batch_texts = []
                batch_metadata = []

                for line in batch_lines:
                    line = line.strip()
                    if not line: continue

                    try:
                        data = json.loads(line)

                        # Próbáljuk meg az új strukturált formátumot olvasni
                        if "metadata" in data and "content" in data:
                            meta = data["metadata"]
                            text = data["content"]

                            source_repo = meta.get("source_repo", "Unknown")
                            f_path = meta.get("filepath", "Unknown")
                            lang = meta.get("language", "Unknown")
                            f_type = meta.get("file_type", "Unknown")

                        else:
                            # Visszafelé kompatibilitás a régi formátummal
                            text = data.get("code", "") or data.get("content", "")
                            source_repo = data.get("source", "Unknown")
                            f_path = data.get("filename", "Unknown")
                            lang = "Unknown"
                            f_type = "Unknown"

                        if text:
                            batch_texts.append(text)
                            batch_metadata.append((source_repo, f_path, lang, f_type, text))

                    except json.JSONDecodeError:
                        continue # Hibás sor kihagyása

                if not batch_texts: continue

                db_ids = []
                # SQL beszúrás
                for meta_row in batch_metadata:
                    cursor.execute('''
                        INSERT INTO rag_data (source_repo, filepath, language, file_type, content)
                        VALUES (?, ?, ?, ?, ?)
                    ''', meta_row)
                    db_ids.append(cursor.lastrowid)
                conn.commit()

                # FAISS vektorizálás
                embeddings = model.encode(batch_texts)
                index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))
                file_inserted += len(batch_texts)

            total_inserted += file_inserted
            rf.write(f"  -> Sikeresen indexelve: {file_inserted} rekord.\n\n")

    print("\n💾 Index mentése lemezre...")
    faiss.write_index(index, index_path)
    conn.close()

    print("-" * 60)
    print(f"✅ KÜLDETÉS TELJESÍTVE! Összesen {total_inserted} rekord került a RAG adatbázisba.")
    print(f"📦 Létrejött fájlok: {DB_FILE}, {INDEX_FILE}")

if __name__ == "__main__":
    main()
