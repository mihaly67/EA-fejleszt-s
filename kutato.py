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

# --- CONFIGURATION ---
RAG_MQL5_DIR = 'rag_mql5_dev'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code

TOP_K = 5

class RAGSearcher:
    def __init__(self):
        self.models = {}
        self.indexes = {}
        self.mql5_conn = None

        # Data Containers
        self.theory_docs = [] # In-Memory List
        self.code_conn = None # Disk-based SQLite

        self._load_mql5()
        self._load_theory()
        self._load_code()

    def _get_model(self, model_name):
        if model_name not in self.models:
            # Silence verbose output during tool calls unless error
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _load_mql5(self):
        """MQL5 Dev: Disk-based SQLite + MMAP Index (MiniLM)"""
        idx_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase_compressed.index')
        db_path = os.path.join(RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase.db')

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes['mql5'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.mql5_conn = sqlite3.connect(db_path, check_same_thread=False)
                self.mql5_conn.row_factory = sqlite3.Row
            except Exception as e:
                sys.stderr.write(f"[ERROR] MQL5 load failed: {e}\n")

    def _load_theory(self):
        """Theory: In-Memory List + MMAP Index (MPNet)"""
        # Index
        idx_path = os.path.join(RAG_THEORY_DIR, 'theory_compressed.index')
        if os.path.exists(idx_path):
            self.indexes['theory'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)

        # Content (Load all into RAM)
        db_path = os.path.join(RAG_THEORY_DIR, 'theory_knowledgebase.db')
        if os.path.exists(db_path):
            try:
                conn = sqlite3.connect(db_path)
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                # Assuming schema: id, filename, content...
                # We load EVERYTHING into self.theory_docs list to mirror FAISS ID order.
                # Crucial: FAISS IDs usually 0..N. We must select by ID ASC.
                cursor.execute("SELECT * FROM theory ORDER BY id ASC")
                # Note: Table name might be 'knowledgebase' or 'theory'. Need to check schema?
                # Fallback check if table name unknown.
                try:
                    cursor.execute("SELECT * FROM knowledgebase ORDER BY id ASC")
                except:
                    # Try 'articles'? Or just list tables?
                    # Let's try generic fallback
                    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                    tables = cursor.fetchall()
                    if tables:
                        tname = tables[0][0]
                        cursor.execute(f"SELECT * FROM {tname} ORDER BY id ASC")

                rows = cursor.fetchall()
                # Convert to list of dicts
                self.theory_docs = [dict(r) for r in rows]
                conn.close()
            except Exception as e:
                # sys.stderr.write(f"[ERROR] Theory load failed: {e}\n")
                pass

    def _load_code(self):
        """Code: Disk-based SQLite + MMAP Index (MPNet)"""
        idx_path = os.path.join(RAG_CODE_DIR, 'code_compressed.index')
        db_path = os.path.join(RAG_CODE_DIR, 'code_knowledgebase.db')

        if os.path.exists(idx_path) and os.path.exists(db_path):
            try:
                self.indexes['code'] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                self.code_conn = sqlite3.connect(db_path, check_same_thread=False)
                self.code_conn.row_factory = sqlite3.Row
            except Exception as e:
                sys.stderr.write(f"[ERROR] Code load failed: {e}\n")

    def search_mql5(self, query, top_k=TOP_K):
        if 'mql5' not in self.indexes or not self.mql5_conn: return []

        model = self._get_model(MODEL_MINILM)
        q_vec = model.encode([query])
        D, I = self.indexes['mql5'].search(q_vec, top_k)

        results = []
        cursor = self.mql5_conn.cursor()
        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            cursor.execute("SELECT * FROM articles WHERE id = ?", (int(idx),))
            row = cursor.fetchone()
            if row:
                res = {
                    'source_type': 'MQL5_DEV',
                    'filename': row['filename'],
                    'content': row['content'] or row['code'] or '',
                    'score': float(1 / (1 + D[0][j]))
                }
                results.append(res)
        return results

    def search_theory(self, query, top_k=TOP_K):
        if 'theory' not in self.indexes or not self.theory_docs: return []

        model = self._get_model(MODEL_MPNET)
        q_vec = model.encode([query])
        D, I = self.indexes['theory'].search(q_vec, top_k)

        results = []
        for j, idx in enumerate(I[0]):
            if idx == -1 or idx >= len(self.theory_docs): continue
            doc = self.theory_docs[int(idx)]
            res = {
                'source_type': 'THEORY',
                'filename': doc.get('filename', '?'),
                'content': doc.get('content', ''),
                'score': float(1 / (1 + D[0][j]))
            }
            results.append(res)
        return results

    def search_code(self, query, top_k=TOP_K):
        if 'code' not in self.indexes or not self.code_conn: return []

        model = self._get_model(MODEL_MPNET)
        q_vec = model.encode([query])
        D, I = self.indexes['code'].search(q_vec, top_k)

        results = []
        cursor = self.code_conn.cursor()
        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            # Query by ID. Assuming table name 'code_snippets' or similar.
            # We'll inspect tables if needed, but assuming standard 'knowledgebase' or 'code' from previous knowledge.
            # Usually schema is: id, filename, code...
            # Let's try generic selection if table name varies.
            try:
                cursor.execute("SELECT * FROM code_snippets WHERE id = ?", (int(idx),))
            except:
                try:
                    cursor.execute("SELECT * FROM knowledgebase WHERE id = ?", (int(idx),))
                except:
                    # Fallback
                    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
                    tname = cursor.fetchone()[0]
                    cursor.execute(f"SELECT * FROM {tname} WHERE id = ?", (int(idx),))

            row = cursor.fetchone()
            if row:
                res = {
                    'source_type': 'CODE',
                    'filename': row['filename'],
                    'content': row['code'] or row['content'] or '', # Usually 'code' column
                    'score': float(1 / (1 + D[0][j]))
                }
                results.append(res)
        return results

    def search(self, query, scope='ALL'):
        results = []

        if scope in ['ALL', 'MQL5']:
            results.extend(self.search_mql5(query))

        if scope in ['ALL', 'LEGACY', 'THEORY']:
            results.extend(self.search_theory(query))

        if scope in ['ALL', 'LEGACY', 'CODE']:
            results.extend(self.search_code(query))

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
        for h in hits:
            print(f"[{h['source_type']}] {h['filename']} (Score: {h['score']:.2f})")
            print("-" * 60)
            print((h['content'][:500] + '...').replace('\n', ' '))
            print("\n")

if __name__ == "__main__":
    main()
