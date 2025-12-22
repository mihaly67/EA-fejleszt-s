#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import json
import argparse
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer

# Config
JSONL_PATH = 'github_codebase/external_codebase.jsonl'
MODEL_NAME = 'all-MiniLM-L6-v2' # Fast and sufficient

class LocalSearcher:
    def __init__(self):
        print(f"Loading model {MODEL_NAME}...")
        self.model = SentenceTransformer(MODEL_NAME)
        self.documents = []
        self.index = None

    def load_data(self):
        print(f"Loading data from {JSONL_PATH}...")
        try:
            with open(JSONL_PATH, 'r', encoding='utf-8') as f:
                for line in f:
                    try:
                        entry = json.loads(line)
                        # Create a searchable text chunk: Path + Content snippet
                        # We truncate content to avoid token limits during encoding
                        text = f"File: {entry['path']}\nContent: {entry['content'][:1000]}"
                        self.documents.append({
                            'path': entry['path'],
                            'content': entry['content'],
                            'text': text
                        })
                    except json.JSONDecodeError:
                        continue
        except FileNotFoundError:
            print(f"Error: {JSONL_PATH} not found.")
            sys.exit(1)

        print(f"Loaded {len(self.documents)} documents. Building index...")

        # Encode
        embeddings = self.model.encode([d['text'] for d in self.documents], show_progress_bar=True)

        # Build FAISS index
        d = embeddings.shape[1]
        self.index = faiss.IndexFlatL2(d)
        self.index.add(embeddings)
        print("Index built.")

    def search(self, query, top_k=5):
        if not self.index:
            return []

        print(f"Searching for: '{query}'")
        q_vec = self.model.encode([query])
        D, I = self.index.search(q_vec, top_k)

        results = []
        for j, idx in enumerate(I[0]):
            if idx == -1: continue
            doc = self.documents[idx]
            results.append({
                'path': doc['path'],
                'snippet': doc['content'][:1000], # First 1000 chars
                'score': float(1 / (1 + D[0][j]))
            })
        return results

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('query', nargs='+', help='Query string')
    parser.add_argument('--limit', type=int, default=5, help='Number of results')
    args = parser.parse_args()

    query = ' '.join(args.query)

    searcher = LocalSearcher()
    searcher.load_data()
    hits = searcher.search(query, top_k=args.limit)

    print(f"\nFound {len(hits)} results:\n")
    for i, h in enumerate(hits):
        print(f"[{i+1}] {h['path']} (Score: {h['score']:.4f})")
        print("-" * 60)
        # Print a clean snippet
        snippet = h['snippet'].replace('\r', '').replace('\n', ' ')[:400]
        print(f"{snippet}...")
        print("\n")

if __name__ == "__main__":
    main()
