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
import time
import argparse
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi
from sklearn.metrics.pairwise import cosine_similarity

# --- KONFIGURACIO v3.3 (Heavy Worker + Load Aware) ---
MODEL_NAME = 'all-mpnet-base-v2'
MAX_DEPTH = 3
BRANCHING_FACTOR = 3
TOP_K = 5
CACHE_FILE = '/tmp/rag_cache_v3.pkl' # TMP-be mentjuk

def log(msg, depth=0):
    indent = "   " * depth
    # Csak stderr-re irunk, hogy a stdout tiszta JSON maradhasson
    sys.stderr.write(f"{indent}[HEAVY WORKER]: {msg}\n")

def check_system_load():
    try:
        load = os.getloadavg()[0]
        # Ha a terheles magas (pl. > 3.0 4 magon), pihenunk
        if load > 3.0:
            log(f"Magas terheles ({load:.2f}). Pihenes...")
            time.sleep(5)
    except: pass

def load_resources():
    if os.path.exists(CACHE_FILE):
        log("Gyorstar betoltese...")
        try:
            with open(CACHE_FILE, 'rb') as f:
                data = pickle.load(f)
            if 'docs' in data and 'bm25' in data:
                model = SentenceTransformer(MODEL_NAME)
                return data['docs'], model, data['bm25']
        except Exception as e:
            log(f"Cache hiba: {e}")

    log("Adatbazis epitese...")
    docs = []
    # Uj eleresi utak
    search_roots = ['/tmp/rag_theory', '/tmp/rag_code', '/tmp/new_knowledge', '/tmp/research_articles']

    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                if file.endswith('_adatok.json') or file.endswith('.json'):
                    try:
                        path = os.path.join(root, file)
                        with open(path, 'r', encoding='utf-8') as f:
                            chunk = json.load(f)
                            stype = 'KOD' if 'code' in root_dir or 'knowledge' in root_dir else 'ELMELET'
                            for d in chunk:
                                d['source_type'] = stype
                                d['origin_file'] = file
                                d['final_filename'] = d.get('filename') or d.get('source') or '?'
                                txt = d.get('search_content') or d.get('content') or ''
                                d['search_text'] = txt
                                d['tokenized_text'] = txt.lower().split()
                                docs.append(d)
                    except: pass

    if not docs:
        log("KRITIKUS HIBA: Ures adatbazis!")
        sys.exit(1)

    log("BM25 Index epitese...")
    corpus = [d['tokenized_text'] for d in docs]
    bm25 = BM25Okapi(corpus)

    try:
        with open(CACHE_FILE, 'wb') as f:
            pickle.dump({'docs': docs, 'bm25': bm25}, f)
    except: pass

    model = SentenceTransformer(MODEL_NAME)
    return docs, model, bm25

def hybrid_search(query, docs, model, bm25):
    tokenized_query = query.lower().split()
    bm25_scores = bm25.get_scores(tokenized_query)

    # Kisebb pool a sebesseg miatt, de a Heavy Workernek tobb ido jut
    cand_idx = np.argsort(bm25_scores)[::-1][:100]
    candidates = [docs[i] for i in cand_idx if bm25_scores[i] > 0]

    if not candidates: return []

    query_vec = model.encode([query])
    cand_txt = [c['search_text'] for c in candidates]
    cand_vecs = model.encode(cand_txt)

    sim_scores = cosine_similarity(query_vec, cand_vecs)[0]
    results = [{'doc': candidates[i], 'score': sim_scores[i]} for i in range(len(sim_scores))]
    results.sort(key=lambda x: x['score'], reverse=True)
    return results

def extract_concepts(text):
    concepts = set()
    includes = re.findall(r'#include\s*[<"](.*?)[>"]', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        if len(clean) > 2: concepts.add(f"MQL5 {clean}")
    return list(concepts)

def recursive_search(query, docs, model, bm25, depth=0, visited=None):
    check_system_load() # Load Awareness

    if visited is None: visited = set()
    q_sig = query.lower().strip()
    if q_sig in visited: return []
    visited.add(q_sig)

    if depth >= MAX_DEPTH: return []

    log(f"Melyseg {depth}: '{query}'", depth)
    hits = hybrid_search(query, docs, model, bm25)
    all_findings = []

    valid_count = 0
    for hit in hits:
        doc = hit['doc']
        all_findings.append({'doc': doc, 'score': float(hit['score']), 'depth': depth, 'query': query})
        valid_count += 1
        if valid_count >= TOP_K: break

        if depth < MAX_DEPTH - 1:
            content = doc.get('content') or ""
            concepts = extract_concepts(content)
            for concept in concepts[:BRANCHING_FACTOR]:
                if concept.lower() not in visited:
                    sub = recursive_search(concept, docs, model, bm25, depth + 1, visited)
                    all_findings.extend(sub)
    return all_findings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--query', required=True)
    parser.add_argument('--scope', default='ALL') # Nem hasznaljuk meg, de a factory kuldi
    parser.add_argument('--depth', type=int, default=MAX_DEPTH) # Override allowed
    parser.add_argument('--output', choices=['json', 'text'], default='text')
    # A tobbi factory argumentumot (action, target_dir) figyelmen kivul hagyjuk vagy bovithetnenk
    args, unknown = parser.parse_known_args()

    global MAX_DEPTH
    MAX_DEPTH = args.depth

    docs, model, bm25 = load_resources()

    results = recursive_search(args.query, docs, model, bm25)

    # Deduplikacio es rendezes
    unique_results = []
    seen = set()
    results.sort(key=lambda x: x['score'], reverse=True)

    for r in results:
        fname = r['doc'].get('final_filename', '')
        if fname not in seen:
            seen.add(fname)
            unique_results.append(r)
            if len(unique_results) >= 20: break # Max limit

    if args.output == 'json':
        print(json.dumps(unique_results, indent=2))
    else:
        for r in unique_results:
            print(f"[{r['doc'].get('source_type')}] {r['doc'].get('final_filename')} ({r['score']:.2f})")

if __name__ == "__main__":
    main()
