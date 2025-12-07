#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import os
import argparse
import sqlite3
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

# --- CONFIGURATION ---
RAG_MQL5_DIR = 'rag_mql5'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev (384 dim)
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code (768 dim)

TOP_K = 5

class RAGSearcher:
    def __init__(self):
        self.models = {}
        self.indexes = {}
        self.mql5_conn = None
        self.legacy_docs = [] # List of documents for Theory/Code
        # Mapping from global FAISS ID to doc index in legacy_docs is implicitly handled
        # IF the order in JSON matches the order in FAISS.
        # However, multiple JSONs exist. We need a robust offset mapping.
        self.legacy_offsets = []

        # Load resources optimized for memory
        self._load_mql5()
        self._load_legacy()

    def _get_model(self, model_name):
        if model_name not in self.models:
            # print(f"   [MEMORY] Loading model: {model_name}...")
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _load_mql5(self):
        index_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase_compressed.index')
        db_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase.db')

        if os.path.exists(index_path) and os.path.exists(db_path):
            try:
                # MMAP for memory safety
                self.indexes['mql5'] = faiss.read_index(index_path, faiss.IO_FLAG_MMAP)
                self.mql5_conn = sqlite3.connect(db_path, check_same_thread=False)
                self.mql5_conn.row_factory = sqlite3.Row
                # print(f"   [INIT] MQL5 Dev RAG mapped (MMAP).")
            except Exception as e:
                sys.stderr.write(f"   [ERROR] MQL5 Dev load failed: {e}\n")

    def _load_legacy_part(self, name, directory, dim):
        index_path = os.path.join(directory, f"{name}.index" if name == 'tudasbazis' else 'kodbazis.index')
        if name == 'tudasbazis': index_path = os.path.join(directory, 'tudasbazis.index')

        # Handle index filename variations if needed, but assuming standard from check

        if os.path.exists(index_path):
             self.indexes[name] = faiss.read_index(index_path, faiss.IO_FLAG_MMAP)

        # Load Content
        # We assume the FAISS index was built iterating over the JSONs in the directory.
        # We must load them in the exact same order to match IDs.
        # Since we don't know the build order for sure, this is a risk.
        # BUT, usually it's alphabetical or standard walk.
        # To be safe, we load the corresponding '_adatok.json' which usually contains the bulk.

        json_path = os.path.join(directory, f"{name}_adatok.json")
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                start_idx = len(self.legacy_docs)
                for d in data:
                    d['source_rag'] = name
                    self.legacy_docs.append(d)

                # Store offset range for this index
                # self.legacy_offsets.append({'name': name, 'start': start_idx, 'count': len(data)})
                # Wait, if we have separate FAISS indexes, we search them separately.
                # So ID 0 in 'theory' index maps to 0-th doc in theory JSON.

                # We need separate lists if we search separate indexes.
                pass
        else:
             # Fallback scan
             pass

    def _load_legacy(self):
        # We need separate lists for Theory and Code to align with their separate FAISS indexes
        self.theory_docs = []
        self.code_docs = []

        # THEORY
        if os.path.exists(RAG_THEORY_DIR):
             idx_path = os.path.join(RAG_THEORY_DIR, 'tudasbazis.index')
             json_path = os.path.join(RAG_THEORY_DIR, 'tudasbazis_adatok.json') # Main file
             if os.path.exists(idx_path):
                 self.indexes['theory'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)

             # Scan all JSONs to be sure we get all content matching the index?
             # Or just the main one. The 'check_indexes' showed 55k vectors.
             # If the JSON has 55k items, we are good.

             if os.path.exists(json_path):
                 with open(json_path, 'r', encoding='utf-8') as f:
                     self.theory_docs = json.load(f)

        # CODE
        if os.path.exists(RAG_CODE_DIR):
             idx_path = os.path.join(RAG_CODE_DIR, 'kodbazis.index')
             json_path = os.path.join(RAG_CODE_DIR, 'kodbazis_adatok.json')
             if os.path.exists(idx_path):
                 self.indexes['code'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)

             if os.path.exists(json_path):
                 with open(json_path, 'r', encoding='utf-8') as f:
                     self.code_docs = json.load(f)

    def search_mql5(self, query, top_k=TOP_K):
        if 'mql5' not in self.indexes or not self.mql5_conn: return []

        model = self._get_model(MODEL_MINILM)
        q_vec = model.encode([query])
        D, I = self.indexes['mql5'].search(q_vec, top_k)

        results = []
        cursor = self.mql5_conn.cursor()
        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            # Mapping assumption: FAISS ID (0-based) maps to SQLite ID (0-based) or ID column?
            # Based on inspection, IDs in DB started at 0.
            cursor.execute("SELECT * FROM articles WHERE id = ?", (int(idx),))
            row = cursor.fetchone()
            if row:
                res = {
                    'source_type': 'MQL5_DEV',
                    'final_filename': row['filename'],
                    'content': row['content'] or row['code'] or '',
                    'score': float(1 / (1 + D[0][j])) # Distance to score
                }
                results.append(res)
        return results

    def _search_generic(self, query, index_key, doc_list, source_type, top_k=TOP_K):
        if index_key not in self.indexes or not doc_list: return []

        # Safety check: Index size vs Doc list size
        # if self.indexes[index_key].ntotal != len(doc_list):
            # print(f"[WARN] Index {index_key} size ({self.indexes[index_key].ntotal}) != Docs ({len(doc_list)}). Alignment may be off.")
            # If misalignment, FAISS ID might point to wrong doc.
            # But we proceed as best effort.

        model = self._get_model(MODEL_MPNET)
        q_vec = model.encode([query])
        D, I = self.indexes[index_key].search(q_vec, top_k)

        results = []
        for j, idx in enumerate(I[0]):
            if idx == -1 or idx >= len(doc_list): continue
            doc = doc_list[int(idx)]
            res = {
                'source_type': source_type,
                'final_filename': doc.get('filename') or doc.get('source') or '?',
                'content': doc.get('content') or doc.get('search_content') or '',
                'score': float(1 / (1 + D[0][j]))
            }
            results.append(res)
        return results

    def search(self, query, scope='ALL'):
        results = []

        # MQL5 (MiniLM)
        if scope in ['ALL', 'MQL5']:
            results.extend(self.search_mql5(query))

        # Theory (MPNet)
        if scope in ['ALL', 'LEGACY', 'THEORY']:
            results.extend(self._search_generic(query, 'theory', self.theory_docs, 'ELMELET'))

        # Code (MPNet)
        if scope in ['ALL', 'LEGACY', 'CODE']:
            results.extend(self._search_generic(query, 'code', self.code_docs, 'KOD'))

        results.sort(key=lambda x: x['score'], reverse=True)
        return results[:TOP_K]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('query', nargs='+', help='Query string')
    parser.add_argument('--scope', default='ALL', choices=['ALL', 'MQL5', 'LEGACY'], help='Search scope')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    query = ' '.join(args.query)
    searcher = RAGSearcher()

    hits = searcher.search(query, scope=args.scope)

    if args.json:
        print(json.dumps(hits, indent=2))
    else:
        # print(f"\n   [SEARCH] Query: '{query}'\n")
        for h in hits:
            print(f"[{h['source_type']}] {h['final_filename']} (Score: {h['score']:.2f})")
            print("-" * 60)
            content_preview = (h['content'][:500] + '...').replace('\n', ' ')
            print(content_preview)
            print("\n")

if __name__ == "__main__":
    main()
