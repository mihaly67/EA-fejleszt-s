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
    print("⚠️ 'tqdm' module hiányzik! (Telepítés: pip install tqdm)")
    class tqdm:
        def __init__(self, *args, **kwargs): pass
        def update(self, *args, **kwargs): pass
        def close(self, *args, **kwargs): pass
        def set_postfix_str(self, *args, **kwargs): pass

try:
    from colorama import Fore, Style, init
    init(autoreset=True)
except ImportError:
    print("⚠️ 'colorama' module hiányzik! (Telepítés: pip install colorama)")
    class Fore: GREEN=""; RED=""; YELLOW=""; CYAN=""; RESET=""
    class Style: BRIGHT=""; RESET_ALL=""

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
    jsonl_files = sorted(glob.glob(os.path.join(work_dir, "*.jsonl")))

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

    print(f"\n{Fore.CYAN}⏳ RAG ADATBÁZIS INICIALIZÁLÁSA...{Style.RESET_ALL}")

    # --- 1. A GLOBÁLIS MÉRET GYORS MEGHATÁROZÁSA ---
    total_lines_all_files = 0
    print("📏 JSONL fájlok méretének becslése a globális folyamatjelzőhöz...")

    for filepath in jsonl_files:
        try:
            # Gyors sor-számlálás a fájlban (generator)
            with open(filepath, 'rb') as f:
                # Az 1.8 GB beolvasása gyors iterációval (bufferrelve, nem eszi meg a RAM-ot)
                total_lines_all_files += sum(1 for _ in f)
        except Exception as e:
            print(f"{Fore.RED}⚠️ Hiba a {filepath} sorainak számolásakor: {e}{Style.RESET_ALL}")

    print(f"✅ Összesen becsült feldolgozandó sor: {Fore.GREEN}{total_lines_all_files:,}{Style.RESET_ALL} db")

    # --- 2. SZÜNET/FOLYTATÁS FUNKCIÓ ELLENŐRZÉSE ---
    resume_file = None
    resume_line = 0
    total_inserted = 0
    global_lines_processed = 0 # Hol tartunk a nagy összegzésben

    if os.path.exists(progress_path) and os.path.exists(db_path) and os.path.exists(index_path):
        print(f"\n{Fore.YELLOW}🔄 Félbeszakadt folyamat észlelése! Folytatás (Resume)...{Style.RESET_ALL}")
        try:
            with open(progress_path, 'r', encoding='utf-8') as pf:
                prog = json.load(pf)
                resume_file = prog.get("current_file")
                resume_line = prog.get("current_line", 0)
                total_inserted = prog.get("total_inserted", 0)
                global_lines_processed = prog.get("global_lines_processed", 0)
            print(f"  -> Ugrás az utolsó mentési pontra: Fájl={resume_file}, Sor={resume_line}")
        except Exception as e:
            print(f"  {Fore.RED}⚠️ Hiba a progress fájl olvasásakor ({e}). Tiszta lappal indulunk.{Style.RESET_ALL}")
            resume_file = None
            global_lines_processed = 0

    conn, cursor = init_database(db_path, resume=(resume_file is not None))

    print(f"🧠 {Fore.CYAN}MiniLM Vektor modell betöltése (all-MiniLM-L6-v2)...{Style.RESET_ALL}")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    dim = model.get_sentence_embedding_dimension()

    if resume_file is not None and os.path.exists(index_path):
        print(f"📂 FAISS Index betöltése: {INDEX_FILE}...")
        index = faiss.read_index(index_path)
    else:
        index = faiss.IndexIDMap(faiss.IndexFlatL2(dim))

    # --- 3. GLOBÁLIS TQDM FOLYAMATJELZŐ INICIALIZÁLÁSA ---
    # Ez a fő folyamatjelző, ami napokig/órákig mutatni fogja a teljes haladást és a várható hátralévő időt (ETA)
    global_pbar = tqdm(
        total=total_lines_all_files,
        initial=global_lines_processed,
        desc=f"RAG ADATBÁZIS ÉPÍTÉSE (10.7 GB -> CHUNKS)",
        unit="sor",
        colour="green",
        dynamic_ncols=True,
        smoothing=0.1 # Simított sebességszámítás
    )

    # Jelentés írása (Append módban, ha folytatunk)
    open_mode = "a" if resume_file else "w"
    with open(report_path, open_mode, encoding="utf-8") as rf:
        if not resume_file:
            rf.write("=== RAG ÉPÍTÉSI JELENTÉS ===\n\n")

        for filepath in jsonl_files:
            file_name = os.path.basename(filepath)

            # Ha folytatunk, és ez nem a mi fájlunk, átugorjuk a generátorban
            if resume_file and file_name != resume_file:
                if file_name < resume_file:
                    continue

            rf.write(f"Fájl: {file_name}\n")

            file_inserted = 0
            current_line_idx = 0
            batch_count = 0

            def read_lines_safe(path):
                f_utf8 = None
                try:
                    f_utf8 = open(path, 'r', encoding='utf-8')
                    for line in f_utf8:
                        yield line
                except UnicodeDecodeError:
                    if f_utf8: f_utf8.close()
                    # Ha már olvastunk, akkor sajnos elölről kell kezdenünk, de ez a JSONL-nél ritka
                    with open(path, 'r', encoding='latin-1') as f:
                        for line in f: yield line
                finally:
                    if f_utf8 and not f_utf8.closed:
                        f_utf8.close()

            batch_lines = []

            for line in read_lines_safe(filepath):
                current_line_idx += 1

                # Ha folytatjuk a fájlt, átugorjuk a már feldolgozott sorokat a Ciklusban (villámgyorsan)
                if resume_file == file_name and current_line_idx <= resume_line:
                    continue

                # Ha átugrottuk a resume-t, most már számoljuk a friss sorokat a globális csúszkán
                global_pbar.update(1)
                global_lines_processed += 1

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

                    # Automatikus Mentés Biztonsági Okokból (Checkpoint)
                    if batch_count % SAVE_INTERVAL == 0:
                        faiss.write_index(index, index_path)
                        with open(progress_path, 'w', encoding='utf-8') as pf:
                            progress_data = {
                                "current_file": file_name,
                                "current_line": current_line_idx,
                                "total_inserted": total_inserted,
                                "global_lines_processed": global_lines_processed
                            }
                            json.dump(progress_data, pf)

                        # Vizuális visszajelzés a folyamatjelzőn
                        global_pbar.set_postfix_str(f"{Fore.YELLOW}[AUTO-SAVE: OK]{Style.RESET_ALL}")
                    else:
                        # Ha nem most mentettünk, töröljük az üzenetet a következő batch-nél,
                        # hogy csak "villanjon" a felirat
                        if batch_count % SAVE_INTERVAL == 1:
                            global_pbar.set_postfix_str("")

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

            rf.write(f"  -> Sikeresen indexelve: {file_inserted} CHUNK ebben a fájlban.\n\n")

            # Fájl végi mentés a következő fájl előtt (Checkpoint)
            faiss.write_index(index, index_path)
            with open(progress_path, 'w', encoding='utf-8') as pf:
                json.dump({
                    "current_file": file_name,
                    "current_line": current_line_idx,
                    "total_inserted": total_inserted,
                    "global_lines_processed": global_lines_processed
                }, pf)

            # Tiszta lappal indul a következő fájlra (ha van több)
            resume_file = None

    # Bezárjuk a globális folyamatjelzőt, ha kész minden
    global_pbar.close()

    print(f"\n{Fore.GREEN}💾 Végleges Index mentése lemezre...{Style.RESET_ALL}")
    faiss.write_index(index, index_path)
    conn.close()

    # Ha teljesen kész, letörölhetjük a progress fájlt (hiszen már nem kell resume)
    if os.path.exists(progress_path):
        os.remove(progress_path)

    print(f"{Fore.CYAN}" + "-" * 60 + f"{Style.RESET_ALL}")
    print(f"✅ KÜLDETÉS TELJESÍTVE! Összesen {Fore.GREEN}{total_inserted:,}{Style.RESET_ALL} CHUNK került a RAG adatbázisba.")
    print(f"📦 Létrejött fájlok: {Fore.YELLOW}{DB_FILE}{Style.RESET_ALL}, {Fore.YELLOW}{INDEX_FILE}{Style.RESET_ALL}")

if __name__ == "__main__":
    main()
