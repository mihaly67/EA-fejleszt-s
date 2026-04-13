import os
import glob
import json
import sqlite3
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer
import time
import shutil
import concurrent.futures
import multiprocessing as mp

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

# CPU MAXIMALIZÁLÁS (Nincs limit a matematikai szálaknál)
# os.environ["OMP_NUM_THREADS"] = "2" - ELTÁVOLÍTVA
# os.environ["MKL_NUM_THREADS"] = "2" - ELTÁVOLÍTVA

DB_FILE = "swat4_unified_knowledge.db"
INDEX_FILE = "swat4_unified_compressed.index"
REPORT_FILE = "rag_build_report.txt"
PROGRESS_FILE = "rag_build_progress.json" # Utolsó feldolgozott sor mentésére
BATCH_SIZE = 200 # Egyszerre beolvasott JSONL sorok (gyorsabb memória/adatbázis rotáció)
ENCODE_BATCH_SIZE = 64 # Pytorch / SIMD optimalizált batch méret a SentenceTransformer-hez
SAVE_INTERVAL = 250 # 250 batch (250*200 = 50,000) utánmentsük ki a FAISS-t és a haladást a lemezre

# WORKER FOLYAMATOKHOZ GLOBÁLIS VÁLTOZÓK
# A ProcessPoolExecutor új processzeket indít, és a Python néha "újrahasznosítja" a workereket (bezárja és újat nyit),
# ami a 100 MB-os PyTorch modell állandó és felesleges újratöltéséhez vezet.
# Hogy ezt elkerüljük, egy robusztus, "Singleton" mintájú globális változóval védjük a modellt:
WORKER_MODEL = None

def _init_worker():
    """Minden egyes processzor magnak (Workernek) betölti a saját független AI modelljét a memóriába (EGYSZER!)."""
    global WORKER_MODEL
    if WORKER_MODEL is None:
        # A HuggingFace figyelmeztetés elkerülése végett (Tokenizers parallelism)
        os.environ["TOKENIZERS_PARALLELISM"] = "false"
        # Letiltjuk a logger üzeneteket ("Loading weights... BertModel LOAD REPORT"), ami telerondította a folyamatjelzőt
        import logging
        logging.getLogger("sentence_transformers").setLevel(logging.ERROR)

        WORKER_MODEL = SentenceTransformer('all-MiniLM-L6-v2')

def _worker_encode_batch(batch_data):
    """
    Ez a függvény a Worker Process-ben fut!
    Megkapja a nyers szövegeket és a metaadatokat, legenerálja a vektorokat az adott magon (100% CPU).
    Mivel a WORKER_MODEL globális, nem kell minden batch-nél betölteni!
    """
    batch_metadata = batch_data["metadata"]
    last_line_idx = batch_data["last_line_idx"]

    global WORKER_MODEL
    texts = [item[6] for item in batch_metadata] # A 6. index a chunk szövege
    embeddings = WORKER_MODEL.encode(texts, batch_size=ENCODE_BATCH_SIZE, show_progress_bar=False)
    return embeddings, batch_metadata, last_line_idx

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
    """Létrehozza vagy megnyitja a strukturált SQLite adatbázist Turbo sebességre hangolva."""
    if not resume and os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)

    # ⚡ SQLITE TURBO TUNING (10-100x gyorsabb Insert sebesség) ⚡
    # Kikapcsoljuk az OS szintű szinkronizálást és átállunk Write-Ahead-Log memóriába
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = OFF;")
    conn.execute("PRAGMA cache_size = 10000;")

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

