#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 4.0 (Deep Drilling - Keyword Branching)
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
VALID_SCOPES = ['MQL5_DEV', 'THEORY', 'CODE', 'COLUMBO', 'THIEFS']

class DeepDrillAgent:
    def __init__(self, depth=DEFAULT_DEPTH, branch=DEFAULT_BRANCH, allowed_scopes=None):
        self.depth = depth
        self.branch_factor = branch
        self.knowledge_base = {} # Deduplicated by content hash
        self.visited_queries = set()
        self.allowed_scopes = allowed_scopes if allowed_scopes else VALID_SCOPES
        self.stop_words = {"the", "and", "is", "of", "to", "in", "a", "for", "with", "on", "as", "by", "at", "an", "be", "this", "that", "from", "or", "are", "it", "not", "but", "can", "if", "will", "has", "have", "which", "was", "were", "we", "you", "they", "he", "she", "import", "class", "def", "return", "self", "none", "true", "false"}

    def _hash_doc(self, doc):
        return hash(doc.get('content', '')[:100] + doc.get('filename', ''))

    def _extract_keywords(self, text, limit=5):
        """Extracts potential technical keywords (CamelCase, snake_case, ALL_CAPS) or frequent technical terms."""
        # Pattern for potential technical terms:
        # 1. Words with underscores (snake_case_vars)
        # 2. Words with mixed case (CamelCaseClass)
        # 3. All caps words of length > 2 (CONSTANTS or ACRONYMS)
        # 4. Words ending in common technical suffixes like .py, .cpp, .mq5, .dll

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
                # Fallback: just add non-stopwords to frequency count
                candidates.append(w)

        # Count frequency to find most relevant
        counts = Counter(candidates)
        # Return top N most frequent 'interesting' terms
        return [item[0] for item in counts.most_common(limit)]

    def _call_kutato_search(self, query, scope):
        try:
            cmd = [sys.executable, "kutato.py", query, "--scope", scope, "--json"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if result.returncode != 0: return []
            return json.loads(result.stdout)
        except: return []

    def search_recursive(self, queries, current_depth):
        if current_depth > self.depth: return

        print(f"\n--- DEPTH {current_depth}/{self.depth} [Queries: {len(queries)}] ---")
        next_level_queries = []

        for query in queries:
            q_clean = query.strip().lower()
            if q_clean in self.visited_queries: continue
            self.visited_queries.add(q_clean)

            print(f"🔍 Drilling: '{query}' in {self.allowed_scopes}")

            for scope in self.allowed_scopes:
                results = self._call_kutato_search(query, scope)

                if results:
                    # Process top results to extract new drill targets
                    for res in results[:self.branch_factor]: # Limit branching per scope
                        doc_hash = self._hash_doc(res)
                        if doc_hash not in self.knowledge_base:
                            self.knowledge_base[doc_hash] = res
                            res['source_scope'] = scope

                            # Drill deeper: Extract keywords from content
                            if current_depth < self.depth:
                                content = res.get('content', '')
                                new_terms = self._extract_keywords(content, limit=self.branch_factor)

                                # Combine original query context with new term? Or just new term?
                                # Strategy: Just new term to widen search (breadth)
                                for term in new_terms:
                                    if term.lower() not in self.visited_queries:
                                        next_level_queries.append(term)
                                        print(f"   -> New Branch: '{term}' (from {res.get('filename','?')})")

        if next_level_queries:
            # Deduplicate and limit total next level queries to avoid exponential explosion
            # But ensure we keep 'branch_factor' diversity
            next_level_queries = list(set(next_level_queries))
            # Limit total branches for next level to keep runtime manageable (e.g., 20)
            if len(next_level_queries) > 20:
                next_level_queries = next_level_queries[:20]

            self.search_recursive(next_level_queries, current_depth + 1)

    def run(self, initial_queries):
        print(f"🚀 Starting Deep Drill (Depth: {self.depth}, Branch: {self.branch_factor}, Scopes: {self.allowed_scopes})")
        self.search_recursive(initial_queries, 1)
        self.report()

    def report(self):
        print("\n" + "="*80)
        print(f"🔬 DEEP DRILL REPORT (Total Unique Documents: {len(self.knowledge_base)})")
        print("="*80)

        sorted_docs = sorted(self.knowledge_base.values(), key=lambda x: (x.get('source_scope', ''), x.get('score', 0)), reverse=True)

        for i, doc in enumerate(sorted_docs):
            scope = doc.get('source_scope', 'UNKNOWN')
            print(f"\n📄 ITEM #{i+1} [SCOPE: {scope}] [{doc.get('source_type', '?')} | {doc.get('filename', '?')}] (Score: {doc.get('score', 0):.2f})")
            print("-" * 80)
            content = doc.get('content', '')
            display_content = content[:3000].replace('\r', '')
            print(display_content)
            if len(content) > 3000:
                print("\n... [Content Truncated] ...")
            print("-" * 80)

def main():
    parser = argparse.ArgumentParser(description="Deep Drill RAG Agent (v4)")
    parser.add_argument('queries', nargs='+', help='Initial search queries')
    parser.add_argument('--depth', type=int, default=DEFAULT_DEPTH, help='Recursion depth')
    parser.add_argument('--branch', type=int, default=DEFAULT_BRANCH, help='Branching factor (new queries per result)')
    parser.add_argument('--scope', type=str, help='Limit search to specific scope')
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

    agent = DeepDrillAgent(depth=args.depth, branch=args.branch, allowed_scopes=scopes)
    agent.run(queries)

if __name__ == "__main__":
    main()
