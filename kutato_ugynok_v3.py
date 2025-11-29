
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import os
import re
import numpy as np
import faiss
import difflib
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi

# --- KONFIGURACIO v3.0 (Deep Miner + Stitcher) ---
MODEL_NAME = 'all-mpnet-base-v2'
MAX_DEPTH = 3        # Milyen melyre asson?
BRANCHING_FACTOR = 3 # Hany uj szalat inditson talalatonkent?
TOP_K = 5            # Hany talalatot hozzon egy keresesre?

def log(msg, depth=0):
    indent = "   " * depth
    print(f"{indent}[UGYNOK v3]: {msg}")

def load_resources():
    log("Memoria es Indexek betoltese...")
    docs = []
    # Ezeket a mappakat nezi a VM-en
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
                                # Normalizaljuk a fajlnevet a kereseshez
                                d['final_filename'] = d.get('filename') or d.get('source') or 'ISMERETLEN'
                                docs.append(d)
                    except: pass

    if not docs:
        log("KRITIKUS HIBA: Ures adatbazis!")
        sys.exit(1)

    model = SentenceTransformer(MODEL_NAME)
    log(f"Kesz. {len(docs)} dokumentum betoltve.")
    return docs, model

# --- FUNKCIO 1: KERESES (Deep Search) ---
def hybrid_search(query, docs, model, top_k=TOP_K):
    # 1. BM25 (Kulcsszo kereses)
    corpus = [(d.get('search_content') or d.get('content') or d.get('text') or '').lower().split() for d in docs]
    bm25 = BM25Okapi(corpus)
    bm25_scores = bm25.get_scores(query.lower().split())

    cand_idx = np.argsort(bm25_scores)[::-1][:100]
    candidates = [docs[i] for i in cand_idx if bm25_scores[i] > 0]
    if not candidates: candidates = docs[:200]

    # 2. Szemantikus Re-ranking
    query_vec = model.encode([query])
    cand_txt = [c.get('search_content') or c.get('content') or c.get('text') for c in candidates]
    cand_vecs = model.encode(cand_txt)

    from sklearn.metrics.pairwise import cosine_similarity
    sim_scores = cosine_similarity(query_vec, cand_vecs)[0]

    results = [{'doc': candidates[i], 'score': sim[i]} for i in range(len(sim))]
    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

def extract_concepts(text):
    concepts = set()
    includes = re.findall(r'#include <(.*?)>', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        concepts.add(f"MQL5 {clean} source code")

    classes = re.findall(r'\bC[A-Z][a-zA-Z0-9]+\b', text)
    for cls in classes: concepts.add(f"MQL5 class {cls} definition")

    funcs = re.findall(r'\b(void|int|double|bool)\s+(\w+)\s*\(', text)
    for _, name in funcs:
        if len(name) > 3: concepts.add(f"MQL5 function {name}")

    return list(concepts)

def recursive_search(query, docs, model, depth=0, visited=None):
    if visited is None: visited = set()
    q_sig = query.lower().strip()
    if q_sig in visited: return []
    visited.add(q_sig)

    if depth >= MAX_DEPTH: return []

    log(f"Melyseg {depth}: Kutatas erre: '{query}'", depth)

    hits = hybrid_search(query, docs, model)
    all_findings = []

    for hit in hits:
        doc = hit['doc']
        all_findings.append({'depth': depth, 'query': query, 'doc': doc, 'score': hit['score']})

        if depth < MAX_DEPTH - 1:
            content = doc.get('content') or doc.get('text') or ""
            new_concepts = extract_concepts(content)
            for concept in new_concepts[:BRANCHING_FACTOR]:
                if concept.lower() not in visited:
                    log(f"   -> Uj szal: {concept}", depth)
                    sub = recursive_search(concept, docs, model, depth + 1, visited)
                    all_findings.extend(sub)
    return all_findings

# --- FUNKCIO 2: OSSZESZERELES (Stitching) ---
def read_full_file(filename_query, docs):
    print(f"--- FAJL OSSZEALLITASA: '{filename_query}' ---")
    parts = []
    for d in docs:
        # Laza egyezes a fajlnevre
        if filename_query.lower() in d['final_filename'].lower():
            parts.append(d)

    if not parts:
        print("HIBA: Nem talaltam ilyen nevu fajlt az adatbazisban.")
        return

    # Rendezes a 'part' mezo szerint (ha van)
    try: parts.sort(key=lambda x: int(x.get('part', 1)))
    except: pass

    print(f"MEGTALALVA: {parts[0]['final_filename']} ({len(parts)} darab)")
    print("=" * 60)

    full_content = ""
    for p in parts:
        full_content += p.get('content', '') + "\n"

    print(full_content)
    print("=" * 60)
    print("VEGE A FAJLNAK.")

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
        docs, model = load_resources()
    except Exception as e:
        print(f"Hiba: {e}")
        sys.exit(1)

    if action == 'read':
        read_full_file(query, docs)
        return

    print(f"\n--- MELYFURO KUTATAS (v3.0) INDITASA ---")
    print(f"Kerdes: '{query}'")
    print("="*60)

    results = recursive_search(query, docs, model)

    print("\n" + "="*60)
    print(f"OSSZEGYUJTOTT TUDASHALO ({len(results)} csomopont)")
    print("="*60)

    seen = set()
    results.sort(key=lambda x: (x['depth'], -x['score']))

    for res in results:
        content = res['doc'].get('content') or res['doc'].get('text') or ""
        sig = content[:100]
        if sig in seen: continue
        seen.add(sig)

        indent = "  " * res['depth']
        marker = "GYOKER" if res['depth'] == 0 else "AG"
        stype = res['doc'].get('source_type', 'RAG')
        fname = res['doc'].get('final_filename', '?')

        print(f"\n{indent}[{marker} | {stype} | {fname}] (Score: {res['score']:.2f})")
        print(f"{indent}Kontextus: {res['query']}")
        print("-" * 60)
        # 2000 karaktert mutatunk
        display_text = content[:2000].replace('\n', f'\n{indent}')
        print(f"{indent}{display_text}...")

if __name__ == "__main__":
    main()
