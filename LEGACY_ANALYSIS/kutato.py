#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 2.0 (Standardized RAG Scope & JSONL)
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
# Standardized RAG Scope Names (Reference: rag_jsonl_test.py)
RAG_SCOPES = ['MQL5_DEV', 'THEORY', 'CODE']

# RAG Directory Configuration
RAG_MQL5_DIR = 'rag_mql5_dev'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

# JSONL Reference Paths (Required for compliance with rag_jsonl_test.py)
GITHUB_JSONL = os.path.join("github_codebase", "knowledge_base_github.jsonl")
MT_LIBS_JSONL = os.path.join("Knowledge_Base", "knowledge_base_mt_libs.jsonl")
LAYERING_JSONL = "knowledge_base_indicator_layering.jsonl"

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code

TOP_K = 5

class RAGSearcher:
    def __init__(self):
        self.models = {}
        self.indexes = {}
        self.conns = {} # SQLite connections: 'mql5', 'theory', 'code'

        self._load_mql5()
        self._load_theory()
        self._load_code()

    def _get_model(self, model_name):
        if model_name not in self.models:
            # Silence verbose output
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _clean_text(self, text):
        """Removes formatting artifacts."""
        if not text: return ""
        # Remove custom markers like §H2§, §B§, etc.
        text = re.sub(r'§[A-Z0-9]+§', '', text)
        # Remove excess whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        return text

    def _load_mql5(self):
        """MQL5 Dev: Disk-based SQLite + MMAP Index (MiniLM)"""
        idx_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase_compressed.index')
        db_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase.db')

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes['mql5'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.conns['mql5'] = sqlite3.connect(db_path, check_same_thread=False)
                self.conns['mql5'].row_factory = sqlite3.Row
            except Exception as e:
                sys.stderr.write(f"[ERROR] MQL5 load failed: {e}\n")

    def _load_theory(self):
        """Theory: Disk-based SQLite + MMAP Index (MPNet)"""
        idx_path = os.path.join(RAG_THEORY_DIR, 'theory_compressed.index')
        db_path = os.path.join(RAG_THEORY_DIR, 'theory_knowledgebase.db')

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes['theory'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.conns['theory'] = sqlite3.connect(db_path, check_same_thread=False)
                self.conns['theory'].row_factory = sqlite3.Row
            except Exception as e:
                sys.stderr.write(f"[ERROR] Theory load failed: {e}\n")

    def _load_code(self):
        """Code: Disk-based SQLite + MMAP Index (MPNet)"""
        idx_path = os.path.join(RAG_CODE_DIR, 'code_compressed.index')
        db_path = os.path.join(RAG_CODE_DIR, 'code_knowledgebase.db')

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes['code'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.conns['code'] = sqlite3.connect(db_path, check_same_thread=False)
                self.conns['code'].row_factory = sqlite3.Row
            except Exception as e:
                sys.stderr.write(f"[ERROR] Code load failed: {e}\n")

    def _search_generic(self, query, scope_key, model_name, source_type, top_k=TOP_K):
        if scope_key not in self.indexes or scope_key not in self.conns:
            return []

        model = self._get_model(model_name)
        q_vec = model.encode([query])
        D, I = self.indexes[scope_key].search(q_vec, top_k)

        results = []
        cursor = self.conns[scope_key].cursor()

        # Determine table name dynamically if possible, or fallback to standard 'articles'
        table_name = 'articles'

        for j, idx in enumerate(I[0]):
            if idx == -1: continue

            try:
                cursor.execute(f"SELECT * FROM {table_name} WHERE id = ?", (int(idx),))
            except sqlite3.OperationalError:
                # Fallback: find table name
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                tables = cursor.fetchall()
                if tables:
                    table_name = tables[0]['name']
                    cursor.execute(f"SELECT * FROM {table_name} WHERE id = ?", (int(idx),))
                else:
                    continue

            row = cursor.fetchone()
            if row:
                # normalize keys
                fname = row['filename'] if 'filename' in row.keys() else '?'
                # Content prioritization: content > code > nothing
                raw_content = ''
                if 'content' in row.keys() and row['content']:
                    raw_content = row['content']
                elif 'code' in row.keys() and row['code']:
                    raw_content = row['code']

                clean_content = self._clean_text(raw_content)

                res = {
                    'source_type': source_type,
                    'filename': fname,
                    'content': clean_content,
                    'score': float(1 / (1 + D[0][j]))
                }
                results.append(res)

        return results

    def search(self, query, scope='MQL5_DEV'):
        results = []

        if scope == 'MQL5_DEV':
            results = self._search_generic(query, 'mql5', MODEL_MINILM, 'MQL5_DEV')
        elif scope == 'THEORY':
            results = self._search_generic(query, 'theory', MODEL_MPNET, 'THEORY')
        elif scope == 'CODE':
            results = self._search_generic(query, 'code', MODEL_MPNET, 'CODE')
        else:
            # Invalid scope
            pass

        return results

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
        for h in hits:
            print(f"[{h['source_type']}] {h['filename']} (Score: {h['score']:.2f})")
            print("-" * 60)
            print((h['content'][:500] + '...'))
            print("\n")

if __name__ == "__main__":
    main()
