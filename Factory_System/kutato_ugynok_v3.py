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

# --- KONFIGURACIO v4.0 (Universal Heavy Worker) ---
MODELS = {
    'mpnet': 'all-mpnet-base-v2',
    'minilm': 'all-MiniLM-L6-v2'
}
MAX_DEPTH = 3
BRANCHING_FACTOR = 3
TOP_K = 5
CACHE_FILE_MPNET = '/tmp/rag_cache_v3_mpnet.pkl'
CACHE_FILE_MINILM = '/tmp/rag_cache_v3_minilm.pkl'

def log(msg, depth=0):
    indent = "   " * depth
    sys.stderr.write(f"{indent}[HEAVY WORKER]: {msg}\n")

def check_system_load():
    try:
        load = os.getloadavg()[0]
        if load > 3.0:
            log(f"Magas terheles ({load:.2f}). Pihenes...")
            time.sleep(5)
    except: pass

def load_resources(model_key='mpnet'):
    cache_file = CACHE_FILE_MINILM if model_key == 'minilm' else CACHE_FILE_MPNET

    # 1. PRE-BUILT MQL5 INDEX (Special case for MiniLM)
    if model_key == 'minilm' and os.path.exists('rag_mql5_dev/index.pkl'):
        log("MQL5 Dev index (Pre-built) betoltese...")
        try:
            with open('rag_mql5_dev/index.pkl', 'rb') as f:
                data = pickle.load(f)
            docs = data['docs']

            # BM25 betoltes vagy epites
            if 'bm25' in data:
                bm25 = data['bm25']
            else:
                log("BM25 ujraepitese...")
                corpus = [(d.get('search_content') or d.get('content') or '').lower().split() for d in docs]
                bm25 = BM25Okapi(corpus)

            model = SentenceTransformer(MODELS['minilm'])

            # FAISS betoltes
            faiss_index = None
            if os.path.exists('rag_mql5_dev/index.faiss'):
                faiss_index = faiss.read_index('rag_mql5_dev/index.faiss')

            return docs, model, bm25, faiss_index
        except Exception as e:
            log(f"Hiba a pre-built index betoltesekor: {e}")

    # 2. JSON/Cache Load
    if os.path.exists(cache_file):
        log("Gyorstar betoltese...")
        try:
            with open(cache_file, 'rb') as f:
                data = pickle.load(f)
            if 'docs' in data and 'bm25' in data:
                model = SentenceTransformer(MODELS.get(model_key, MODELS['mpnet']))
                return data['docs'], model, data['bm25'], None
        except Exception as e:
            log(f"Cache hiba: {e}")

    log("Adatbazis epitese...")
    docs = []
    search_roots = ['rag_theory', 'rag_code', 'rag_mql5_dev']

    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                if file.endswith('_adatok.json') or file.endswith('.json'):
                    try:
                        path = os.path.join(root, file)
                        with open(path, 'r', encoding='utf-8') as f:
                            chunk = json.load(f)
                            stype = 'UNKNOWN'
                            if 'code' in root_dir or 'knowledge' in root_dir: stype = 'KOD'
                            elif 'theory' in root_dir: stype = 'ELMELET'
                            elif 'mql5' in root_dir: stype = 'MQL5_DEV'

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
        with open(cache_file, 'wb') as f:
            pickle.dump({'docs': docs, 'bm25': bm25}, f)
    except: pass

    model = SentenceTransformer(MODELS.get(model_key, MODELS['mpnet']))
    return docs, model, bm25, None

def hybrid_search(query, docs, model, bm25, faiss_index=None):
    # BM25 (Kulcsszo)
    tokenized_query = query.lower().split()
    bm25_scores = bm25.get_scores(tokenized_query)

    cand_idx = np.argsort(bm25_scores)[::-1][:100]
    candidates = [docs[i] for i in cand_idx if bm25_scores[i] > 0]

    if not candidates and faiss_index:
        # Ha csak vektorban van talalat
        pass
    elif not candidates:
        return []

    # Vector Search
    q_vec = model.encode([query])

    results = []

    if faiss_index:
        D, I = faiss_index.search(q_vec, TOP_K * 2)
        for j, idx in enumerate(I[0]):
            if idx != -1 and idx < len(docs):
                 results.append({'doc': docs[idx], 'score': 1.0 / (1.0 + D[0][j])})
    else:
        cand_txt = [c['search_text'] for c in candidates]
        cand_vecs = model.encode(cand_txt)
        sim_scores = cosine_similarity(q_vec, cand_vecs)[0]
        results = [{'doc': candidates[i], 'score': sim_scores[i]} for i in range(len(sim_scores))]

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:TOP_K]

def extract_concepts(text):
    concepts = set()
    includes = re.findall(r'#include\s*[<"](.*?)[>"]', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        if len(clean) > 2: concepts.add(f"MQL5 {clean}")
    return list(concepts)

def recursive_search(query, docs, model, bm25, faiss_index=None, depth=0, visited=None):
    check_system_load()

    if visited is None: visited = set()
    q_sig = query.lower().strip()
    if q_sig in visited: return []
    visited.add(q_sig)

    if depth >= MAX_DEPTH: return []

    log(f"Melyseg {depth}: '{query}'", depth)
    hits = hybrid_search(query, docs, model, bm25, faiss_index)
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
                    sub = recursive_search(concept, docs, model, bm25, faiss_index, depth + 1, visited)
                    all_findings.extend(sub)
    return all_findings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--query', required=True)
    parser.add_argument('--scope', default='ALL')
    parser.add_argument('--depth', type=int, default=3)
    parser.add_argument('--model', choices=['mpnet', 'minilm'], default='mpnet')
    parser.add_argument('--output', choices=['json', 'text'], default='text')
    args, unknown = parser.parse_known_args()

    global MAX_DEPTH
    MAX_DEPTH = args.depth

    docs, model, bm25, faiss_index = load_resources(args.model)

    results = recursive_search(args.query, docs, model, bm25, faiss_index)

    unique_results = []
    seen = set()
    results.sort(key=lambda x: x['score'], reverse=True)

    for r in results:
        fname = r['doc'].get('final_filename', '')
        if fname not in seen:
            seen.add(fname)
            unique_results.append(r)
            if len(unique_results) >= 20: break

    if args.output == 'json':
        print(json.dumps(unique_results, indent=2))
    else:
        for r in unique_results:
            print(f"[{r['doc'].get('source_type')}] {r['doc'].get('final_filename')} ({r['score']:.2f})")

if __name__ == "__main__":
    main()
