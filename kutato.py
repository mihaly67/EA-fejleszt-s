#!/usr/bin/env python
import sys, json, faiss, numpy as np, os, re, argparse
from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi

# --- KONFIGURACIO ---
MODEL_NAME = 'all-mpnet-base-v2'
TOP_K_INITIAL = 20
TOP_K_FINAL = 5
CONTEXT_WINDOW = 1500

class WorkerAgent:
    def __init__(self):
        self.docs = []
        self.model = None
        self.index = None
        self.bm25 = None
        self.corpus = []
        self.loaded = False

    def load_resources(self):
        if self.loaded: return
        # print("   [MUNKAS]: Memoria betoltese...", file=sys.stderr)

        # Modositva: ideiglenes konyvtar hasznalata a sandbox korlatok miatt
        search_roots = ['/tmp/rag_theory', '/tmp/rag_code', '/tmp/new_knowledge', 'rag_theory', 'rag_code']
        raw_docs = []

        for root_dir in search_roots:
            if not os.path.exists(root_dir): continue
            for root, dirs, files in os.walk(root_dir):
                for file in files:
                    if file.endswith('_adatok.json') or file.endswith('.json'):
                        try:
                            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                                chunk = json.load(f)
                                stype = 'ELMELET' if 'theory' in root_dir else 'KOD'
                                for d in chunk:
                                    d['source_type'] = stype
                                    d['origin_file'] = file
                                    d['final_filename'] = d.get('filename') or d.get('source') or '?'
                                    content = d.get('search_content') or d.get('content') or ''
                                    d['clean_content'] = content
                                    raw_docs.append(d)
                        except: pass

        if not raw_docs:
            print(json.dumps({"error": "Ures adatbazis"})); sys.exit(1)

        self.docs = raw_docs
        self.model = SentenceTransformer(MODEL_NAME)
        self.corpus = [d['clean_content'].lower().split() for d in self.docs]
        self.bm25 = BM25Okapi(self.corpus)
        self.loaded = True

    def search(self, query, scope=None, depth=0):
        if not self.loaded: self.load_resources()
        hits = self._hybrid_search(query, scope, limit=TOP_K_INITIAL)
        final_results = hits

        if depth > 0 and hits:
            best_doc = hits[0]['doc']
            new_query = f"{query} {best_doc.get('final_filename', '')}"
            sub_hits = self._hybrid_search(new_query, scope, limit=TOP_K_INITIAL)
            seen_ids = {h['doc'].get('content')[:50] for h in final_results}
            for h in sub_hits:
                if h['doc'].get('content')[:50] not in seen_ids:
                    final_results.append(h)

        final_results.sort(key=lambda x: x['score'], reverse=True)
        return final_results[:TOP_K_FINAL]

    def _hybrid_search(self, query, scope, limit=10):
        active_docs_idx = []
        if scope:
            active_docs_idx = [i for i, d in enumerate(self.docs) if d['source_type'] == scope]
        else:
            active_docs_idx = list(range(len(self.docs)))

        if not active_docs_idx: return []

        tokenized_query = query.lower().split()
        bm25_scores = self.bm25.get_scores(tokenized_query)
        # Optimalizalas: Csak az elso 50 talalatot vektorizaljuk a sebesseg erdekeben
        top_n_indices = np.argsort(bm25_scores)[::-1][:min(50, len(bm25_scores))]
        candidates_idx = [i for i in top_n_indices if i in active_docs_idx]

        if not candidates_idx: return []

        candidate_docs = [self.docs[i] for i in candidates_idx]
        candidate_txts = [d['clean_content'] for d in candidate_docs]

        query_vec = self.model.encode([query])
        doc_vecs = self.model.encode(candidate_txts)

        from sklearn.metrics.pairwise import cosine_similarity
        sims = cosine_similarity(query_vec, doc_vecs)[0]

        results = []
        for i, score in enumerate(sims):
            results.append({
                'doc': candidate_docs[i],
                'score': float(score),
                'query': query
            })
        return results

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--query', required=True, help='Keresesi kifejezes')
    parser.add_argument('--scope', choices=['ELMELET', 'KOD'], help='Szures: ELMELET vagy KOD')
    parser.add_argument('--depth', type=int, default=0, help='Keresesi melyseg')
    parser.add_argument('--output', choices=['json', 'text'], default='text')
    args = parser.parse_args()

    agent = WorkerAgent()
    results = agent.search(args.query, args.scope, args.depth)

    if args.output == 'json':
        clean_results = []
        for r in results:
            d = r['doc']
            clean_results.append({
                'filename': d['final_filename'],
                'type': d['source_type'],
                'score': r['score'],
                'content': (d.get('content') or '')[:CONTEXT_WINDOW]
            })
        print(json.dumps(clean_results, indent=2))
    else:
        print(f"=== KERESES: '{args.query}' (Scope: {args.scope or 'ALL'}, Depth: {args.depth}) ===\n")
        for r in results:
            d = r['doc']
            print(f"[{d['source_type']}] {d['final_filename']} (Score: {r['score']:.2f})")
            print("-" * 40)
            print((d.get('content') or '')[:500] + "...")
            print("\n")

if __name__ == "__main__":
    main()
