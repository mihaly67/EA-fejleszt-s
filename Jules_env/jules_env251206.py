 pip install gdown sentence-transformers faiss-cpu numpy rank_bm25 flashrank rapidfuzz pandas networkx chardet && python -c "import os, gdown, zipfile; downloads = {'rag_theory': os.environ.get('RAG_DRIVE_LINK'), 'rag_code': os.environ.get('CODEBASE_RAG_DRIVE_LINK'), 'rag_mql5': os.environ.get('MQL5_RAG_DRIVE_LINK')}; [ (print(f'Letoltes: {k}...'), gdown.download(v, f'{k}.zip', quiet=False, fuzzy=True), print(f'Kicsomagolas: {k}...'), os.makedirs(k, exist_ok=True), zipfile.ZipFile(f'{k}.zip', 'r').extractall(k), os.remove(f'{k}.zip')) for k, v in downloads.items() if v ];" && cat << 'EOF' > kutato.py
#!/usr/bin/env python
import sys, json, faiss, numpy as np, os, re, argparse
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
    # A 'rag_mql5' mappa is bekerult a keresesi utvonalak koze
    search_roots = ['rag_theory', 'rag_code', 'rag_mql5']
    for root_dir in search_roots:
        if not os.path.exists(root_dir): continue
        for root, dirs, files in os.walk(root_dir):
            for file in files:
                if file.endswith('_adatok.json') or file.endswith('.json'):
                    try:
                        with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                            chunk = json.load(f)
                            # Tipus meghatarozasa a mappa alapjan
                            stype = 'ELMELET'
                            if 'code' in root_dir: stype = 'KOD'
                            elif 'mql5' in root_dir: stype = 'MQL5_DEV'

                            for d in chunk:
                                d['source_type'] = stype
                                d['origin_file'] = file
                                d['final_filename'] = d.get('filename') or d.get('source') or '?'
                                docs.append(d)
                    except: pass
    if not docs: print("HIBA: Ures adatbazis!"); sys.exit(1)

    # A kivalasztott modell betoltese
    model_name = MODELS.get(model_key, MODELS['mpnet'])
    model = SentenceTransformer(model_name)
    return docs, model

def hybrid_search(query, docs, model):
    corpus = [(d.get('search_content') or d.get('content') or '').lower().split() for d in docs]
    bm25 = BM25Okapi(corpus)
    scores = bm25.get_scores(query.lower().split())
    cand_idx = np.argsort(scores)[::-1][:50]
    candidates = [docs[i] for i in cand_idx if scores[i] > 0]
    if not candidates: candidates = docs[:100]

    q_vec = model.encode([query])
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

    # Probaljuk sorba rendezni a 'part' mezo alapjan
    try: parts.sort(key=lambda x: int(x.get('part', 0)))
    except: pass

    print(f"\n=== FAJL TARTALMA: {parts[0]['final_filename']} ({len(parts)} darab) ===\n")
    for p in parts:
        print(p.get('content', ''))
    print("\n=== VEGE ===\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['search', 'read'], help='Muvelet')
    parser.add_argument('query', nargs='+', help='Keresoszo vagy fajlnev')
    # Uj argumentum a modell kivalasztasahoz
    parser.add_argument('--model', choices=['mpnet', 'minilm'], default='mpnet', help='Hasznalt embedding modell (mpnet vagy minilm)')
    args = parser.parse_args()

    q = ' '.join(args.query)
    docs, model = load_resources(args.model)

    if args.action == 'read':
        read_file_stitching(q, docs)
        return

    print(f"   [AGY]: Kereses: '{q}'")
    hits = hybrid_search(q, docs, model)

    print(f"\nTALALATOK:")
    for i, h in enumerate(hits):
        d = h['doc']
        print(f"\n[{d['source_type']} | {d['final_filename']}] (Score: {h['score']:.2f})")
        print("-" * 60)
        print((d.get('content') or '')[:1500] + "...")

if __name__ == "__main__":
    main()
EOF
echo "kutato.py" >> .git/info/exclude && echo "rag_theory" >> .git/info/exclude && echo "rag_code" >> .git/info/exclude && echo "rag_mql5" >> .git/info/exclude && echo "INSTRUCTIONS.md" >> .git/info/exclude
