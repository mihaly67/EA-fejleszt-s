#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Jules Environment Setup Script v251207_1
----------------------------------------
Autonomous bootstrap script to set up the entire development environment.
- Installs dependencies.
- Downloads and extracts RAG knowledge bases (MQL5 Dev, Theory, Code).
- Recreates essential tools (kutato.py, kutato_ugynok_v3.py).
- Ensures directory structure.
"""

import os
import sys
import subprocess
import shutil
import time

# --- CONFIGURATION ---
RAG_LINKS = {
    'rag_mql5': 'https://drive.google.com/uc?id=1luBkNTptLkdJsYs_mHHgRyDwSijgC5NA', # Converted from view?usp to uc?id
    'rag_theory': 'https://drive.google.com/uc?id=1UZgIItTO5a-Kspzdg2MozvqqiF16f3H3',
    'rag_code': 'https://drive.google.com/uc?id=1OM_4ucQj40PvWPRBajC6faMXktCvdRZq'
}

REQUIRED_DIRS = [
    'Factory_System',
    'Knowledge_Base',
    'Browser_Tools',
    'Profit_Management',
    'Showcase_Indicators',
    'rag_mql5',
    'rag_theory',
    'rag_code'
]

DEPENDENCIES = [
    'faiss-cpu',
    'sentence-transformers',
    'gdown'
]

# --- EMBEDDED TOOLS ---
KUTATO_PY_CONTENT = r'''#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Kutato modul - Unified RAG Search Tool
Handles MQL5 Dev (MiniLM), Theory (MPNet), and Code (MPNet) RAGs using SQLite + FAISS.
"""

import sys
import json
import os
import argparse
import sqlite3
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer

# --- CONFIGURATION ---
RAG_MQL5_DIR = 'rag_mql5'
RAG_THEORY_DIR = 'rag_theory'
RAG_CODE_DIR = 'rag_code'

MODEL_MINILM = 'all-MiniLM-L6-v2'  # For MQL5 Dev
MODEL_MPNET = 'all-mpnet-base-v2'  # For Theory/Code

TOP_K = 5

class RAGSearcher:
    def __init__(self):
        self.models = {}
        self.rags = {} # Key: name -> {index, conn, model_key}

        # Initialize Models & RAGs
        self._init_rag('mql5', RAG_MQL5_DIR, 'MQL5_DEV_knowledgebase.db', 'MQL5_DEV_knowledgebase_compressed.index', MODEL_MINILM)
        self._init_rag('theory', RAG_THEORY_DIR, 'theory_knowledgebase.db', 'theory_compressed.index', MODEL_MPNET)
        self._init_rag('code', RAG_CODE_DIR, 'code_knowledgebase.db', 'code_compressed.index', MODEL_MPNET)

    def _get_model(self, model_name):
        if model_name not in self.models:
            # print(f"   [MEMORY] Loading model: {model_name}...", file=sys.stderr)
            self.models[model_name] = SentenceTransformer(model_name)
        return self.models[model_name]

    def _init_rag(self, name, directory, db_file, index_file, model_key):
        db_path = os.path.join(directory, db_file)
        index_path = os.path.join(directory, index_file)

        if os.path.exists(db_path) and os.path.exists(index_path):
            try:
                index = faiss.read_index(index_path, faiss.IO_FLAG_MMAP)
                conn = sqlite3.connect(db_path, check_same_thread=False)
                conn.row_factory = sqlite3.Row
                self.rags[name] = {
                    'index': index,
                    'conn': conn,
                    'model_key': model_key
                }
                # print(f"   [INIT] {name.upper()} RAG loaded.", file=sys.stderr)
            except Exception as e:
                sys.stderr.write(f"   [ERROR] Failed to load {name} RAG: {e}\n")
        else:
             # sys.stderr.write(f"   [WARN] Missing files for {name} RAG at {directory}\n")
             pass

    def search(self, query, top_k=TOP_K, scope='ALL'):
        all_results = []

        # Determine which RAGs to search
        targets = []
        if scope == 'ALL':
            targets = ['mql5', 'theory', 'code']
        elif scope == 'MQL5':
            targets = ['mql5']
        elif scope in ['LEGACY', 'THEORY', 'CODE']:
            # Mapping legacy scope names to our keys
            if scope == 'LEGACY': targets = ['theory', 'code']
            if scope == 'THEORY': targets = ['theory']
            if scope == 'CODE': targets = ['code']

        for name in targets:
            if name not in self.rags: continue
            rag = self.rags[name]

            try:
                model = self._get_model(rag['model_key'])
                q_vec = model.encode([query])

                # Perform Search
                D, I = rag['index'].search(q_vec, top_k)

                cursor = rag['conn'].cursor()
                for j, idx in enumerate(I[0]):
                    if idx == -1: continue

                    # Fetch from DB
                    # Assuming FAISS ID maps to SQLite ID column
                    cursor.execute("SELECT * FROM articles WHERE id = ?", (int(idx),))
                    row = cursor.fetchone()

                    if row:
                        content_val = row['content']
                        if not content_val and 'code' in row.keys(): # Fallback for code DB if content is empty
                            content_val = row['code']

                        res = {
                            'source_rag': name, # 'mql5', 'theory', 'code'
                            # Legacy compatibility keys
                            'source_type': name.upper() if name == 'mql5' else ('ELMELET' if name == 'theory' else 'KOD'),
                            'final_filename': row['filename'],
                            'content': content_val or '',
                            'score': float(1 / (1 + D[0][j])) # Simple distance-to-score
                        }
                        all_results.append(res)
            except Exception as e:
                sys.stderr.write(f"   [ERROR] Search failed for {name}: {e}\n")

        # Sort combined results by score
        all_results.sort(key=lambda x: x['score'], reverse=True)
        return all_results[:top_k]

