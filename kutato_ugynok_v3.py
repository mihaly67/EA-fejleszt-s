#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Universal Heavy Worker v3.0 (Kutato Ugynok v3)
Wrapper around 'kutato.py' to perform deep, recursive searches across ALL RAG databases.
"""
import sys
import json
import os
import re
import argparse
import subprocess

# --- CONFIGURATION ---
KUTATO_SCRIPT = "kutato.py"
MAX_DEPTH = 3        # Recursion depth
TOP_K_PER_STEP = 3   # Hits per step

def log(msg):
    print(f"   [UGYNOK v3]: {msg}")

def run_kutato(query, scope='ALL'):
    """Executes the base searcher tool via subprocess."""
    try:
        cmd = [sys.executable, KUTATO_SCRIPT, query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            log(f"Search failed for '{query}': {result.stderr}")
            return []

        # Parse JSON output from kutato.py
        try:
            hits = json.loads(result.stdout)
            return hits
        except json.JSONDecodeError:
            log(f"Invalid JSON from kutato.py: {result.stdout[:100]}...")
            return []
    except Exception as e:
        log(f"Subprocess error: {e}")
        return []

def extract_leads(text):
    """Extracts potential follow-up queries (includes, class names)."""
    leads = []
    # MQL5 Includes
    includes = re.findall(r'#include <(.*?)>', text)
    for inc in includes:
        clean = inc.replace('\\', ' ').replace('.mqh', '')
        leads.append(f"MQL5 {clean} source code")

    # MQL5 Classes
    classes = re.findall(r'\bclass\s+(C[A-Z][a-zA-Z0-9]+)', text)
    for cls in classes:
        leads.append(f"MQL5 class {cls} definition")

    return list(set(leads))

def deep_research(initial_query, max_depth=MAX_DEPTH):
    log(f"Deep Research Started: '{initial_query}'")

    knowledge_base = []
    queue = [(initial_query, 0)] # (Query, Depth)
    visited_queries = set()
    seen_content_hashes = set()

    while queue:
        query, depth = queue.pop(0)
        q_sig = query.lower().strip()

        if q_sig in visited_queries: continue
        if depth > max_depth: continue

        visited_queries.add(q_sig)
        log(f"Step {depth+1}: Searching '{query}'...")

        # 1. Search
        hits = run_kutato(query)

        if not hits:
            log("   -> No results.")
            continue

        log(f"   -> Found {len(hits)} hits.")

        # 2. Process Hits
        for hit in hits:
            content = hit.get('content', '')
            # Dedup based on content snippet
            h = hash(content[:100])
            if h in seen_content_hashes: continue
            seen_content_hashes.add(h)

            knowledge_base.append(hit)

            # 3. Extract Leads (only if not too deep)
            if depth < max_depth:
                new_leads = extract_leads(content)
                for lead in new_leads:
                    if lead.lower() not in visited_queries:
                        # Prioritize leads? Or append to end (BFS).
                        log(f"      -> New Lead: {lead}")
                        queue.append((lead, depth + 1))

    return knowledge_base

def main():
    if len(sys.argv) < 2:
        print("Usage: python kutato_ugynok_v3.py \"query\"")
        sys.exit(1)

    initial_query = ' '.join(sys.argv[1:])

    # Run Deep Research
    results = deep_research(initial_query)

    print(f"\n{'='*60}")
    print(f"DEEP RESEARCH REPORT: {initial_query}")
    print(f"{'='*60}\n")

    for i, res in enumerate(results):
        print(f"HIT #{i+1} [{res.get('source_type','?')}] {res.get('filename','?')}")
        print(f"Score: {res.get('score',0):.2f}")
        print("-" * 40)
        content = res.get('content','')
        print(content[:2000].replace('\r', ''))
        if len(content) > 2000: print("\n... [Truncated]")
        print("\n")

if __name__ == "__main__":
    main()
