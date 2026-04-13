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

# A szálak számát 3-ra emeljük a Ryzen 3 processzor jobb kihasználása érdekében (egy mag marad a rendszernek)
os.environ["OMP_NUM_THREADS"] = "3"
os.environ["MKL_NUM_THREADS"] = "3"

DB_FILE = "swat4_unified_knowledge.db"
INDEX_FILE = "swat4_unified_compressed.index"
REPORT_FILE = "rag_build_report.txt"
PROGRESS_FILE = "rag_build_progress.json"

# A RAM terhére gyorsítjuk a CPU mátrixszorzásait. BATCH_SIZE 1024 több RAM-ot használ és a 2 hatványai miatt optimális a PyTorch-nak.
BATCH_SIZE = 1024
# Checkpoint SŰRŰSÍTÉSE: Mivel a feldolgozás lassú, MINDEN batch (1024 sor) után mentsünk! Így azonnal leállítható marad.
CHECKPOINT_INTERVAL_BATCHES = 1

def get_script_dir():
    return os.path.dirname(os.path.abspath(__file__))

def init_database(db_path, resume=False):
    """Létrehozza vagy megnyitja a strukturált SQLite adatbázist."""
    if not resume and os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)

    # SQLite sebesség és RAM optimalizálás
    conn.execute("PRAGMA synchronous = NORMAL")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA cache_size = -500000") # ~500 MB dedikált RAM gyorsítótár

    cursor = conn.cursor()

    if not resume:
        # A tábla felkészítve a strukturált metaadatok fogadására
        cursor.execute('''
            CREATE TABLE rag_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT,
                source_repo TEXT,
                filepath TEXT,
                language TEXT,
                file_type TEXT,
                content TEXT
            )
        ''')

        # Indexek a gyorsabb kereséshez
        cursor.execute('CREATE INDEX idx_category ON rag_data (category)')
        cursor.execute('CREATE INDEX idx_source_repo ON rag_data (source_repo)')
        cursor.execute('CREATE INDEX idx_language ON rag_data (language)')
        conn.commit()
    return conn, cursor

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

def process_jsonl_files(work_dir):
    # Fontos a sorted() a determinisztikus bejárás (Resume) miatt!
    jsonl_files = sorted(glob.glob(os.path.join(work_dir, "*.jsonl")))

    if not jsonl_files:
        print("❌ HIBA: Egyetlen .jsonl fájl sem található a mappában!")
        return []

    print(f"📄 {len(jsonl_files)} db JSONL fájlt találtam:")
    for f in jsonl_files:
        print(f"  - {os.path.basename(f)} ({os.path.getsize(f) / (1024*1024):.2f} MB)")

    return jsonl_files