def main():
    parser = argparse.ArgumentParser(description="Unified RAG Search Tool")
    parser.add_argument('query', nargs='+', help='Search query')
    parser.add_argument('--json', action='store_true', help='Output in JSON format')
    parser.add_argument('--limit', type=int, default=5, help='Number of results')
    parser.add_argument('--scope', default='ALL', choices=['ALL', 'MQL5', 'LEGACY', 'THEORY', 'CODE'], help='Search scope')

    args = parser.parse_args()
    query_text = ' '.join(args.query)

    searcher = RAGSearcher()
    # Note: search() uses 'scope' argument now
    results = searcher.search(query_text, top_k=args.limit, scope=args.scope)

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print(f"\n=== Search Results for: '{query_text}' (Scope: {args.scope}) ===\n")
        for res in results:
            print(f"[{res['source_type']}] {res['final_filename']} (Score: {res['score']:.4f})")
            print("-" * 60)
            preview = (res['content'][:400] + '...').replace('\n', ' ')
            print(preview)
            print("\n")

if __name__ == "__main__":
    main()
'''

KUTATO_UGYNOK_CONTENT = r'''#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import os
import re
import argparse
import time

# Add the repository root to sys.path to allow importing kutato.py
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(REPO_ROOT)

try:
    from kutato import RAGSearcher, TOP_K
except ImportError:
    # If not found, try to look in the same directory (if moved)
    try:
        from kutato import RAGSearcher, TOP_K
    except:
        sys.stderr.write("[ERROR] Could not import 'kutato'. Ensure kutato.py is in the root or same directory.\n")
        sys.exit(1)

MAX_DEPTH = 3
BRANCHING_FACTOR = 3

def log(msg, depth=0):
    indent = "   " * depth
    sys.stderr.write(f"{indent}[HEAVY WORKER]: {msg}\n")

def check_system_load():
    try:
        load = os.getloadavg()[0]
        if load > 3.0:
            log(f"High load ({load:.2f}). Pausing...")
            time.sleep(5)
    except: pass

