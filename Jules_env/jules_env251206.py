 pip install gdown sentence-transformers faiss-cpu numpy rank_bm25 flashrank rapidfuzz pandas networkx chardet && python -c "import os, gdown, zipfile; downloads = {'rag_theory': os.environ.get('RAG_DRIVE_LINK'), 'rag_code': os.environ.get('CODEBASE_RAG_DRIVE_LINK'), 'rag_mql5_dev': os.environ.get('MQL5_RAG_DRIVE_LINK')}; [ (print(f'Letoltes: {k}...'), gdown.download(v, f'{k}.zip', quiet=False, fuzzy=True), print(f'Kicsomagolas: {k}...'), os.makedirs(k, exist_ok=True), zipfile.ZipFile(f'{k}.zip', 'r').extractall(k), os.remove(f'{k}.zip')) for k, v in downloads.items() if v ];" && cat << 'EOF' > kutato.py
#!/usr/bin/env python
import sys, json, faiss, numpy as np, os, re, argparse, pickle
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi

# Modellek definialasa
MODELS = {
    'mpnet': 'all-mpnet-base-v2',
    'minilm': 'all-MiniLM-L6-v2'
}
TOP_K = 5

def load_resources(model_key='mpnet'):
    print(f"   [AGY]: Memoria betoltese (Modell: {MODELS[model_key]})...")
    docs = []

    # 1. PRE-BUILT INDEX LOAD (MiniLM specializacio - rag_mql5_dev)
    if model_key == 'minilm' and os.path.exists('rag_mql5_dev/index.pkl'):
        try:
            print("   [AGY]: Pre-built MQL5 index eszlelese...")
            with open('rag_mql5_dev/index.pkl', 'rb') as f:
                data = pickle.load(f)
                docs = data['docs']
                # Opcionális: BM25 betoltese ha van
        except Exception as e:
             print(f"   [AGY]: Hiba a pickle betoltesekor: {e}")

    # 2. JSON SCAN (Fallback vagy mas modellekhez)
    if not docs:
        search_roots = ['rag_theory', 'rag_code', 'rag_mql5_dev']
        for root_dir in search_roots:
            if not os.path.exists(root_dir): continue
            for root, dirs, files in os.walk(root_dir):
                for file in files:
                    if file.endswith('_adatok.json') or file.endswith('.json'):
                        try:
                            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                                chunk = json.load(f)
                                stype = 'ELMELET'
                                if 'code' in root_dir: stype = 'KOD'
                                elif 'mql5' in root_dir: stype = 'MQL5_DEV'

                                for d in chunk:
                                    d['source_type'] = stype
                                    d['origin_file'] = file
                                    d['final_filename'] = d.get('filename') or d.get('source') or '?'
                                    d['content'] = d.get('content') or d.get('search_content') or ''
                                    docs.append(d)
                        except: pass

    if not docs: print("HIBA: Ures adatbazis!"); sys.exit(1)

    # A kivalasztott modell betoltese
    model_name = MODELS.get(model_key, MODELS['mpnet'])
    try:
        model = SentenceTransformer(model_name)
    except Exception as e:
        print(f"HIBA a modell betoltesekor ({model_name}): {e}")
        sys.exit(1)

    # FAISS Index betoltese (Ha van es MiniLM)
    faiss_index = None
    if model_key == 'minilm' and os.path.exists('rag_mql5_dev/index.faiss'):
         try:
             faiss_index = faiss.read_index('rag_mql5_dev/index.faiss')
             print(f"   [AGY]: FAISS index betoltve ({faiss_index.ntotal} vektor).")
         except Exception as e:
             print(f"   [AGY]: FAISS betoltesi hiba: {e}")

    return docs, model, faiss_index

def hybrid_search(query, docs, model, faiss_index=None):
    # 1. Kulcsszavas kereses (BM25) - Ez modell-fuggetlen
    corpus = [(d.get('search_content') or d.get('content') or '').lower().split() for d in docs]
    bm25 = BM25Okapi(corpus)
    scores = bm25.get_scores(query.lower().split())

    # BM25 eloszures
    cand_idx = np.argsort(scores)[::-1][:100]
    candidates = [docs[i] for i in cand_idx if scores[i] > 0]

    # 2. Szemantikus kereses
    q_vec = model.encode([query])

    if faiss_index:
        # FAISS hasznalata
        # Fontos: A docs lista sorrendje meg kell egyezzen a FAISS index ID-jaival!
        D, I = faiss_index.search(q_vec, TOP_K * 2)
        results = []
        for j, idx in enumerate(I[0]):
            if idx != -1 and idx < len(docs):
                results.append({'doc': docs[idx], 'score': 1.0 / (1.0 + D[0][j])})
    else:
        # On-the-fly embedding (Fallback)
        if not candidates: candidates = docs[:200]
        cand_txt = [c.get('search_content') or c.get('content') for c in candidates]
        cand_vec = model.encode(cand_txt)

        from sklearn.metrics.pairwise import cosine_similarity
        sim = cosine_similarity(q_vec, cand_vec)[0]
        results = [{'doc': candidates[i], 'score': sim[i]} for i in range(len(sim))]

    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:TOP_K]

def read_file_stitching(fname, docs):
    print(f"   [AGY]: Fajl osszevarrasa: {fname}")
    parts = [d for d in docs if fname.lower() in d['final_filename'].lower()]
    if not parts: print("Nincs ilyen fajl."); return
    try: parts.sort(key=lambda x: int(x.get('part', 0)))
    except: pass
    print(f"\n=== FAJL TARTALMA: {parts[0]['final_filename']} ({len(parts)} darab) ===\n")
    for p in parts:
        print(p.get('content', ''))
    print("\n=== VEGE ===\n")

def main():
    parser = argparse.ArgumentParser(description="Kutato Ugynok - Universal")
    parser.add_argument('action', choices=['search', 'read'], help='Muvelet')
    parser.add_argument('query', nargs='+', help='Keresoszo vagy fajlnev')
    parser.add_argument('--model', choices=['mpnet', 'minilm'], default='mpnet', help='Modell')
    args = parser.parse_args()

    q = ' '.join(args.query)
    docs, model, faiss_index = load_resources(args.model)

    if args.action == 'read':
        read_file_stitching(q, docs)
        return

    print(f"   [AGY]: Kereses: '{q}' (Modell: {args.model})")
    hits = hybrid_search(q, docs, model, faiss_index)

    print(f"\nTALALATOK:")
    for i, h in enumerate(hits):
        d = h['doc']
        print(f"\n[{d['source_type']} | {d['final_filename']}] (Score: {h['score']:.2f})")
        print("-" * 60)
        print((d.get('content') or '')[:1500] + "...")

if __name__ == "__main__":
    main()
EOF
echo "kutato.py" >> .git/info/exclude && echo "rag_theory" >> .git/info/exclude && echo "rag_code" >> .git/info/exclude && echo "rag_mql5_dev" >> .git/info/exclude && echo "INSTRUCTIONS.md" >> .git/info/exclude
