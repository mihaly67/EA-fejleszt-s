import sqlite3
import argparse
import os
import json
from collections import defaultdict
import re

def create_repo_map(db_path: str, output_file: str):
    """
    Végigmegy a RAG adatbázison és egy memóriakímélő Könyvtári Katalógust (Fraktál-Memória) generál.
    Cél: Csak a repók, könyvtárak és az azokban lévő fájlnevek kinyerése hierarchikusan,
    a nyers kód kontextusba emelése (porszívó effektus) nélkül.
    """
    if not os.path.exists(db_path):
        print(f"❌ Adatbázis nem található: {db_path}")
        return

    print(f"🔍 Scout indítása a(z) {db_path} adatbázison...")

    # 1. Lekérdezzük csak a metaadatokat, KIZÁRVA a hatalmas `content` oszlopot!
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # Próbáljuk a szabványos sémát
        cursor.execute("SELECT source_repo, filepath, file_type FROM rag_data")
        rows = cursor.fetchall()
    except sqlite3.OperationalError:
        try:
             # Régi séma fallback (pl. swat_data)
             cursor.execute("SELECT source, type FROM data")
             raw_rows = cursor.fetchall()
             rows = []
             for r in raw_rows:
                 source = r[0]
                 repo = source.split('/')[0] if '/' in source else "Unknown"
                 rows.append((repo, source, r[1]))
        except sqlite3.OperationalError as e:
             print(f"❌ Ismeretlen adatbázis séma: {e}")
             return
    finally:
        conn.close()

    # 2. Építjük a Hierarchikus Tudásgráfot (Repo -> Mappa -> Fájlok)
    repo_map = defaultdict(lambda: defaultdict(list))

    for repo, filepath, file_type in rows:
        if not filepath: continue

        # Levágjuk a repó nevét az útvonal elejéről, ha ott van
        clean_path = filepath
        if repo and filepath.startswith(repo + "/"):
            clean_path = filepath[len(repo)+1:]

        directory = os.path.dirname(clean_path)
        if not directory:
            directory = "/" # Gyökér

        filename = os.path.basename(clean_path)
        repo_map[repo][directory].append(filename)

    # 3. Kiírjuk az eredményt fájlba (Markdown/Text formátumban a könnyű olvasásért)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 🗺️ RAG KÖNYVTÁRI KATALÓGUS (FRAKTÁL-MEMÓRIA MAPPA)\n")
        f.write("Használat: Ezt a fájlt olvasd, hogy megtudd, hol keresd a kódot. Ha megvan a fájl, használd a rag_interrogator.py-t!\n\n")

        for repo in sorted(repo_map.keys()):
            f.write(f"## 📦 {repo}\n")

            for directory in sorted(repo_map[repo].keys()):
                files = sorted(repo_map[repo][directory])
                f.write(f"  📂 {directory}/\n")

                # Tömörítjük a kimenetet: max 10 fájl egy sorban
                file_chunks = [files[i:i + 5] for i in range(0, len(files), 5)]
                for chunk in file_chunks:
                    f.write(f"      📄 {', '.join(chunk)}\n")
            f.write("\n")

    print(f"✅ RAG Katalógus sikeresen legenerálva ide: {output_file}")

def extract_signatures(db_path: str, output_file: str, target_repo: str = None, repo_list: list = None):
    """
    Speciális "Mélyfúrás" de memóriakímélő módon:
    Csak a Python class és def definíciókat húzza ki a kódokból.
    Buktató (OOM) elkerülése: LIMIT/OFFSET (Batch) iterátor használata a fetchall() helyett!
    """
    if not os.path.exists(db_path):
        return

    print(f"🔍 Python Szignatúra kinyerése (BATCH MÓD, OOM VÉDELEMMEL). Repó: {target_repo if target_repo else 'Kijelöltek/Minden'}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Építjük az alapszűrést
    base_query = "SELECT source_repo, filepath, content FROM rag_data WHERE filepath LIKE '%.py'"
    params = []

    if target_repo:
        base_query += " AND source_repo = ?"
        params.append(target_repo)
    elif repo_list:
        placeholders = ','.join(['?'] * len(repo_list))
        base_query += f" AND source_repo IN ({placeholders})"
        params.extend(repo_list)

    # Szigorú rendezés az OFFSET/LIMIT determinisztikus működéséért!
    base_query += " ORDER BY rowid"

    signature_map = defaultdict(list)
    class_pattern = re.compile(r"^\s*class\s+([A-Za-z0-9_]+)[\(:]")
    def_pattern = re.compile(r"^\s*def\s+([A-Za-z0-9_]+)\s*\(")

    batch_size = 500
    offset = 0
    total_processed = 0

    try:
        while True:
            # Szigorú kötegelés (LIMIT és OFFSET) a VPS RAM megóvása érdekében
            query = f"{base_query} LIMIT ? OFFSET ?"
            batch_params = params + [batch_size, offset]

            cursor.execute(query, batch_params)
            rows = cursor.fetchall()

            if not rows:
                break # Nincs több sor

            for repo, filepath, content in rows:
                if not content: continue

                found_signatures = []
                for line in content.splitlines():
                    class_match = class_pattern.match(line)
                    if class_match:
                        found_signatures.append(f"Class: {class_match.group(1)}")

                    def_match = def_pattern.match(line)
                    if def_match:
                        found_signatures.append(f"  Method/Func: {def_match.group(1)}")

                if found_signatures:
                     signature_map[filepath] = found_signatures

            total_processed += len(rows)
            offset += batch_size
            print(f"   ⏳ Feldolgozva: {total_processed} fájl...")

    except Exception as e:
        print(f"Hiba a kötegelt lekérdezésnél: {e}")
    finally:
        conn.close()

    # Eredmények kiírása fájlba
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 🧩 PYTHON SZIGNATÚRA TÉRKÉP (Mélyfúrás test nélkül)\n\n")
        for filepath in sorted(signature_map.keys()):
            f.write(f"📜 {filepath}\n")
            for sig in signature_map[filepath]:
                f.write(f"    {sig}\n")
            f.write("\n")

    print(f"✅ Szignatúra térkép sikeresen legenerálva ide: {output_file} ({total_processed} fájl alapján)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAG Scout - Memóriakímélő Tudásgráf Építő")
    parser.add_argument("--db", required=True, help="Az SQLite RAG adatbázis elérési útja")
    parser.add_argument("--mode", choices=["map", "signatures", "both"], default="map", help="Működési mód (Katalógus vagy Szignatúrák)")
    parser.add_argument("--out_map", default="knowledge_map.txt", help="Kimeneti fájl a katalógushoz")
    parser.add_argument("--out_sig", default="knowledge_signatures.txt", help="Kimeneti fájl a szignatúrákhoz")
    parser.add_argument("--repo", default=None, help="Speciális szignatúra keresés egy adott repóra")
    parser.add_argument("--repo_list_file", default=None, help="Egy TXT fájl, ami soronként tartalmazza a keresendő repók nevét")

    args = parser.parse_args()

    repo_list = None
    if args.repo_list_file and os.path.exists(args.repo_list_file):
        with open(args.repo_list_file, 'r', encoding='utf-8') as f:
            repo_list = [line.strip() for line in f if line.strip()]

    if args.mode in ["map", "both"]:
        create_repo_map(args.db, args.out_map)

    if args.mode in ["signatures", "both"]:
        extract_signatures(args.db, args.out_sig, args.repo, repo_list)