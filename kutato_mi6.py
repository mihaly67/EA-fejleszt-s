#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Kutato MI6 - Passive Knowledge Base Searcher for MI6 and Black Ops JSONL files.
Searches for specific keywords without complex dependencies (no vectorization).
"""

import json
import os
import argparse
import sys

# Define locations of the new knowledge bases
KNOWLEDGE_BASES = {
    "MI6": "Knowledge_Base/MI6/MI6.jsonl",
    "Black_Ops": "Knowledge_Base/Black_Ops/Black_Ops.jsonl"
}

def search_jsonl(filepath, keywords, limit=20):
    """Searches a JSONL file for keywords."""
    if not os.path.exists(filepath):
        print(f"ERROR: Knowledge base not found: {filepath}")
        return

    print(f"\n--- Searching in: {filepath} ---")
    matches_found = 0

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line_idx, line in enumerate(f):
                if matches_found >= limit:
                    print(f"... Limit of {limit} matches reached.")
                    break

                try:
                    data = json.loads(line)
                    content = ""
                    # Content can be in various fields depending on the source structure
                    if 'content' in data: content += str(data['content'])
                    if 'code' in data: content += str(data['code'])
                    if 'text' in data: content += str(data['text'])
                    if 'description' in data: content += str(data['description'])

                    content_lower = content.lower()

                    # Check if ANY keyword is present
                    found_keywords = [kw for kw in keywords if kw.lower() in content_lower]

                    if found_keywords:
                        matches_found += 1
                        print(f"\n[MATCH #{matches_found}] Line {line_idx+1}")
                        print(f"Keywords found: {found_keywords}")
                        print(f"Source/File: {data.get('filename', 'Unknown')}")
                        # Print a snippet around the first keyword
                        snippet_len = 300
                        kw_pos = content_lower.find(found_keywords[0].lower())
                        start = max(0, kw_pos - 50)
                        end = min(len(content), kw_pos + snippet_len)
                        print(f"Snippet: ...{content[start:end]}...")
                        print("-" * 40)

                except json.JSONDecodeError:
                    continue
    except Exception as e:
        print(f"Error reading file {filepath}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Search MI6 and Black Ops Knowledge Bases")
    parser.add_argument('keywords', nargs='+', help="Keywords to search for")
    parser.add_argument('--limit', type=int, default=20, help="Max matches per file")

    args = parser.parse_args()

    print(f"Searching for keywords: {args.keywords}")

    for kb_name, kb_path in KNOWLEDGE_BASES.items():
        search_jsonl(kb_path, args.keywords, args.limit)

if __name__ == "__main__":
    main()