def extract_concepts(text):
    concepts = set()
    # Find #include "file.mqh" or <file.mqh>
    includes = re.findall(r'#include\s*[<"](.*?)[>"]', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        # Filter out too short or common headers if needed
        if len(clean) > 2: concepts.add(f"MQL5 {clean}")
    return list(concepts)

def recursive_search(searcher, query, scope='ALL', depth=0, visited=None):
    check_system_load()

    if visited is None: visited = set()
    q_sig = query.lower().strip()
    if q_sig in visited: return []
    visited.add(q_sig)

    if depth >= MAX_DEPTH: return []

    log(f"Depth {depth}: '{query}'", depth)

    # Use the unified RAGSearcher
    hits = searcher.search(query, scope=scope)

    all_findings = []
    valid_count = 0

    for hit in hits:
        all_findings.append({
            'doc': hit,
            'score': float(hit['score']),
            'depth': depth,
            'query': query
        })
        valid_count += 1
        if valid_count >= TOP_K: break

        # Recursion logic: If deeper search is allowed, extract concepts
        if depth < MAX_DEPTH - 1:
            content = hit.get('content') or ""
            concepts = extract_concepts(content)
            for concept in concepts[:BRANCHING_FACTOR]:
                if concept.lower() not in visited:
                    sub = recursive_search(searcher, concept, scope, depth + 1, visited)
                    all_findings.extend(sub)

    return all_findings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--query', required=True)
    parser.add_argument('--scope', default='ALL', choices=['ALL', 'MQL5', 'LEGACY'])
    parser.add_argument('--depth', type=int, default=3)
    parser.add_argument('--output', choices=['json', 'text'], default='text')
    args, unknown = parser.parse_known_args()

    global MAX_DEPTH
    MAX_DEPTH = args.depth

    # Initialize the unified searcher
    searcher = RAGSearcher()

    results = recursive_search(searcher, args.query, scope=args.scope)

    # Deduplicate results based on filename
    unique_results = []
    seen = set()
    results.sort(key=lambda x: x['score'], reverse=True)

    for r in results:
        fname = r['doc'].get('final_filename', '')
        if fname not in seen:
            seen.add(fname)
            unique_results.append(r)
            if len(unique_results) >= 20: break

    if args.output == 'json':
        print(json.dumps(unique_results, indent=2))
    else:
        for r in unique_results:
            print(f"[{r['doc'].get('source_type')}] {r['doc'].get('final_filename')} ({r['score']:.2f})")
            if args.output == 'text':
                print(f"   Excerpt: {(r['doc'].get('content') or '')[:200].replace('\n', ' ')}...\n")

if __name__ == "__main__":
    main()
'''

def log(msg):
    print(f"[BOOTSTRAP] {msg}")

def run_cmd(cmd):
    try:
        subprocess.check_call(cmd, shell=True)
    except subprocess.CalledProcessError as e:
        log(f"ERROR: Command failed: {cmd}")
        sys.exit(1)

def install_dependencies():
    log("Installing Python dependencies...")
    run_cmd(f"{sys.executable} -m pip install {' '.join(DEPENDENCIES)}")

def setup_directories():
    log("Verifying directory structure...")
    for d in REQUIRED_DIRS:
        if not os.path.exists(d):
            os.makedirs(d)
            log(f"Created: {d}")

def restore_tools():
    log("Restoring tool scripts...")

    # kutato.py
    with open('kutato.py', 'w', encoding='utf-8') as f:
        f.write(KUTATO_PY_CONTENT)
    log("Restored: kutato.py")

    # kutato_ugynok_v3.py
    ugynok_path = os.path.join('Factory_System', 'kutato_ugynok_v3.py')
    with open(ugynok_path, 'w', encoding='utf-8') as f:
        f.write(KUTATO_UGYNOK_CONTENT)
    log(f"Restored: {ugynok_path}")

def download_rag(name, link, target_dir):
    # Check if DB exists to skip download
    # Assumption: zip contains .db or .index
    # We check if the target dir is populated with expected files
    if name == 'rag_mql5':
        check_file = os.path.join(target_dir, 'MQL5_DEV_knowledgebase.db')
    elif name == 'rag_theory':
        check_file = os.path.join(target_dir, 'theory_knowledgebase.db')
    elif name == 'rag_code':
        check_file = os.path.join(target_dir, 'code_knowledgebase.db')
    else:
        check_file = None

    if check_file and os.path.exists(check_file):
        log(f"RAG {name} already exists at {check_file}. Skipping download.")
        return

    log(f"Downloading {name}...")
    zip_path = f"{name}.zip"

    # Using gdown
    run_cmd(f"gdown --fuzzy '{link}' -O {zip_path}")

    log(f"Extracting {name}...")
    run_cmd(f"unzip -o {zip_path} -d {target_dir}")

    if os.path.exists(zip_path):
        os.remove(zip_path)
    log(f"Cleaned up {zip_path}")

def main():
    log("Starting environment setup...")

    install_dependencies()
    setup_directories()
    restore_tools()

    for name, link in RAG_LINKS.items():
        download_rag(name, link, name)

    log("Environment setup complete! You are ready to work.")

if __name__ == "__main__":
    main()
