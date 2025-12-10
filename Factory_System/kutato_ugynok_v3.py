#!/usr/bin/env python
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
