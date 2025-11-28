#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import os
import re
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi

# --- KONFIGURACIO v2.0 ---
MODEL_NAME = 'all-mpnet-base-v2'
MAX_STEPS = 5       # Melyseg (hany korben keressen)
TOP_K = 10           # Talalatok szama koronkent

def log(msg):
    print(f"   [UGYNOK v2.0]: {msg}")

def load_resources():
    log("Memoria betoltese (Theory + Code)...")
    docs = []
    # Ezeket a mappakat nezi a VM-en
    search_roots = ['rag_theory', 'rag_code', '.', 'rag_data']

    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                if file.endswith('_adatok.json') or file.endswith('.json'):
                    # Kizarjuk a technikai fajlokat
                    if "package" in file or "lock" in file: continue

                    try:
                        path = os.path.join(root, file)
                        with open(path, 'r', encoding='utf-8') as f:
                            chunk = json.load(f)
                            # Milyen tipusu tudas ez?
                            stype = 'ELMELET' if 'theory' in root_dir else 'KOD'
                            if 'code' in root_dir: stype = 'KOD'

                            for d in chunk:
                                d['source_type'] = stype
                                d['origin_file'] = file
                                docs.append(d)
                    except Exception as e:
                        pass

    if not docs:
        log("HIBA: Nem talalhato indexelt adat (JSON) a mappakban.")
        sys.exit(1)

    try:
        model = SentenceTransformer(MODEL_NAME)
    except:
        log("HIBA: A modell betoltese sikertelen. (pip install sentence-transformers?)")
        sys.exit(1)

    log(f"Kesz. {len(docs)} dokumentum betoltve.")
    return docs, model

def hybrid_search(query, docs, model, top_k=TOP_K):
    # 1. BM25 (Kulcsszo kereses)
    corpus = [(d.get('search_content') or d.get('content') or d.get('text') or '').lower().split() for d in docs]
    bm25 = BM25Okapi(corpus)
    bm25_scores = bm25.get_scores(query.lower().split())

    # Eloszurunk: csak a legjobb 100 BM25 talalatot nezzuk meg a lassabb AI-val
    cand_idx = np.argsort(bm25_scores)[::-1][:100]
    candidates = [docs[i] for i in cand_idx if bm25_scores[i] > 0]

    if not candidates:
        # Ha nincs kulcsszavas egyezes, nezzuk az elso 200-at (fallback)
        candidates = docs[:200]

    # 2. Szemantikus Re-ranking (AI)
    query_vec = model.encode([query])
    cand_texts = [c.get('search_content') or c.get('content') or c.get('text') for c in candidates]
    cand_vecs = model.encode(cand_texts)

    from sklearn.metrics.pairwise import cosine_similarity
    sim_scores = cosine_similarity(query_vec, cand_vecs)[0]

    results = []
    for i, score in enumerate(sim_scores):
        results.append({'doc': candidates[i], 'score': score})

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

def extract_next_steps(text):
    """Kinyeri a kodbol a fuggosegeket (include, osztaly)."""
    next_queries = []
    # Include fajlok
    includes = re.findall(r'#include <(.*?)>', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        next_queries.append(f"MQL5 {clean} source code definition")

    # Osztalyok
    classes = re.findall(r'\bC[A-Z][a-zA-Z0-9]+\b', text)
    for cls in classes:
        next_queries.append(f"MQL5 class {cls} definition")

    return list(set(next_queries))

def main():
    if len(sys.argv) < 2:
        print("Hasznalat: python kutato_ugynok_v2.py \"kerdes\"")
        sys.exit(1)

    initial_query = ' '.join(sys.argv[1:])

    docs, model = load_resources()

    print(f"\n--- KUTATAS INDITASA: '{initial_query}' ---\n")

    knowledge_base = []
    queue = [initial_query]
    visited = set()

    for step in range(MAX_STEPS):
        if not queue: break
        current_q = queue.pop(0)

        q_sig = current_q.lower().strip()
        if q_sig in visited: continue

        log(f"Lepes {step+1}: Kutatas erre: '{current_q}'")
        visited.add(q_sig)

        hits = hybrid_search(current_q, docs, model)

        if hits:
            log(f"   -> Talalat: {len(hits)} db")
            for hit in hits:
                doc = hit['doc']
                if doc not in knowledge_base:
                    knowledge_base.append(doc)

                # Csak az elso korben keresunk uj nyomokat (hogy ne fusson orakig)
                if step == 0:
                    content = doc.get('content') or doc.get('text') or ""
                    new_leads = extract_next_steps(content)
                    for lead in new_leads:
                        if lead.lower().strip() not in visited:
                            log(f"      -> Uj nyom: {lead}")
                            queue.append(lead)
        else:
            log("   -> Nincs talalat.")

    print("\n" + "="*60)
    print("OSSZEGYUJTOTT TUDAS (JULES SZAMARA)")
    print("="*60)

    seen = set()
    for i, doc in enumerate(knowledge_base):
        content = doc.get('content') or doc.get('text') or ""
        sig = content[:100]
        if sig in seen: continue
        seen.add(sig)

        stype = doc.get('source_type', 'RAG')
        fname = doc.get('filename') or doc.get('source') or '?'

        print(f"\nRESULT #{i+1} [{stype} | {fname}]")
        print("-" * 40)
        # Max 2000 karaktert irunk ki talalatonkent, hogy Jules lasson eleget
        print(content[:2000] + ("\n... (folytatas a fajlban)" if len(content) > 2000 else ""))
        print("-" * 40)

if __name__ == "__main__":
    main()
