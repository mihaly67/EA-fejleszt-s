#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import os
import re
import numpy as np
import faiss
import difflib
import pickle
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi
from sklearn.metrics.pairwise import cosine_similarity

# --- KONFIGURACIO v3.1 (Optimized Cache + Dedup + Visible Recursion) ---
MODEL_NAME = 'all-mpnet-base-v2'
MAX_DEPTH = 3
BRANCHING_FACTOR = 3
TOP_K = 5
CACHE_FILE = 'rag_cache.pkl'

def log(msg, depth=0):
    indent = "   " * depth
    print(f"{indent}[UGYNOK v3.1]: {msg}")

def load_resources():
    # 1. Probaljuk betolteni a cache-bol
    if os.path.exists(CACHE_FILE):
        log("Gyorstarr (cache) betoltese...")
        try:
            with open(CACHE_FILE, 'rb') as f:
                data = pickle.load(f)
            # Ellenorizzuk a strukturat
            if 'docs' in data and 'bm25' in data:
                log(f"Cache betoltve: {len(data['docs'])} dokumentum.")
                model = SentenceTransformer(MODEL_NAME) # A modelt nem cache-eljuk (tul nagy/bonyolult)
                return data['docs'], model, data['bm25']
        except Exception as e:
            log(f"Hiba a cache betoltesekor ({e}), ujraepites...")

    # 2. Ha nincs cache, epitjuk elorol
    log("Adatbazis epitese JSON fajlokbol...")
    docs = []
    search_roots = ['rag_theory', 'rag_code', '.', 'rag_data', 'rag_data_codebase_ultimate', 'rag_data_theory_rich']

    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                if file.endswith('_adatok.json') or file.endswith('.json'):
                    if "package" in file or "lock" in file: continue
                    try:
                        path = os.path.join(root, file)
                        with open(path, 'r', encoding='utf-8') as f:
                            chunk = json.load(f)
                            stype = 'ELMELET' if 'theory' in root_dir else 'KOD'
                            if 'code' in root_dir: stype = 'KOD'

                            for d in chunk:
                                d['source_type'] = stype
                                d['origin_file'] = file
                                d['final_filename'] = d.get('filename') or d.get('source') or 'ISMERETLEN'

                                # Content elokeszitese kereseshez
                                txt = d.get('search_content') or d.get('content') or d.get('text') or ''
                                d['search_text'] = txt
                                d['tokenized_text'] = txt.lower().split()

                                docs.append(d)
                    except: pass

    if not docs:
        log("KRITIKUS HIBA: Ures adatbazis!")
        sys.exit(1)

    # 3. BM25 Index epitese (Ez a lassu resz!)
    log("BM25 Index epitese (ez eltarthat egy darabig)...")
    corpus = [d['tokenized_text'] for d in docs]
    bm25 = BM25Okapi(corpus)

    # 4. Cache mentes
    log(f"Cache mentese: {CACHE_FILE}...")
    try:
        with open(CACHE_FILE, 'wb') as f:
            pickle.dump({'docs': docs, 'bm25': bm25}, f)
    except Exception as e:
        log(f"Nem sikerult menteni a cache-t: {e}")

    model = SentenceTransformer(MODEL_NAME)
    log(f"Kesz. {len(docs)} dokumentum betoltve.")
    return docs, model, bm25

# --- FUNKCIO 1: KERESES (Deep Search) ---
def hybrid_search(query, docs, model, bm25, top_k=TOP_K):
    # 1. BM25 (Kulcsszo kereses - MOST MAR GYORS)
    tokenized_query = query.lower().split()
    bm25_scores = bm25.get_scores(tokenized_query)

    # Csak a legjobb 50-et vesszuk a re-rankinghez (gyorsitas)
    cand_idx = np.argsort(bm25_scores)[::-1][:50]
    candidates = [docs[i] for i in cand_idx if bm25_scores[i] > 0]

    if not candidates:
        return []

    # 2. Szemantikus Re-ranking (BERT)
    query_vec = model.encode([query])
    cand_txt = [c['search_text'] for c in candidates]
    cand_vecs = model.encode(cand_txt)

    sim_scores = cosine_similarity(query_vec, cand_vecs)[0]

    results = [{'doc': candidates[i], 'score': sim_scores[i]} for i in range(len(sim_scores))]
    results.sort(key=lambda x: x['score'], reverse=True)

    return results[:top_k]