def atomic_save(index, index_path, progress_data, progress_path, db_path):
    """Biztonságosan menti a FAISS indexet, a JSON progress-t és csinál egy DB Backupot a lemezre ideiglenes (TMP) fájlokkal."""
    tmp_index = index_path + ".tmp"
    tmp_prog = progress_path + ".tmp"
    db_backup = db_path + ".bak"

    # 1. Mentés az ideiglenes fájlokba
    faiss.write_index(index, tmp_index)
    with open(tmp_prog, 'w', encoding='utf-8') as pf:
        json.dump(progress_data, pf)

    # 2. Biztonsági másolat az SQLite-ról (PRAGMA synchronous=OFF miatt kötelező)
    if os.path.exists(db_path):
        shutil.copy2(db_path, db_backup)

    # 3. Villámgyors (atomikus) átnevezés a végleges fájlokra
    shutil.move(tmp_index, index_path)
    shutil.move(tmp_prog, progress_path)

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

    print(f"🧠 {Fore.CYAN}A RAG FAISS paramétereinek betöltése (all-MiniLM-L6-v2)...{Style.RESET_ALL}")
    # Itt a főfolyamatban nem töltjük be a modellt, csak a FAISS-hez szükséges dimenziót adjuk meg
    dim = 384 # A MiniLM-L6-v2 fix dimenziója (felesleges betölteni a modellt a Main szálon)

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

            # ⚡ A MULTIPROCESSING POOL INDÍTÁSA ⚡
            # Indítunk maximum 2 (vagy ha van több mag, CPU_COUNT-1) dedikált workert, amik párhuzamosan ontják a vektorokat.
            # A max_workers=2 biztonságos a 8 GB RAM miatt (2.5 GB tesztelt foglalás 2 workernél).
            max_cores = max(1, mp.cpu_count() - 1)

            # Hogy ne omoljon össze és ne generáljon újra workereket a memóriában, megnöveljük az élettartamot
            with concurrent.futures.ProcessPoolExecutor(max_workers=max_cores, initializer=_init_worker) as executor:

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
                futures = set() # Ide gyűjtjük az aszinkron feladatokat

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

                    # Ha összegyűlt 1 Batch, beküldjük az Executorba aszinkron módon
                    if len(batch_lines) >= BATCH_SIZE:
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
                                    # Main Thread darabol és előkészít
                                    chunks = chunk_text(text, chunk_size=1000, overlap=200)
                                    for c_idx, chunk in enumerate(chunks):
                                        batch_metadata.append((category, source_repo, f_path, c_idx, lang, f_type, chunk))
                            except json.JSONDecodeError:
                                continue # Hibás sor kihagyása

                        if batch_metadata:
                            # ⚡ Párhuzamos CPU Vektorizálás Aszinkron Beküldése ⚡
                            batch_payload = {
                                "metadata": batch_metadata,
                                "last_line_idx": current_line_idx # Eltároljuk, hol tartott a fájl olvasása ezen batch végén
                            }
                            future = executor.submit(_worker_encode_batch, batch_payload)
                            futures.add(future)

                        batch_lines = [] # Batch ürítése

                        # --- FELDOLGOZÁS & VÁRAKOZÁS ---
                        # Ha a várólista túl nagy (pl. több mint 4-5 batch van kint a queue-ban),
                        # akkor a Main szál megvárja és beírja az eredményeket az SQLite/FAISS-be.
                        if len(futures) >= max_cores * 2:
                            # Végigmegyünk a KÉSZ aszinkron feladatokon
                            done_futures, futures = concurrent.futures.wait(futures, return_when=concurrent.futures.FIRST_COMPLETED)

                            for f in done_futures:
                                try:
                                    embeddings, r_metadata, processed_line_idx = f.result()

                                    # SQLite írás (Nagyon gyors, 1 szálon a Main-ben)
                                    db_ids = []
                                    for meta_row in r_metadata:
                                        cursor.execute('''
                                            INSERT INTO rag_data (category, source_repo, filepath, chunk_index, language, file_type, content)
                                            VALUES (?, ?, ?, ?, ?, ?, ?)
                                        ''', meta_row)
                                        db_ids.append(cursor.lastrowid)
                                    conn.commit()

                                    # FAISS vektorok hozzáadása
                                    index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))

                                    file_inserted += len(r_metadata)
                                    total_inserted += len(r_metadata)
                                    batch_count += 1

                                    # ⚡ ATOMIC CHECKPOINT ⚡
                                    if batch_count % SAVE_INTERVAL == 0:
                                        prog_data = {
                                            "current_file": file_name,
                                            "current_line": processed_line_idx, # A TÉNYLEGESEN feldolgozott utolsó sor a Workerből!
                                            "total_inserted": total_inserted,
                                            "global_lines_processed": global_lines_processed
                                        }
                                        atomic_save(index, index_path, prog_data, progress_path, db_path)
                                        global_pbar.set_postfix_str(f"{Fore.YELLOW}[TURBO CHECKPOINT MENTVE]{Style.RESET_ALL}")
                                    elif batch_count % SAVE_INTERVAL == 1:
                                        global_pbar.set_postfix_str("")
                                except Exception as e:
                                    print(f"Hiba egy Worker Process-ben: {e}")

                # CIKLUS VÉGE: Maradék batchek és futures feldolgozása
                if batch_lines:
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
                                    batch_metadata.append((category, source_repo, f_path, c_idx, lang, f_type, chunk))
                        except json.JSONDecodeError:
                            pass

                    if batch_metadata:
                        batch_payload = {
                            "metadata": batch_metadata,
                            "last_line_idx": current_line_idx
                        }
                        futures.add(executor.submit(_worker_encode_batch, batch_payload))

                # Várakozás az ÖSSZES megmaradt aszinkron feladatra a fájl végén
                for f in concurrent.futures.as_completed(futures):
                    try:
                        embeddings, r_metadata, _ = f.result()
                        db_ids = []
                        for meta_row in r_metadata:
                            cursor.execute('''
                                INSERT INTO rag_data (category, source_repo, filepath, chunk_index, language, file_type, content)
                                VALUES (?, ?, ?, ?, ?, ?, ?)
                            ''', meta_row)
                            db_ids.append(cursor.lastrowid)
                        conn.commit()
                        index.add_with_ids(np.array(embeddings).astype('float32'), np.array(db_ids).astype('int64'))
                        file_inserted += len(r_metadata)
                        total_inserted += len(r_metadata)
                    except Exception as e:
                        print(f"Hiba a záró Worker Process-ben: {e}")

            rf.write(f"  -> Sikeresen indexelve: {file_inserted} CHUNK ebben a fájlban.\n\n")

            # ⚡ Fájl végi ATOMIC mentés a következő fájl előtt (Checkpoint) ⚡
            prog_data = {
                "current_file": file_name,
                "current_line": current_line_idx,
                "total_inserted": total_inserted,
                "global_lines_processed": global_lines_processed
            }
            atomic_save(index, index_path, prog_data, progress_path, db_path)

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
