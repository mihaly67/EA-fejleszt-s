#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.0 (Kutatóintézet - Hierarchikus Kutatási Rendszer)
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

STOP_WORDS = {"the", "and", "is", "of", "to", "in", "a", "for", "with", "on", "as", "by", "at", "an", "be", "this", "that", "from", "or", "are", "it", "not", "but", "can", "if", "will", "has", "have", "which", "was", "were", "we", "you", "they", "he", "she", "import", "class", "def", "return", "self", "none", "true", "false", "var", "let", "const", "function"}

def extract_keywords(text, limit=3):
    """Kinyeri a kulcsszavakat a szövegből (technikai kifejezések)."""
    candidates = []
    words = re.findall(r'\b[a-zA-Z0-9_]+\b', text)

    for w in words:
        w_lower = w.lower()
        if w_lower in STOP_WORDS or len(w) < 4: continue

        is_snake = '_' in w
        is_camel = re.match(r'[A-Z][a-z]+[A-Z]', w)
        is_caps = w.isupper() and len(w) > 2

        if is_snake or is_camel or is_caps:
            candidates.append(w)
        elif w_lower not in STOP_WORDS:
            candidates.append(w)

    counts = Counter(candidates)
    return [item[0] for item in counts.most_common(limit)]

def call_kutato(query, scope):
    """Hívja a kutato.py-t egy adott query-re és scope-ra."""
    try:
        cmd = [sys.executable, KUTATO_SCRIPT, query, "--scope", scope, "--json"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0: return []
        return json.loads(result.stdout)
    except: return []

class ResearchLevel:
    def __init__(self, level_id, input_jobs, output_file, scopes=['THIEFS', 'COLUMBO']):
        self.level_id = level_id
        self.input_jobs = input_jobs # List of {query, origin_doc}
        self.output_file = output_file
        self.scopes = scopes
        self.results = []
        self.next_jobs = []

    def run(self, max_jobs=None):
        print(f"\n--- LEVEL {self.level_id} START ---")
        print(f"Input Jobs: {len(self.input_jobs)}")

        jobs_to_run = self.input_jobs
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

            # Process results for next level
            for res in job_results:
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

    if args.role == 'director':
        if not args.query:
            print("Error: Director needs a --query")
            sys.exit(1)

        # Director starts level 0
        jobs = [{'query': args.query, 'origin_doc': 'DIRECTOR'}]
        level = ResearchLevel(0, jobs, args.output)
        level.run(max_jobs=args.limit)

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
            level.run(max_jobs=args.limit)

        except Exception as e:
            print(f"Error loading input: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()