def load_progress(progress_path):
    if os.path.exists(progress_path):
        try:
            with open(progress_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ Hiba a progress fájl beolvasásakor: {e}. Tiszta lappal indulunk.")
    return None

def save_progress(progress_path, file_name, line_index, total_inserted):
    with open(progress_path, 'w', encoding='utf-8') as f:
        json.dump({
            "current_file": file_name,
            "line_index": line_index,
            "total_inserted": total_inserted
        }, f, indent=4)

def get_file_line_count(filepath):
    """Megszámolja a sorokat egy nagy fájlban gyorsan, streaming módban."""
    def _count_lines(f):
        return sum(1 for _ in f)

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return _count_lines(f)
    except UnicodeDecodeError:
        with open(filepath, 'r', encoding='latin-1') as f:
            return _count_lines(f)

def process_file_streaming(filepath, model, index, cursor, conn, progress_path,
                           start_line_index, start_file_name, total_inserted_global,
                           rf, resume):

    file_name = os.path.basename(filepath)
    print(f"\n📂 Fájl feldolgozása (Streaming): {file_name}")
    rf.write(f"Fájl: {file_name} (Folytatva: {resume})\n")

    total_lines = get_file_line_count(filepath)

    current_line_idx = start_line_index if resume and file_name == start_file_name else 0
    file_inserted = 0
    batch_counter = 0

    def parse_and_process(f):
        nonlocal current_line_idx, total_lines, file_inserted, total_inserted_global, batch_counter

        # Átugorjuk a már feldolgozott sorokat (O(1) memória használat)
        for _ in range(current_line_idx):
            next(f)

        pbar = tqdm(total=total_lines, initial=current_line_idx, desc=f"Darálás [{file_name}]")

        batch_lines = []

        for line in f:
            batch_lines.append(line)

            if len(batch_lines) >= BATCH_SIZE:
                _process_batch(batch_lines, model, index, cursor, conn)

                file_inserted += len(batch_lines)
                total_inserted_global += len(batch_lines)
                current_line_idx += len(batch_lines)
                pbar.update(len(batch_lines))

                batch_lines = []
                batch_counter += 1

                # Checkpoint logika
                if batch_counter >= CHECKPOINT_INTERVAL_BATCHES:
                    conn.commit()
                    faiss.write_index(index, index_path)
                    save_progress(progress_path, file_name, current_line_idx, total_inserted_global)
                    batch_counter = 0

        # Maradék sorok feldolgozása
        if batch_lines:
            _process_batch(batch_lines, model, index, cursor, conn)
            file_inserted += len(batch_lines)
            total_inserted_global += len(batch_lines)
            current_line_idx += len(batch_lines)
            pbar.update(len(batch_lines))

        pbar.close()
        return current_line_idx, total_inserted_global

    def _process_batch(batch_lines, model, index, cursor, conn):
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
                    chunks = chunk_text(text, chunk_size=1000, overlap=200)
                    for chunk in chunks:
                        batch_texts.append(chunk)
                        batch_metadata.append((category, source_repo, f_path, lang, f_type, chunk))

            except json.JSONDecodeError:
                continue # Hibás sor kihagyása

        if batch_texts:
            db_ids = []
            # SQL beszúrás (még memória/WAL szinten)
            for meta_row in batch_metadata:
                cursor.execute('''
                    INSERT INTO rag_data (category, source_repo, filepath, language, file_type, content)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', meta_row)
                db_ids.append(cursor.lastrowid)

            # FAISS vektorizálás a chunk-okra (MiniLM max 256 token/vektor)
            embeddings = model.encode(batch_texts)
            index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))

    # Itt alkalmazzuk a memóriaszabályt: ha a fallback bekövetkezik, az eredeti file mutató bezárul,
    # és teljesen elölről újranyitja a fájlt, így nem csúszik el a stream.
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            current_line_idx, total_inserted_global = parse_and_process(f)
    except UnicodeDecodeError:
        print("⚠️ UnicodeDecodeError az utf-8 olvasásakor. Fallback: latin-1.")
        # Fájl újranyitása tiszta streamen
        with open(filepath, 'r', encoding='latin-1') as f:
            current_line_idx, total_inserted_global = parse_and_process(f)

    # Fájl végi Checkpoint
    conn.commit()
    faiss.write_index(index, index_path)
    save_progress(progress_path, file_name, current_line_idx, total_inserted_global)

    rf.write(f"  -> Fájl feldolgozva. Sikeresen indexelve eddig: {file_inserted} rekord.\n\n")
    return total_inserted_global

def main():
    print("=== 🧠 SWAT4 (ML-OPS, BLACK_OPS) - FAISS/SQLITE RAG BUILDER [RESUME CAPABLE] ===")

    work_dir = get_script_dir()
    jsonl_files = process_jsonl_files(work_dir)
    if not jsonl_files:
        return

    global DB_FILE, INDEX_FILE, REPORT_FILE, PROGRESS_FILE
    db_path = os.path.join(work_dir, DB_FILE)
    global index_path
    index_path = os.path.join(work_dir, INDEX_FILE)
    report_path = os.path.join(work_dir, REPORT_FILE)
    progress_path = os.path.join(work_dir, PROGRESS_FILE)

    progress = load_progress(progress_path)
    resume = False
    start_file_name = None
    start_line_index = 0
    total_inserted_global = 0

    if progress and os.path.exists(db_path) and os.path.exists(index_path):
        resume = True
        start_file_name = progress.get("current_file")
        start_line_index = progress.get("line_index", 0)
        total_inserted_global = progress.get("total_inserted", 0)
        print(f"\n🔄 FOLYTATÁS MÓD: Adatbázis és index betöltése...")
        print(f"   Utolsó mentett pont: {start_file_name} @ {start_line_index} sor. Összes beillesztett: {total_inserted_global}")
    else:
        print("\n⏳ Tiszta lappal indulás. Adatbázis inicializálása...")
        if os.path.exists(progress_path):
            os.remove(progress_path)

    conn, cursor = init_database(db_path, resume)

    print("🧠 MiniLM Vektor modell betöltése (all-MiniLM-L6-v2)...")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    dim = getattr(model, "get_embedding_dimension", lambda: getattr(model, "get_sentence_embedding_dimension")())()

    if resume:
        print("📥 FAISS Index betöltése lemezről...")
        index = faiss.read_index(index_path)
    else:
        index = faiss.IndexIDMap(faiss.IndexFlatL2(dim))

    # Jelentés írása (hozzáfűzés, ha resume)
    report_mode = "a" if resume else "w"
    with open(report_path, report_mode, encoding="utf-8") as rf:
        if not resume:
            rf.write("=== RAG ÉPÍTÉSI JELENTÉS ===\n\n")

        skip_files = resume

        for filepath in jsonl_files:
            file_name = os.path.basename(filepath)

            if skip_files:
                if file_name != start_file_name:
                    print(f"⏭️ Fájl átugrása: {file_name} (Már feldolgozva)")
                    continue
                else:
                    skip_files = False # Megtaláltuk a fájlt, innentől már nem ugrik át

            total_inserted_global = process_file_streaming(
                filepath, model, index, cursor, conn, progress_path,
                start_line_index, start_file_name, total_inserted_global,
                rf, resume
            )

            # Következő fájlra már nem lesz resume, elölről kezdi
            resume = False
            start_line_index = 0

    print("\n💾 Végső szinkronizáció lemezre...")
    conn.commit()
    faiss.write_index(index, index_path)
    conn.close()

    # Töröljük a progress fájlt, ha mindennel készen vagyunk
    if os.path.exists(progress_path):
        os.remove(progress_path)

    print("-" * 60)
    print(f"✅ KÜLDETÉS TELJESÍTVE! Összesen {total_inserted_global} rekord került a RAG adatbázisba.")
    print(f"📦 Létrejött fájlok: {DB_FILE}, {INDEX_FILE}")

if __name__ == "__main__":
    main()
