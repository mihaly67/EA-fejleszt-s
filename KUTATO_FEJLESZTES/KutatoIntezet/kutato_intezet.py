#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.1 (Kutatóintézet - Expanded Scopes & Deduplication)
import sys
import json
import argparse
import re
import os
import subprocess
from collections import Counter
import time

# --- CONFIGURATION ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KUTATO_SCRIPT = os.path.abspath(os.path.join(BASE_DIR, "..", "kutato.py"))

# Dynamically import RAG Adapter if available
sys.path.append(BASE_DIR)
try:
    from rag_adapter import RAGAdapter
    rag_engine = RAGAdapter()
    RAG_AVAILABLE = True
except Exception as e:
    print(f"RAG Adapter not loaded: {e}")
    RAG_AVAILABLE = False

STOP_WORDS = {
    "the", "and", "is", "of", "to", "in", "a", "for", "with", "on", "as", "by", "at", "an", "be", "this", "that",
    "from", "or", "are", "it", "not", "but", "can", "if", "will", "has", "have", "which", "was", "were", "we",
    "you", "they", "he", "she", "import", "class", "def", "return", "self", "none", "true", "false", "var",
    "let", "const", "function", "test", "data", "code", "file", "your", "branch", "repo", "git", "main", "master",
    "http", "https", "com", "org", "net", "www", "html", "xml", "json", "yaml", "yml", "md", "txt", "value", "result"
}

def extract_keywords(text, limit=3):
    """Kinyeri a kulcsszavakat a szövegből (technikai kifejezések)."""
    candidates = []
    # Find words, allowing dots for filenames/objects
    words = re.findall(r'\b[a-zA-Z0-9_.]+\b', text)

    for w in words:
        w_clean = w.strip(".,")
        w_lower = w_clean.lower()

        # Strict filtering
        if w_lower in STOP_WORDS or len(w_clean) < 5: continue
        if w_clean.isdigit(): continue # Skip pure numbers

        # Heuristics for "Strong" technical terms
        is_snake = '_' in w_clean
        is_camel = re.match(r'^[A-Z][a-z]+[A-Z]', w_clean) or re.match(r'^[a-z]+[A-Z]', w_clean) # CamelCase or camelCase
        is_caps = w_clean.isupper() and len(w_clean) > 3
        is_dot_access = '.' in w_clean and not w_clean.startswith('.') # e.g. self.component

        if is_snake or is_camel or is_caps or is_dot_access:
            # Normalize to avoid duplicates like "Hummingbot" and "hummingbot" -> prefer original if Camel, else lower
            candidates.append(w_clean)

    # Deduplicate while preserving case preference (most frequent form wins)
    counts = Counter(candidates)

    # Post-process: Remove duplicates that differ only by case (e.g. "Token" vs "token")
    # Keep the most frequent casing
    final_candidates = {}
    for word, count in counts.most_common():
        lower = word.lower()
        if lower not in final_candidates:
            final_candidates[lower] = (word, count)
        else:
            # Add count to existing
            existing_word, existing_count = final_candidates[lower]
            final_candidates[lower] = (existing_word, existing_count + count)

    # Sort by count descending
    sorted_items = sorted(final_candidates.values(), key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:limit]]