def extract_concepts(text):
    concepts = set()
    # Improved Regex for Includes (handles "file.mqh" and <file.mqh>)
    includes = re.findall(r'#include\s*[<"](.*?)[>"]', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        if len(clean) > 2:
            concepts.add(f"MQL5 {clean} source code")

    # Classes (standard C+ClassName pattern)
    classes = re.findall(r'\bC[A-Z][a-zA-Z0-9]+\b', text)
    for cls in classes:
        if cls != "CArrayDouble" and cls != "CObject": # Skip basics
            concepts.add(f"MQL5 class {cls} definition")

    return list(concepts)

def recursive_search(query, docs, model, bm25, depth=0, visited=None):
    if visited is None: visited = set()
    q_sig = query.lower().strip()
    if q_sig in visited: return []
    visited.add(q_sig)

    if depth >= MAX_DEPTH: return []

    log(f"Melyseg {depth}: Kutatas erre: '{query}'", depth)

    hits = hybrid_search(query, docs, model, bm25)
    all_findings = []

    for hit in hits:
        doc = hit['doc']
        all_findings.append({'depth': depth, 'query': query, 'doc': doc, 'score': hit['score']})

        if depth < MAX_DEPTH - 1:
            content = doc.get('content') or doc.get('text') or ""
            new_concepts = extract_concepts(content)
            for concept in new_concepts[:BRANCHING_FACTOR]:
                if concept.lower() not in visited:
                    log(f"   -> Uj szal: {concept}", depth) # UNCOMMENTED
                    sub = recursive_search(concept, docs, model, bm25, depth + 1, visited)
                    all_findings.extend(sub)
    return all_findings

# --- FUNKCIO 2: DEDUPLIKACIO ---
def is_duplicate(content, seen_contents, threshold=0.8):
    # Egyszeru string similarity ellenorzes
    if not content: return False
    # Gyors hash check
    h = hash(content[:500]) # Csak az elso 500 karaktert nezzuk
    if h in seen_contents: return True
    return False

# --- FUNKCIO 3: OSSZESZERELES ---
def read_full_file(filename_query, docs):
    print(f"--- FAJL OSSZEALLITASA: '{filename_query}' ---")
    parts = [d for d in docs if filename_query.lower() in d['final_filename'].lower()]

    if not parts:
        print("HIBA: Nem talaltam ilyen nevu fajlt az adatbazisban.")
        return

    try: parts.sort(key=lambda x: int(x.get('part', 1)))
    except: pass

    print(f"MEGTALALVA: {parts[0]['final_filename']} ({len(parts)} darab)")
    print("=" * 60)
    full_content = "".join([p.get('content', '') + "\n" for p in parts])
    print(full_content)
    print("=" * 60)

# --- FO PROGRAM ---
def main():
    if len(sys.argv) < 3:
        print("Hasznalat:")
        print("  1. Kereses: python kutato_ugynok_v3.py search \"keresoszavak\"")
        print("  2. Olvasas: python kutato_ugynok_v3.py read \"Experts/MyEA.mq5\"")
        sys.exit(1)

    action = sys.argv[1]
    query = ' '.join(sys.argv[2:])

    try:
        # Load resources (with caching!)
        docs, model, bm25 = load_resources()
    except Exception as e:
        print(f"Hiba: {e}")
        sys.exit(1)

    if action == 'read':
        read_full_file(query, docs)
        return

    print(f"\n--- MELYFURO KUTATAS (v3.1 Optimized) INDITASA ---")
    print(f"Kerdes: '{query}'")
    print("="*60)

    results = recursive_search(query, docs, model, bm25)

    print("\n" + "="*60)
    print(f"OSSZEGYUJTOTT TUDASHALO ({len(results)} csomopont)")
    print("="*60)

    # Eredmenyek szurese (Deduplikacio)
    seen_sigs = set()
    unique_results = []

    # Sorbarendezes score szerint
    results.sort(key=lambda x: x['score'], reverse=True)

    for res in results:
        content = res['doc'].get('content') or res['doc'].get('text') or ""
        # Signature: elso 100 karakter + fajlnev
        sig = (content[:100] + res['doc'].get('final_filename', '')).strip()

        if sig in seen_sigs:
            continue

        seen_sigs.add(sig)
        unique_results.append(res)

    # Megjelenites
    for res in unique_results[:10]: # Max 10 egyedi talalat
        indent = "  " * res['depth']
        marker = "GYOKER" if res['depth'] == 0 else "AG"
        stype = res['doc'].get('source_type', 'RAG')
        fname = res['doc'].get('final_filename', '?')

        print(f"\n{indent}[{marker} | {stype} | {fname}] (Score: {res['score']:.2f})")
        print(f"{indent}Kontextus: {res['query']}")
        print("-" * 60)
        display_text = (res['doc'].get('content') or "")[:2000].replace('\n', f'\n{indent}')
        print(f"{indent}{display_text}...")

if __name__ == "__main__":
    main()
