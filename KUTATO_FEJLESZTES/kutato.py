#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 2.3 (Debug Paths)
import sys
import json
import os
import argparse
import sqlite3
import re
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer

# --- CONFIGURATION ---
RAG_SCOPES = ['MQL5_DEV', 'THEORY', 'CODE', 'COLUMBO', 'THIEFS']

# RAG Directory Configuration
RAG_MQL5_DIR = 'rag_mql5_dev'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

# JSONL Reference Paths
THIEFS_JSONL = os.path.join("Knowledge_Base", "knowledge_base_thiefs_library.jsonl")
COLUMBO_JSONL = os.path.join("Knowledge_Base", "knowledge_base_columbo.jsonl")

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code

TOP_K = 5

class RAGSearcher:
    def __init__(self):
        self.models = {}
        self.indexes = {}
        self.conns = {} # SQLite connections
        self.jsonl_data = {} # In-memory cache for JSONL files

        self._load_mql5()
        self._load_theory()
        self._load_code()
        # JSONL files are loaded on demand to save memory/startup time

    def _get_model(self, model_name):
        if model_name not in self.models:
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _clean_text(self, text):
        if not text: return ""
        text = re.sub(r'§[A-Z0-9]+§', '', text)
        text = re.sub(r'\s+', ' ', text).strip()
        return text

    def _load_idx(self, key, directory, db_filename, index_filename):
        idx_path = os.path.join(directory, index_filename)
        db_path = os.path.join(directory, db_filename)

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes[key] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.conns[key] = sqlite3.connect(db_path, check_same_thread=False)
                self.conns[key].row_factory = sqlite3.Row
                # sys.stderr.write(f"[DEBUG] Loaded {key} from {idx_path}\n")
            except Exception as e:
                sys.stderr.write(f"[ERROR] {key} load failed: {e}\n")
        else:
             sys.stderr.write(f"[WARN] Missing {idx_path} or {db_path} for {key}\n")
             pass

    def _load_mql5(self):
        self._load_idx('mql5', RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase.db', 'MQL5_DEV_knowledgebase_compressed.index')

    def _load_theory(self):
        self._load_idx('theory', RAG_THEORY_DIR, 'theory_knowledgebase.db', 'theory_compressed.index')

    def _load_code(self):
        self._load_idx('code', RAG_CODE_DIR, 'code_knowledgebase.db', 'code_compressed.index')

    def _search_rag_generic(self, query, scope_key, model_name, source_type, top_k=TOP_K):
        if scope_key not in self.indexes or scope_key not in self.conns:
            sys.stderr.write(f"[WARN] Scope {scope_key} not loaded, skipping search.\n")
            return []

        model = self._get_model(model_name)
        q_vec = model.encode([query])
        D, I = self.indexes[scope_key].search(q_vec, top_k)

        results = []
        cursor = self.conns[scope_key].cursor()

        # Dynamic table finding
        table_name = 'articles'
        try:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            if tables:
                table_name = tables[0]['name']
        except: pass

        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            try:
                cursor.execute(f"SELECT * FROM {table_name} WHERE id = ?", (int(idx),))
                row = cursor.fetchone()
                if row:
                    fname = row['filename'] if 'filename' in row.keys() else '?'
                    raw_content = ''
                    if 'content' in row.keys() and row['content']: raw_content = row['content']
                    elif 'code' in row.keys() and row['code']: raw_content = row['code']

                    results.append({
                        'source_type': source_type,
                        'filename': fname,
                        'content': self._clean_text(raw_content),
                        'score': float(1 / (1 + D[0][j]))
                    })
            except: pass
        return results

    def _search_jsonl(self, query, filepath, source_type, top_k=TOP_K):
        if not os.path.exists(filepath):
            sys.stderr.write(f"[WARN] JSONL file not found: {filepath}\n")
            return []

        # Simple keyword/regex search for now (could be upgraded to vector search if embeddings existed)
        query_terms = query.lower().split()
        hits = []

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                for line in f:
                    try:
                        doc = json.loads(line)
                        content = doc.get('content', '') or doc.get('code', '')
                        content_lower = content.lower()

                        # Basic scoring: count term matches
                        score = 0
                        for term in query_terms:
                            if term in content_lower:
                                score += 1

                        if score > 0:
                            hits.append({
                                'source_type': source_type,
                                'filename': doc.get('filename', '?'),
                                'content': self._clean_text(content),
                                'score': score
                            })
                    except: pass
        except Exception as e:
             sys.stderr.write(f"[ERROR] Reading {filepath}: {e}\n")

        # Sort by score descending
        hits.sort(key=lambda x: x['score'], reverse=True)

        # Normalize scores to 0-1 range for consistency with FAISS (heuristic)
        max_score = hits[0]['score'] if hits else 1
        for h in hits:
            h['score'] = min(0.99, h['score'] / (max_score + 1)) # Simple normalization

        return hits[:top_k]


    def search(self, query, scope='MQL5_DEV'):
        if scope == 'MQL5_DEV':
            return self._search_rag_generic(query, 'mql5', MODEL_MINILM, 'MQL5_DEV')
        elif scope == 'THEORY':
            return self._search_rag_generic(query, 'theory', MODEL_MPNET, 'THEORY')
        elif scope == 'CODE':
            return self._search_rag_generic(query, 'code', MODEL_MPNET, 'CODE')
        elif scope == 'COLUMBO':
            return self._search_jsonl(query, COLUMBO_JSONL, 'COLUMBO')
        elif scope == 'THIEFS':
            return self._search_jsonl(query, THIEFS_JSONL, 'THIEFS')
        else:
            return []

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('query', nargs='+', help='Query string')
    parser.add_argument('--scope', required=True, choices=RAG_SCOPES, help='Search scope')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    args = parser.parse_args()

    query = ' '.join(args.query)
    searcher = RAGSearcher()
    hits = searcher.search(query, scope=args.scope)

    if args.json:
        print(json.dumps(hits, indent=2))
    else:
        print(f"--- Results for '{query}' in {args.scope} ---")
        for h in hits:
            print(f"[{h['source_type']}] {h['filename']} (Score: {h['score']:.2f})")
            print("-" * 60)
            print((h['content'][:500] + '...'))
            print("\n")

if __name__ == "__main__":
    main()