def call_kutato(query, scope):
    """Hívja a kutato.py-t (JSONL) vagy a rag_adapter-t (RAG) scope alapján."""

    # RAG Handling
    if scope in ['MQL5_DEV', 'THEORY', 'CODE']:
        if RAG_AVAILABLE:
            return rag_engine.search_full(query, scope, top_k=5)
        else:
            return []

    # JSONL Handling (subprocess)
    try:
        cmd = [sys.executable, KUTATO_SCRIPT, query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0: return []
        return json.loads(result.stdout)
    except: return []

class ResearchLevel:
    def __init__(self, level_id, input_jobs, output_file, scopes=None):
        self.level_id = level_id
        self.input_jobs = input_jobs # List of {query, origin_doc}
        self.output_file = output_file
        # Updated default scopes to include new RAG sources
        self.scopes = scopes if scopes else [
            'MQL5_DEV', 'THEORY', 'CODE',
            'COLUMBO', 'THIEFS',
            'DATA_ENG', 'SYS_INTEGR', 'MONITORING',
            'EXT_THIEFS', 'EXT_COLUMBO'
        ]
        self.results = []
        self.next_jobs = []

    def deduplicate_results(self, raw_results):
        """Merges duplicate files from different scopes."""
        merged = {}
        for r in raw_results:
            key = r.get('filename', 'unknown')

            if key in merged:
                # Merge existing
                existing = merged[key]
                # Add source to found_in list
                if 'found_in' not in existing:
                    existing['found_in'] = [existing['source_type']]

                if r['source_type'] not in existing['found_in']:
                    existing['found_in'].append(r['source_type'])
                    # Update display source to show multiple
                    existing['source_type'] = ", ".join(existing['found_in'])

                # Update max score
                if r['score'] > existing['score']:
                    existing['score'] = r['score']
            else:
                # New entry
                r['found_in'] = [r['source_type']]
                merged[key] = r

        return list(merged.values())

    def run(self, max_jobs=None):
        print(f"\n--- LEVEL {self.level_id} START ---")
        print(f"Input Jobs: {len(self.input_jobs)}")

        jobs_to_run = self.input_jobs
        # If input_jobs is actually a list of strings (simple queries from legacy format), normalize
        if jobs_to_run and isinstance(jobs_to_run[0], str):
            jobs_to_run = [{'query': q, 'origin_doc': 'UNKNOWN'} for q in jobs_to_run]

        if max_jobs and len(jobs_to_run) > max_jobs:
            print(f"Limiting jobs to {max_jobs} for safety.")
            jobs_to_run = jobs_to_run[:max_jobs]

        for i, job in enumerate(jobs_to_run):
            query = job['query']
            print(f"[{self.level_id}] Processing Job #{i+1}: '{query}'")

            job_results = []
            for scope in self.scopes:
                hits = call_kutato(query, scope)
                for h in hits:
                    h['level'] = self.level_id
                    h['parent_query'] = query
                    job_results.append(h)

            # Deduplicate results for this job
            unique_results = self.deduplicate_results(job_results)

            # Process results for next level
            for res in unique_results:
                # Add to current level results
                self.results.append(res)

                # Extract new keywords for next level
                keywords = extract_keywords(res.get('content', ''))
                for kw in keywords:
                    self.next_jobs.append({
                        'query': kw,
                        'origin_doc': res.get('filename', '?')
                    })

        # Save results
        self.save_state()
        print(f"--- LEVEL {self.level_id} COMPLETE ---")
        print(f"Generated Results: {len(self.results)}")
        print(f"New Jobs for Next Level: {len(self.next_jobs)}")

    def save_state(self):
        data = {
            'level': self.level_id,
            'results': self.results,
            'next_jobs': self.next_jobs
        }
        with open(self.output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print(f"Saved state to {self.output_file}")

def main():
    parser = argparse.ArgumentParser(description="Kutatóintézet - Hierarchikus Kutatás")
    parser.add_argument('--role', choices=['director', 'manager', 'worker'], required=True, help="Role to execute")
    parser.add_argument('--input', help="Input JSON file (for managers/workers)")
    parser.add_argument('--output', required=True, help="Output JSON file")
    parser.add_argument('--query', help="Initial query (for director only)")
    parser.add_argument('--limit', type=int, default=10, help="Max jobs to process")

    args = parser.parse_args()

    level = None # Initialize level variable

    if args.role == 'director':
        if not args.query:
            print("Error: Director needs a --query")
            sys.exit(1)

        # Director starts level 0
        jobs = [{'query': args.query, 'origin_doc': 'DIRECTOR'}]
        level = ResearchLevel(0, jobs, args.output)

    elif args.role in ['manager', 'worker']:
        if not args.input:
            print("Error: Manager/Worker needs an --input file")
            sys.exit(1)

        try:
            with open(args.input, 'r', encoding='utf-8') as f:
                data = json.load(f)
                input_jobs = data.get('next_jobs', [])
                prev_level = data.get('level', 0)

            current_level_id = prev_level + 1
            level = ResearchLevel(current_level_id, input_jobs, args.output)

        except Exception as e:
            print(f"Error loading input: {e}")
            sys.exit(1)

    if level:
        level.run(max_jobs=args.limit)

if __name__ == "__main__":
    main()
