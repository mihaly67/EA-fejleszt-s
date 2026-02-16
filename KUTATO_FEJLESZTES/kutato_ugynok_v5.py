#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 5.0 (Hybrid Deep Drill - RAG + JSONL + GREP)
import sys
import json
import argparse
import re
import os
import subprocess
from collections import Counter

# --- CONFIGURATION ---
DEFAULT_DEPTH = 3
DEFAULT_BRANCH = 3 # How many new queries to branch from each result
TOP_K_PER_QUERY = 5
VALID_SCOPES = [
    'MQL5_DEV', 'THEORY', 'CODE',
    'COLUMBO', 'THIEFS',
    'DATA_ENG', 'SYS_INTEGR', 'MONITORING',
    'EXT_THIEFS', 'EXT_COLUMBO'
]

# Directories where raw files might be present for GREP
RAW_FILE_DIRS = {
    'THIEFS': 'Knowledge_Base',
    'COLUMBO': 'Knowledge_Base',
    'CODE': 'github_codebase' # If available
}

class HybridDeepDrillAgent:
    def __init__(self, depth=DEFAULT_DEPTH, branch=DEFAULT_BRANCH, allowed_scopes=None, use_grep=True):
        self.depth = depth
        self.branch_factor = branch
        self.knowledge_base = {} # Deduplicated by content hash
        self.visited_queries = set()
        self.allowed_scopes = allowed_scopes if allowed_scopes else VALID_SCOPES
        self.use_grep = use_grep
        self.stop_words = {"the", "and", "is", "of", "to", "in", "a", "for", "with", "on", "as", "by", "at", "an", "be", "this", "that", "from", "or", "are", "it", "not", "but", "can", "if", "will", "has", "have", "which", "was", "were", "we", "you", "they", "he", "she", "import", "class", "def", "return", "self", "none", "true", "false", "var", "let", "const", "function"}

    def _hash_doc(self, doc):
        return hash(doc.get('content', '')[:100] + doc.get('filename', ''))

    def _extract_keywords(self, text, limit=5):
        """Extracts potential technical keywords (CamelCase, snake_case, ALL_CAPS)."""
        candidates = []
        words = re.findall(r'\b[a-zA-Z0-9_]+\b', text)

        for w in words:
            w_lower = w.lower()
            if w_lower in self.stop_words or len(w) < 4: continue

            # Heuristics for "interesting" technical terms
            is_snake = '_' in w
            is_camel = re.match(r'[A-Z][a-z]+[A-Z]', w)
            is_caps = w.isupper() and len(w) > 2
            is_file = '.' in w

            if is_snake or is_camel or is_caps or is_file:
                candidates.append(w)
            elif w_lower not in self.stop_words:
                candidates.append(w)

        counts = Counter(candidates)
        return [item[0] for item in counts.most_common(limit)]

    def _call_kutato_search(self, query, scope):
        try:
            # Use path relative to this script
            script_dir = os.path.dirname(os.path.abspath(__file__))
            script_path = os.path.join(script_dir, "kutato.py")

            if not os.path.exists(script_path):
                 # Fallback: maybe we are in root and kutato.py is in KUTATO_FEJLESZTES?
                 # Or vice versa. Just check standard locations.
                 if os.path.exists("KUTATO_FEJLESZTES/kutato.py"):
                     script_path = "KUTATO_FEJLESZTES/kutato.py"
                 elif os.path.exists("kutato.py"):
                     script_path = "kutato.py"

            cmd = [sys.executable, script_path, query, "--scope", scope, "--json"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if result.returncode != 0: return []
            return json.loads(result.stdout)
        except: return []

    def _call_grep_search(self, query, scope):
        """Executes a recursive grep search in the target directory for the scope."""
        target_dir = RAW_FILE_DIRS.get(scope)
        if not target_dir or not os.path.exists(target_dir): return []

        try:
            # Grep recursive, max 5 matches, only matching line
            # Using -r (recursive), -i (ignore case), -n (line number), -a (treat binary as text)
            # Limiting to first 5 matches to avoid flooding
            cmd = ["grep", "-r", "-i", "-n", "-a", "--max-count=1", query, target_dir]

            # Run grep with timeout
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)

            hits = []
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines[:self.branch_factor]: # Limit results
                    parts = line.split(':', 2)
                    if len(parts) >= 3:
                        filename = parts[0]
                        line_num = parts[1]
                        content = parts[2].strip()
                        hits.append({
                            'source_type': 'GREP',
                            'source_scope': scope,
                            'filename': f"{filename}:{line_num}",
                            'content': content,
                            'score': 1.0 # Exact match
                        })
            return hits
        except Exception as e:
            return []

    def search_recursive(self, queries, current_depth):
        if current_depth > self.depth: return

        print(f"\n--- DEPTH {current_depth}/{self.depth} [Queries: {len(queries)}] ---")
        next_level_queries = []

        for query in queries:
            q_clean = query.strip().lower()
            if q_clean in self.visited_queries: continue
            self.visited_queries.add(q_clean)

            print(f"🔍 Hybrid Drilling: '{query}' in {self.allowed_scopes}")

            for scope in self.allowed_scopes:
                # 1. Semantic Search (Kutato RAG/JSONL)
                rag_results = self._call_kutato_search(query, scope)

                # 2. Exact Match Search (Grep) - Only if enabled and directory exists
                grep_results = []
                if self.use_grep and scope in RAW_FILE_DIRS:
                    # Heuristic: Only grep if query looks technical (no spaces, >3 chars)
                    if ' ' not in query and len(query) > 3:
                        grep_results = self._call_grep_search(query, scope)
                        if grep_results:
                            print(f"   [GREP] Found {len(grep_results)} matches in {scope}")

                # Combine results
                all_results = rag_results + grep_results

                if all_results:
                    # Process top results (prioritize Grep if exact match found)
                    # Limit processing to branch_factor
                    for res in all_results[:self.branch_factor]:
                        doc_hash = self._hash_doc(res)
                        if doc_hash not in self.knowledge_base:
                            self.knowledge_base[doc_hash] = res
                            res['source_scope'] = scope

                            # Drill deeper
                            if current_depth < self.depth:
                                content = res.get('content', '')
                                new_terms = self._extract_keywords(content, limit=self.branch_factor)
                                for term in new_terms:
                                    if term.lower() not in self.visited_queries:
                                        next_level_queries.append(term)
                                        print(f"   -> New Branch: '{term}' (from {res.get('filename','?')})")

        if next_level_queries:
            next_level_queries = list(set(next_level_queries))
            if len(next_level_queries) > 20:
                next_level_queries = next_level_queries[:20]
            self.search_recursive(next_level_queries, current_depth + 1)

    def run(self, initial_queries):
        print(f"🚀 Starting Hybrid Deep Drill (Depth: {self.depth}, Branch: {self.branch_factor}, Grep: {self.use_grep})")
        self.search_recursive(initial_queries, 1)
        self.report()

    def report(self):
        print("\n" + "="*80)
        print(f"🔬 HYBRID RESEARCH REPORT (Total Unique Documents: {len(self.knowledge_base)})")
        print("="*80)

        sorted_docs = sorted(self.knowledge_base.values(), key=lambda x: (x.get('source_scope', ''), x.get('score', 0)), reverse=True)

        for i, doc in enumerate(sorted_docs):
            scope = doc.get('source_scope', 'UNKNOWN')
            stype = doc.get('source_type', '?')
            print(f"\n📄 ITEM #{i+1} [SCOPE: {scope}] [{stype} | {doc.get('filename', '?')}] (Score: {doc.get('score', 0):.2f})")
            print("-" * 80)
            content = doc.get('content', '')
            display_content = content[:3000].replace('\r', '')
            print(display_content)
            if len(content) > 3000:
                print("\n... [Content Truncated] ...")
            print("-" * 80)

def main():
    parser = argparse.ArgumentParser(description="Hybrid Deep Drill Agent (v5)")
    parser.add_argument('queries', nargs='+', help='Initial search queries')
    parser.add_argument('--depth', type=int, default=DEFAULT_DEPTH, help='Recursion depth')
    parser.add_argument('--branch', type=int, default=DEFAULT_BRANCH, help='Branching factor')
    parser.add_argument('--scope', type=str, help='Limit search to specific scope')
    parser.add_argument('--no-grep', action='store_true', help='Disable grep search')
    args = parser.parse_args()

    queries = []
    for q in args.queries:
        if ';' in q:
            queries.extend(q.split(';'))
        else:
            queries.append(q)

    scopes = None
    if args.scope:
        if args.scope in VALID_SCOPES:
            scopes = [args.scope]
        else:
            print(f"Invalid scope. Valid options: {VALID_SCOPES}")
            sys.exit(1)

    agent = HybridDeepDrillAgent(
        depth=args.depth,
        branch=args.branch,
        allowed_scopes=scopes,
        use_grep=not args.no_grep
    )
    agent.run(queries)

if __name__ == "__main__":
    main()
