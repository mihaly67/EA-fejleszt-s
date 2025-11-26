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

# --- KONFIGURÁCIÓ ---
MODEL_NAME = 'all-mpnet-base-v2'
MAX_STEPS = 3       # Hány lépés mélységbe ásson le?
TOP_K = 4           # Hány találatot hozzon lépésenként?

def log(msg):
    """Látható visszajelzés."""
    print(f"   [ÜGYNÖK]: {msg}")

def load_resources():
    log("Memória és Indexek betöltése...")
    docs = []
    search_roots = ['rag_theory', 'rag_code']

    # Ha nincsenek letöltött mappák, nézzük a gyökeret is (hátha ott van a JSONL)
    if not os.path.exists('rag_theory') and not os.path.exists('rag_code'):
        search_roots.append('.')

    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                # Támogatjuk a .json és a .jsonl formátumot is
                if file.endswith('_adatok.json') or file.endswith('.json') or file == 'knowledge_base.jsonl':
                    try:
                        path = os.path.join(root, file)
                        with open(path, 'r', encoding='utf-8') as f:
                            if file.endswith('.jsonl'):
                                # JSONL beolvasás soronként
                                for line in f:
                                    if line.strip():
                                        d = json.loads(line)
                                        d['source_type'] = 'REPO'
                                        d['origin'] = file
                                        docs.append(d)
                            else:
                                # Sima JSON tömb beolvasás
                                chunk = json.load(f)
                                stype = 'ELMÉLET' if 'theory' in root_dir else 'KÓD'
                                for d in chunk:
                                    d['source_type'] = stype
                                    d['origin'] = file
                                    docs.append(d)
                    except Exception as e:
                        log(f"Hiba a {file} olvasásakor: {e}")

    if not docs:
        log("KRITIKUS HIBA: Üresek az indexek! Ellenőrizd a letöltést vagy a JSONL fájlt.")
        sys.exit(1)

    model = SentenceTransformer(MODEL_NAME)
    log(f"Kész. {len(docs)} dokumentum betöltve.")
    return docs, model

def hybrid_search(query, docs, model, top_k=TOP_K):
    """Kombinált keresés: BM25 (Kulcsszó) + MPNET (Szemantika)"""

    # 1. BM25 (Kulcsszó keresés)
    # Ez a leggyorsabb és legpontosabb a technikai szavakra (pl. CLR_GREEN)
    corpus = [(d.get('search_content') or d.get('content') or d.get('text') or '').lower().split() for d in docs]
    bm25 = BM25Okapi(corpus)
    bm25_scores = bm25.get_scores(query.lower().split())

    # Vegyük a BM25 legjobb 50 találatát (előszűrés)
    candidates_idx = np.argsort(bm25_scores)[::-1][:50]
    candidates = [docs[i] for i in candidates_idx if bm25_scores[i] > 0]

    if not candidates:
        log("BM25 nem talált pontos egyezést. Próbálkozás tisztán szemantikával...")
        # Ha nincs kulcsszavas találat, akkor nézzük át az egészet az AI-val (lassabb, de találhat valamit)
        candidates = docs[:500] # Limitáljuk 500-ra a sebesség miatt, ha nincs index
        if not candidates: return []

    # 2. Szemantikus Újrarangsorolás (Re-Ranking)
    # Az AI modell megnézi a jelölteket, és kiválasztja a kontextusban legjobbat
    query_vec = model.encode([query])
    candidate_texts = [c.get('search_content') or c.get('content') or c.get('text') for c in candidates]
    cand_embeddings = model.encode(candidate_texts)

    from sklearn.metrics.pairwise import cosine_similarity
    sim_scores = cosine_similarity(query_vec, cand_embeddings)[0]

    results = []
    for i, score in enumerate(sim_scores):
        results.append({'doc': candidates[i], 'score': score})

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

def extract_next_steps(text):
    """Kinyeri a kódból, hogy mire kellene még rákeresni (Rekurzió)."""
    next_queries = []
    # Include fájlok
    includes = re.findall(r'#include <(.*?)>', text)
    for inc in includes:
        clean_inc = inc.replace('\\', ' ').replace('.mqh', '')
        next_queries.append(f"MQL5 {clean_inc} content code")

    # Osztályok (C betűvel kezdődő PascalCase)
    classes = re.findall(r'\bC[A-Z][a-zA-Z0-9]+\b', text)
    for cls in classes:
        next_queries.append(f"MQL5 class {cls} definition usage")

    return list(set(next_queries))

def main():
    if len(sys.argv) < 2:
        print("Használat: python kutato_ugynok.py \"<kérdés>\"")
        sys.exit(1)

    initial_query = ' '.join(sys.argv[1:])

    try:
        docs, model = load_resources()
    except Exception as e:
        print(f"Hiba a betöltésnél: {e}")
        sys.exit(1)

    print(f"\n🔎 --- KUTATÁS INDÍTÁSA: '{initial_query}' ---\n")

    knowledge_base = []
    queue = [initial_query]
    visited = set()

    for step in range(MAX_STEPS):
        if not queue: break
        current_q = queue.pop(0)

        # Normalizálás a duplikációk elkerülésére
        q_sig = current_q.lower().strip()
        if q_sig in visited: continue

        log(f"Lépés {step+1}: Kutatás erre: '{current_q}'")
        visited.add(q_sig)

        hits = hybrid_search(current_q, docs, model)

        if hits:
            log(f"   -> Találtam {len(hits)} releváns infót.")
            for hit in hits:
                doc = hit['doc']
                # Csak akkor adjuk hozzá, ha még nincs benne
                if doc not in knowledge_base:
                    knowledge_base.append(doc)

                # Új nyomok keresése (csak az első körben, hogy ne fusson végtelenig)
                if step == 0:
                    content = doc.get('content') or doc.get('text') or ""
                    new_leads = extract_next_steps(content)
                    for lead in new_leads:
                        if lead.lower().strip() not in visited:
                            log(f"      -> Új nyom (Automata): {lead}")
                            queue.append(lead)
        else:
            log("   -> Nincs találat.")

    # EREDMÉNYEK KIÍRÁSA
    print("\n" + "="*60)
    print("📚 --- ÖSSZEGYŰJTÖTT TUDÁS (JULES SZÁMÁRA) ---")
    print("="*60)

    unique_content = set()
    for i, doc in enumerate(knowledge_base):
        content = doc.get('content') or doc.get('text') or ""
        signature = content[:100] # Egyszerű duplikátum szűrés az eleje alapján
        if signature in unique_content: continue
        unique_content.add(signature)

        src_type = doc.get('source_type', 'RAG')
        fname = doc.get('filename') or doc.get('source') or '?'

        print(f"\n📌 [{i+1}] FORRÁS: {src_type} | FÁJL: {fname}")
        print("-" * 40)
        print(content[:1500] + ("\n... (folytatás a fájlban)" if len(content) > 1500 else ""))
        print("-" * 40)

if __name__ == "__main__":
    main()
