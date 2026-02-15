#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.0 (RAG Adapter - Full Context Retrieval)
import sys
import json
import sqlite3
import os
import faiss
from sentence_transformers import SentenceTransformer

# --- CONFIGURATION ---
# Assumes we are in KUTATO_FEJLESZTES/KutatoIntezet, so go up two levels to root
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

            # Identify DB and Index files
            # Naming convention varies: MQL5_DEV_knowledgebase.db vs theory_knowledgebase.db
            prefix = ""
            if scope == 'MQL5_DEV': prefix = "MQL5_DEV_knowledgebase"
            elif scope == 'THEORY': prefix = "theory_knowledgebase"
            elif scope == 'CODE': prefix = "code_knowledgebase"

            db_path = os.path.join(directory, f"{prefix}.db")
            idx_path = os.path.join(directory, f"{prefix}_compressed.index")

            if os.path.exists(db_path) and os.path.exists(idx_path):
                try:
                    self.indexes[scope] = faiss.read_index(idx_path, faiss.IO_FLAG_MMAP)
                    self.conns[scope] = sqlite3.connect(db_path, check_same_thread=False)
                    self.conns[scope].row_factory = sqlite3.Row
                except Exception as e:
                    print(f"Error loading {scope}: {e}")

    def search_full(self, query, scope, top_k=5):
        """Searches RAG and reconstructs FULL context using embedded metadata."""
        if scope not in self.indexes or scope not in self.conns:
            return []

        model_name = MODELS.get(scope, 'all-MiniLM-L6-v2')
        model = self._get_model(model_name)

        vec = model.encode([query])
        D, I = self.indexes[scope].search(vec, top_k)

        results = []
        cursor = self.conns[scope].cursor()

        # Determine table name
        table = 'articles'
        try:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            if tables: table = tables[0]['name']
        except: pass

        seen_contexts = set()

        for j, idx in enumerate(I[0]):
            if idx == -1: continue

            try:
                # 1. Get the Initial Chunk
                cursor.execute(f"SELECT * FROM {table} WHERE id=?", (int(idx),))
                row = cursor.fetchone()
                if not row: continue

                raw_text = row['content'] or row['code'] or ""
                filename = row['filename'] if 'filename' in row.keys() else 'unknown'

                # 2. Extract Context ID (The "Series: ... Title: ..." part)
                # Look for "// CONTEXT: ... \n"
                import re
                context_match = re.search(r'// CONTEXT: (.*?)\n', raw_text)

                context_id = None
                if context_match:
                    context_id = context_match.group(1).strip()
                else:
                    # Fallback: Use filename if no context found
                    context_id = filename

                if context_id in seen_contexts: continue
                seen_contexts.add(context_id)

                # 3. Retrieve ALL chunks sharing this Context
                # If we have a robust context string, we use LIKE to find peers
                full_content = ""

                if context_match:
                    # Escape special chars for SQL LIKE if needed, but simple string usually works
                    # Note: This might be slow if DB is huge and not indexed by content.
                    # Optimization: Limit to e.g. 50 chunks max to avoid hanging.
                    try:
                        # Use parameterized query for safety.
                        # We look for chunks containing the same context header.
                        # Note: This assumes the context header is unique enough.
                        like_query = f"%// CONTEXT: {context_id}%"
                        cursor.execute(f"SELECT content, code, filename FROM {table} WHERE content LIKE ? OR code LIKE ? LIMIT 100", (like_query, like_query))
                        peer_chunks = cursor.fetchall()

                        # Organize by file?
                        file_contents = {}
                        for pc in peer_chunks:
                            c_text = pc['content'] or pc['code'] or ""
                            c_fname = pc['filename']
                            if c_fname not in file_contents: file_contents[c_fname] = []
                            file_contents[c_fname].append(c_text)

                        # Assemble
                        for fname, chunks in file_contents.items():
                            full_content += f"\n--- FILE: {fname} ---\n"
                            full_content += "\n".join(chunks)

                    except Exception as e:
                        print(f"Context retrieval failed: {e}")
                        full_content = raw_text # Fallback
                else:
                    # Fallback: Fetch by filename
                    if 'filename' in row.keys():
                        cursor.execute(f"SELECT content, code FROM {table} WHERE filename=? LIMIT 50", (filename,))
                        all_chunks = cursor.fetchall()
                        for chunk in all_chunks:
                            c_text = chunk['content'] or chunk['code'] or ""
                            full_content += c_text + "\n\n"
                    else:
                        full_content = raw_text

                results.append({
                    'source_type': scope,
                    'filename': context_id, # Use context as the "Document Name"
                    'content': full_content,
                    'score': float(1/(1+D[0][j]))
                })

            except Exception as e:
                print(f"Error retrieving {idx} in {scope}: {e}")

        return results

if __name__ == "__main__":
    # Test
    adapter = RAGAdapter()
    hits = adapter.search_full("indicator handle", "MQL5_DEV", top_k=3)
    print(json.dumps(hits, indent=2))
