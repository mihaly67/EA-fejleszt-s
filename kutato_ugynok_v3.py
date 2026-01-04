#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import argparse
import re
import os
from kutato import RAGSearcher, GITHUB_JSONL, MT_LIBS_JSONL, LAYERING_JSONL

# --- CONFIGURATION ---
DEFAULT_DEPTH = 3
TOP_K_PER_QUERY = 5
VALID_SCOPES = ['MQL5_DEV', 'THEORY', 'CODE']

class DeepResearcher:
    def __init__(self, depth=DEFAULT_DEPTH):
        self.depth = depth
        self.searcher = RAGSearcher()
        self.knowledge_base = {} # Deduplicated by content hash
        self.visited_queries = set()

    def _hash_doc(self, doc):
        return hash(doc.get('content', '')[:100] + doc.get('filename', ''))

    def extract_follow_up_queries(self, text):
        """Simple heuristic to find related technical terms for deeper search."""
        queries = []
        # Look for algorithm names
        algos = re.findall(r'\b(JMA|HMA|ALMA|Kalman|ZeroLag|T3|DEMA|TEMA)\b', text, re.IGNORECASE)
        for algo in algos:
            queries.append(f"MQL5 {algo} smoothing algorithm")

        # Look for normalization terms
        norms = re.findall(r'\b(Inverse Fisher|Tanh|Logistic|Sigmoid|Normalization)\b', text, re.IGNORECASE)
        for norm in norms:
            queries.append(f"MQL5 {norm} transform")

        # Look for specific MQL5 library references
        includes = re.findall(r'#include <(.*?)>', text)
        for inc in includes:
            clean = inc.replace('\\', ' ').replace('.mqh', '')
            if "Trade" not in clean and "Err" not in clean: # Filter common utils
                queries.append(f"MQL5 {clean} source code")

        return list(set(queries))

    def search_recursive(self, queries, current_depth):
        if current_depth > self.depth:
            return

        print(f"\n--- DEPTH {current_depth}/{self.depth} ---")
        next_level_queries = []

        for query in queries:
            q_clean = query.strip().lower()
            if q_clean in self.visited_queries:
                continue
            self.visited_queries.add(q_clean)

            print(f"🔍 Searching: '{query}'")

            # Iterate over all valid scopes explicitly
            for scope in VALID_SCOPES:
                try:
                    # print(f"   -> Scope: {scope}...")
                    results = self.searcher.search(query, scope=scope)

                    if results:
                        # print(f"      Found {len(results)} hits.")
                        for res in results:
                            doc_hash = self._hash_doc(res)
                            if doc_hash not in self.knowledge_base:
                                self.knowledge_base[doc_hash] = res

                                # Dig deeper (only if allowed)
                                if current_depth < self.depth:
                                    content = res.get('content', '')
                                    new_leads = self.extract_follow_up_queries(content)
                                    for lead in new_leads:
                                        if lead.lower() not in self.visited_queries:
                                            next_level_queries.append(lead)
                except Exception as e:
                    print(f"   ❌ Error searching '{query}' in {scope}: {e}")

        if next_level_queries:
            # Deduplicate list
            next_level_queries = list(set(next_level_queries))
            # Limit branching factor
            next_level_queries = next_level_queries[:5]
            self.search_recursive(next_level_queries, current_depth + 1)

    def run(self, initial_queries):
        print(f"🚀 Starting Deep Research (Depth: {self.depth})")
        print(f"   Using Reference JSONLs: {GITHUB_JSONL}, {MT_LIBS_JSONL}, {LAYERING_JSONL}")
        self.search_recursive(initial_queries, 1)
        self.report()

    def report(self):
        print("\n" + "="*80)
        print(f"🔬 RESEARCH REPORT (Total Unique Documents: {len(self.knowledge_base)})")
        print("="*80)

        # Sort by score
        sorted_docs = sorted(self.knowledge_base.values(), key=lambda x: x.get('score', 0), reverse=True)

        for i, doc in enumerate(sorted_docs):
            print(f"\n📄 ITEM #{i+1} [{doc.get('source_type', '?')} | {doc.get('filename', '?')}] (Score: {doc.get('score', 0):.2f})")
            print("-" * 80)
            content = doc.get('content', '')
            display_content = content[:3000].replace('\r', '')
            print(display_content)
            if len(content) > 3000:
                print("\n... [Content Truncated] ...")
            print("-" * 80)

def main():
    parser = argparse.ArgumentParser(description="Deep Recursive RAG Agent")
    parser.add_argument('queries', nargs='+', help='Initial search queries')
    parser.add_argument('--depth', type=int, default=DEFAULT_DEPTH, help='Recursion depth')
    args = parser.parse_args()

    # Split multi-query string
    queries = []
    for q in args.queries:
        if ';' in q:
            queries.extend(q.split(';'))
        else:
            queries.append(q)

    agent = DeepResearcher(depth=args.depth)
    agent.run(queries)

if __name__ == "__main__":
    main()
