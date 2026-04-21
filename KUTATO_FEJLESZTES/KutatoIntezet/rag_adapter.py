#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.1 (RAG Adapter - Multi-Strategy Retrieval)
import sys
import json
import sqlite3
import os
import faiss
from sentence_transformers import SentenceTransformer
import re

# --- CONFIGURATION ---
ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

RAG_DIRS = {
    'MQL5_DEV': os.path.join(ROOT_DIR, 'rag_mql5_dev'),
    'THEORY': os.path.join(ROOT_DIR, 'rag_theory'),
    'CODE': os.path.join(ROOT_DIR, 'rag_code')
}

MODELS = {
    'MQL5_DEV': 'all-MiniLM-L6-v2',
    'THEORY': 'all-mpnet-base-v2',
    'CODE': 'all-mpnet-base-v2'
}

class RAGAdapter:
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
        for scope, directory in RAG_DIRS.items():
            if not os.path.exists(directory): continue

            db_filename = ""
            idx_filename = ""

            if scope == 'MQL5_DEV':
                db_filename = "MQL5_DEV_knowledgebase.db"
                idx_filename = "MQL5_DEV_knowledgebase_compressed.index"
            elif scope == 'THEORY':
                db_filename = "theory_knowledgebase.db"
                idx_filename = "theory_compressed.index"
            elif scope == 'CODE':
                db_filename = "code_knowledgebase.db"
                idx_filename = "code_compressed.index"

            db_path = os.path.join(directory, db_filename)
            idx_path = os.path.join(directory, idx_filename)

            if os.path.exists(db_path) and os.path.exists(idx_path):
                try:
                    self.indexes[scope] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                    self.conns[scope] = sqlite3.connect(db_path, check_same_thread=False)
                    self.conns[scope].row_factory = sqlite3.Row
                except Exception as e:
                    print(f"Error loading {scope}: {e}")

    def search_full(self, query, scope, top_k=5):
        """Searches RAG and applies scope-specific reconstruction strategy."""
        if scope not in self.indexes or scope not in self.conns:
            return []

        model_name = MODELS.get(scope, 'all-MiniLM-L6-v2')
        model = self._get_model(model_name)

        vec = model.encode([query])
        D, I = self.indexes[scope].search(vec, top_k)

        # Dispatch based on scope
        if scope == 'THEORY':
            return self._search_theory(scope, D[0], I[0])
        elif scope == 'CODE':
            return self._search_code(scope, D[0], I[0])
        else:
            return self._search_mql5_dev(scope, D[0], I[0])

    def _search_theory(self, scope, distances, indices):
        """Windowed Context Strategy (Hit +/- 2 chunks). Excludes TOC."""
        results = []
        cursor = self.conns[scope].cursor()

        for j, idx in enumerate(indices):
            if idx == -1: continue

            try:
                # Get the hit to identify filename and ID
                cursor.execute("SELECT * FROM articles WHERE id=?", (int(idx),))
                row = cursor.fetchone()
                if not row: continue

                filename = row['filename']
                # TOC Filter
                if filename.endswith('_TOC.txt') or filename.endswith('_TOC.mq5'):
                    continue

                hit_id = int(row['id'])

                # Window: Hit-2 to Hit+2
                start_id = max(0, hit_id - 2)
                end_id = hit_id + 2

                # Fetch window
                cursor.execute("SELECT content FROM articles WHERE filename=? AND id BETWEEN ? AND ? ORDER BY id ASC",
                               (filename, start_id, end_id))
                chunks = cursor.fetchall()

                full_content = f"--- FILE: {filename} (Windowed Context: {start_id}-{end_id}) ---\n\n"
                for c in chunks:
                    full_content += (c['content'] or "") + "\n\n"

                results.append({
                    'source_type': scope,
                    'filename': f"{filename} (Chunk {hit_id})",
                    'content': full_content,
                    'score': float(1/(1+distances[j]))
                })

            except Exception as e:
                print(f"Error in Theory search: {e}")

        return results

    def _search_code(self, scope, distances, indices):
        """Full File Reconstruction Strategy."""
        results = []
        cursor = self.conns[scope].cursor()
        seen_filenames = set()

        for j, idx in enumerate(indices):
            if idx == -1: continue

            try:
                cursor.execute("SELECT filename FROM articles WHERE id=?", (int(idx),))
                row = cursor.fetchone()
                if not row: continue

                filename = row['filename']
                if filename in seen_filenames: continue
                seen_filenames.add(filename)

                # Reconstruct FULL file
                cursor.execute("SELECT content, code FROM articles WHERE filename=? ORDER BY id ASC", (filename,))
                all_chunks = cursor.fetchall()

                full_content = f"--- FILE: {filename} ---\n"
                for c in all_chunks:
                    text = c['content'] or c['code'] or ""
                    full_content += text

                results.append({
                    'source_type': scope,
                    'filename': filename,
                    'content': full_content,
                    'score': float(1/(1+distances[j]))
                })

            except Exception as e:
                print(f"Error in Code search: {e}")

        return results

    def _search_mql5_dev(self, scope, distances, indices):
        """Context ID Strategy (Original)."""
        results = []
        cursor = self.conns[scope].cursor()

        # Determine table name (usually 'articles')
        table = 'articles'

        seen_contexts = set()

        for j, idx in enumerate(indices):
            if idx == -1: continue

            try:
                cursor.execute(f"SELECT * FROM {table} WHERE id=?", (int(idx),))
                row = cursor.fetchone()
                if not row: continue

                raw_text = row['content'] or row['code'] or ""
                filename = row['filename'] if 'filename' in row.keys() else 'unknown'

                # Extract Context ID
                context_match = re.search(r'// CONTEXT: (.*?)\n', raw_text)
                context_id = context_match.group(1).strip() if context_match else filename

                if context_id in seen_contexts: continue
                seen_contexts.add(context_id)

                full_content = ""
                if context_match:
                    try:
                        like_query = f"%// CONTEXT: {context_id}%"
                        cursor.execute(f"SELECT content, code, filename FROM {table} WHERE content LIKE ? OR code LIKE ? LIMIT 100", (like_query, like_query))
                        peer_chunks = cursor.fetchall()

                        file_contents = {}
                        for pc in peer_chunks:
                            c_text = pc['content'] or pc['code'] or ""
                            c_fname = pc['filename']
                            if c_fname not in file_contents: file_contents[c_fname] = []
                            file_contents[c_fname].append(c_text)

                        for fname, chunks in file_contents.items():
                            full_content += f"\n--- FILE: {fname} ---\n"
                            full_content += "\n".join(chunks)
                    except:
                        full_content = raw_text
                else:
                     full_content = raw_text

                results.append({
                    'source_type': scope,
                    'filename': context_id,
                    'content': full_content,
                    'score': float(1/(1+distances[j]))
                })

            except Exception as e:
                print(f"Error in MQL5_DEV search: {e}")

        return results

if __name__ == "__main__":
    # Test
    adapter = RAGAdapter()
    print("Testing MQL5_DEV...")
    hits = adapter.search_full("indicator handle", "MQL5_DEV", top_k=1)
    print(f"Hits: {len(hits)}")
    if hits: print(hits[0]['filename'])
