#!/usr/bin/env python
# -*- coding: utf-8 -*-
# kutato_v3_adapter.py (Deep Search Logic)
import sys
import json
import os
import argparse
import sqlite3
import re
import faiss
from sentence_transformers import SentenceTransformer

# --- CONFIGURATION ---
RAG_MQL5_DIR = 'rag_mql5_dev'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code

TOP_K = 5

class DeepResearcher:
    def __init__(self):
        self.models = {}
        self.indexes = {}
        self.conns = {}
        self._load_resources()

    def _get_model(self, model_name):
        if model_name not in self.models:
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _load_resources(self):
        # MQL5
        self._load_idx('mql5', RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase')
        # Theory
        self._load_idx('theory', RAG_THEORY_DIR, 'theory_knowledgebase')
        # Code
        self._load_idx('code', RAG_CODE_DIR, 'code_knowledgebase')

    def _load_idx(self, key, directory, prefix):
        idx_path = os.path.join(directory, f'{prefix}_compressed.index')
        db_path = os.path.join(directory, f'{prefix}.db')
        if os.path.exists(idx_path) and os.path.exists(db_path):
            self.indexes[key] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
            self.conns[key] = sqlite3.connect(db_path, check_same_thread=False)
            self.conns[key].row_factory = sqlite3.Row

    def search(self, query):
        results = []
        # Search all scopes
        results.extend(self._search_scope(query, 'mql5', MODEL_MINILM))
        results.extend(self._search_scope(query, 'theory', MODEL_MPNET))
        results.extend(self._search_scope(query, 'code', MODEL_MPNET))

        # Sort by score
        results.sort(key=lambda x: x['score'], reverse=True)
        return results[:10] # Top 10 global

    def _search_scope(self, query, key, model_name):
        if key not in self.indexes: return []

        model = self._get_model(model_name)
        vec = model.encode([query])
        D, I = self.indexes[key].search(vec, TOP_K)

        res = []
        cursor = self.conns[key].cursor()

        # Dynamic table detection
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        table = tables[0]['name'] if tables else 'articles'

        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            cursor.execute(f"SELECT * FROM {table} WHERE id=?", (int(idx),))
            row = cursor.fetchone()
            if row:
                content = row['content'] if 'content' in row.keys() else (row['code'] if 'code' in row.keys() else '')
                res.append({
                    'scope': key,
                    'file': row['filename'] if 'filename' in row.keys() else '?',
                    'content': content[:500], # Snippet
                    'score': float(1/(1+D[0][j]))
                })
        return res

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("query", nargs="+")
    args = parser.parse_args()

    researcher = DeepResearcher()
    hits = researcher.search(" ".join(args.query))
    print(json.dumps(hits, indent=2))
