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
    class tqdm:
        def __init__(self, *args, **kwargs): pass
        def update(self, *args, **kwargs): pass
        def close(self, *args, **kwargs): pass

os.environ["OMP_NUM_THREADS"] = "2"
os.environ["MKL_NUM_THREADS"] = "2"

DB_FILE = "swat4_unified_knowledge.db"
INDEX_FILE = "swat4_unified_compressed.index"
REPORT_FILE = "rag_build_report.txt"
PROGRESS_FILE = "rag_build_progress.json" # Utolsó feldolgozott sor mentésére
BATCH_SIZE = 100 # Fájlok (illetve chunk batch-ek) feldolgozási mérete
SAVE_INTERVAL = 500 # Hány batch után mentsük ki a FAISS-t és a haladást a lemezre (ha megszakadna)

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def chunk_text(text, chunk_size=1000, overlap=200):
    """Feldarabolja a hosszú szövegeket fix méretű blokkokra átfedéssel a FAISS token limit miatt."""
    if not text:
        return []

    chunks = []
    start = 0
    text_length = len(text)

    while start < text_length:
        end = start + chunk_size
        chunk = text[start:end]
        chunks.append(chunk)
        start += (chunk_size - overlap)

    return chunks

def init_database(db_path, resume=False):
    """Létrehozza vagy megnyitja a strukturált SQLite adatbázist."""
    if not resume and os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    if not resume:
        # A tábla felkészítve a strukturált metaadatok fogadására
        cursor.execute('''
            CREATE TABLE rag_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT,
                source_repo TEXT,
                filepath TEXT,
                chunk_index INTEGER,
                language TEXT,
                file_type TEXT,
                content TEXT
            )
        ''')

        # Indexek a gyorsabb kereséshez
        cursor.execute('CREATE INDEX idx_category ON rag_data (category)')
        cursor.execute('CREATE INDEX idx_source_repo ON rag_data (source_repo)')
        cursor.execute('CREATE INDEX idx_filepath ON rag_data (filepath)')
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
    print("=== 🧠 SWAT4 (ML-OPS, BLACK_OPS) - FAISS/SQLITE RAG BUILDER ===")

    work_dir = get_script_dir()
    jsonl_files = process_jsonl_files(work_dir)
    if not jsonl_files:
        return

    # A kimeneti mappát automatikusan létrehozzuk a RAG adatbázisoknak, ahogy a dokumentáció is írja
    output_dir = os.path.join(work_dir, "Knowledge_Base", "RAG_DB")
    os.makedirs(output_dir, exist_ok=True)

    db_path = os.path.join(output_dir, DB_FILE)
    index_path = os.path.join(output_dir, INDEX_FILE)
    report_path = os.path.join(output_dir, REPORT_FILE)
    progress_path = os.path.join(output_dir, PROGRESS_FILE)

    # Szünet / Folytatás funkció ellenőrzése
    resume_file = None
    resume_line = 0
    total_inserted = 0

    if os.path.exists(progress_path) and os.path.exists(db_path) and os.path.exists(index_path):
        print("\n🔄 Félbeszakadt folyamat észlelése! Megpróbálom folytatni a darálást...")
        try:
            with open(progress_path, 'r', encoding='utf-8') as pf:
                prog = json.load(pf)
                resume_file = prog.get("current_file")
                resume_line = prog.get("current_line", 0)
                total_inserted = prog.get("total_inserted", 0)
            print(f"  -> Utolsó fájl: {resume_file}, Sor: {resume_line}")
        except Exception as e:
            print(f"  ⚠️ Hiba a progress fájl olvasásakor ({e}). Tiszta lappal indulunk.")
            resume_file = None

    print("\n⏳ Adatbázis inicializálása...")
    conn, cursor = init_database(db_path, resume=(resume_file is not None))

    print("🧠 MiniLM Vektor modell betöltése (all-MiniLM-L6-v2)...")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    dim = model.get_sentence_embedding_dimension()

    if resume_file is not None and os.path.exists(index_path):
        print(f"📂 FAISS Index betöltése: {INDEX_FILE}...")
        index = faiss.read_index(index_path)
    else:
        index = faiss.IndexIDMap(faiss.IndexFlatL2(dim))

    # Jelentés írása (Append módban, ha folytatunk)
    open_mode = "a" if resume_file else "w"
    with open(report_path, open_mode, encoding="utf-8") as rf:
        if not resume_file:
            rf.write("=== RAG ÉPÍTÉSI JELENTÉS ===\n\n")

        for filepath in jsonl_files:
            file_name = os.path.basename(filepath)

            # Ha folytatunk, és ez nem a mi fájlunk, átugorjuk. (Feltételezzük, hogy sorrendben haladunk)
            if resume_file and file_name != resume_file:
                # Egyszerű logika: Csak akkor ugorjuk át, ha biztosan megvolt már. De itt inkább
                # arra számítunk, hogy csak 1 nagy JSONL van (a swat4_unified_data.jsonl).
                if file_name < resume_file:
                    continue

            print(f"\n📂 Fájl feldolgozása: {file_name}")
            rf.write(f"Fájl: {file_name}\n")

            file_inserted = 0
            current_line_idx = 0
            batch_count = 0

            # Memóriabarát fájlolvasás soronként (nem olvassuk be mind a 1.8 GB-ot a RAM-ba egyszerre)
            # UTF-8 és Latin-1 fallback-al. Mivel a jsonl ascii/utf8 alapú, beépített try-except generátor kell.
            def read_lines_safe(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        for line in f: yield line
                except UnicodeDecodeError:
                    with open(path, 'r', encoding='latin-1') as f:
                        for line in f: yield line

            batch_lines = []

            # Progress bar inicializálása (Mivel nem tudjuk a hosszt előre a generátornál, csak fut egy counter)
            pbar = tqdm(desc=f"Darálás [{file_name}]", unit="sor")

            for line in read_lines_safe(filepath):
                current_line_idx += 1
                pbar.update(1)

                # Ha folytatjuk a fájlt, átugorjuk a már feldolgozott sorokat (villámgyorsan)
                if resume_file == file_name and current_line_idx <= resume_line:
                    continue

                line = line.strip()
                if not line: continue
                batch_lines.append(line)

                if len(batch_lines) >= BATCH_SIZE:
                    batch_texts = []
                    batch_metadata = []

                    for bline in batch_lines:
                        try:
                            data = json.loads(bline)

                            if "metadata" in data and "content" in data:
                                meta = data["metadata"]
                                text = data["content"]

                                category = meta.get("category", "Uncategorized")
                                source_repo = meta.get("source_repo", "Unknown")
                                f_path = meta.get("filepath", "Unknown")
                                lang = meta.get("language", "Unknown")
                                f_type = meta.get("file_type", "Unknown")

                            else:
                                # Visszafelé kompatibilitás a régi formátummal
                                text = data.get("code", "") or data.get("content", "")
                                category = "Uncategorized"
                                source_repo = data.get("source", "Unknown")
                                f_path = data.get("filename", "Unknown")
                                lang = "Unknown"
                                f_type = "Unknown"

                            if text:
                                # 10.7 GB adat feldolgozása darabolással (Context Window megoldás)
                                chunks = chunk_text(text, chunk_size=1000, overlap=200)
                                for c_idx, chunk in enumerate(chunks):
                                    batch_texts.append(chunk)
                                    batch_metadata.append((category, source_repo, f_path, c_idx, lang, f_type, chunk))

                        except json.JSONDecodeError:
                            continue # Hibás sor kihagyása

                    if batch_texts:
                        db_ids = []
                        # SQL beszúrás a darabolt szövegekre
                        for meta_row in batch_metadata:
                            cursor.execute('''
                                INSERT INTO rag_data (category, source_repo, filepath, chunk_index, language, file_type, content)
                                VALUES (?, ?, ?, ?, ?, ?, ?)
                            ''', meta_row)
                            db_ids.append(cursor.lastrowid)
                        conn.commit()

                        # FAISS vektorizálás a chunk-okra (MiniLM max 256 token/vektor)
                        embeddings = model.encode(batch_texts)
                        index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))
                        file_inserted += len(batch_texts)
                        total_inserted += len(batch_texts)

                    batch_lines = [] # Batch ürítése
                    batch_count += 1

                    # Automatikus Mentés Biztonsági Okokból
                    if batch_count % SAVE_INTERVAL == 0:
                        faiss.write_index(index, index_path)
                        with open(progress_path, 'w', encoding='utf-8') as pf:
                            progress_data = {"current_file": file_name, "current_line": current_line_idx, "total_inserted": total_inserted}
                            json.dump(progress_data, pf)

            # Végleges batch feldolgozása a fájl végén, ha maradt még benne valami
            if batch_lines:
                batch_texts = []
                batch_metadata = []
                for bline in batch_lines:
                    try:
                        data = json.loads(bline)
                        if "metadata" in data and "content" in data:
                            meta = data["metadata"]
                            text = data["content"]
                            category = meta.get("category", "Uncategorized")
                            source_repo = meta.get("source_repo", "Unknown")
                            f_path = meta.get("filepath", "Unknown")
                            lang = meta.get("language", "Unknown")
                            f_type = meta.get("file_type", "Unknown")
                        else:
                            text = data.get("code", "") or data.get("content", "")
                            category = "Uncategorized"
                            source_repo = data.get("source", "Unknown")
                            f_path = data.get("filename", "Unknown")
                            lang = "Unknown"
                            f_type = "Unknown"
                        if text:
                            chunks = chunk_text(text, chunk_size=1000, overlap=200)
                            for c_idx, chunk in enumerate(chunks):
                                batch_texts.append(chunk)
                                batch_metadata.append((category, source_repo, f_path, c_idx, lang, f_type, chunk))
                    except json.JSONDecodeError:
                        pass

                if batch_texts:
                    db_ids = []
                    for meta_row in batch_metadata:
                        cursor.execute('''
                            INSERT INTO rag_data (category, source_repo, filepath, chunk_index, language, file_type, content)
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                        ''', meta_row)
                        db_ids.append(cursor.lastrowid)
                    conn.commit()
                    embeddings = model.encode(batch_texts)
                    index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))
                    file_inserted += len(batch_texts)
                    total_inserted += len(batch_texts)

            pbar.close()
            rf.write(f"  -> Sikeresen indexelve: {file_inserted} CHUNK ebben a fájlban.\n\n")

            # Fájl végi mentés a következő előtt
            faiss.write_index(index, index_path)
            with open(progress_path, 'w', encoding='utf-8') as pf:
                json.dump({"current_file": file_name, "current_line": current_line_idx, "total_inserted": total_inserted}, pf)

            # Tiszta lappal indul a következő fájlra (ha van több)
            resume_file = None

    print("\n💾 Végleges Index mentése lemezre...")
    faiss.write_index(index, index_path)
    conn.close()

    # Ha teljesen kész, letörölhetjük a progress fájlt
    if os.path.exists(progress_path):
        os.remove(progress_path)

    print("-" * 60)
    print(f"✅ KÜLDETÉS TELJESÍTVE! Összesen {total_inserted} rekord került a RAG adatbázisba.")
    print(f"📦 Létrejött fájlok: {DB_FILE}, {INDEX_FILE}")

if __name__ == "__main__":
    main()
