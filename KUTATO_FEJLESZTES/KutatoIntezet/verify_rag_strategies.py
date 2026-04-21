#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Version: 1.1 (Verification Script for Multi-Strategy RAG)
import sys
import os
import json

# Adjust path to find rag_adapter
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from rag_adapter import RAGAdapter

def test_theory_strategy(adapter):
    print("\n--- TEST 1: THEORY (Windowed Context) ---")
    query = "indicator buffer"
    results = adapter.search_full(query, "THEORY", top_k=3)

    if not results:
        print("FAIL: No results found for THEORY.")
        return False

    for res in results:
        print(f"Hit: {res['filename']}")
        content = res['content']

        # Check for Windowed Context header
        if "(Windowed Context:" not in content:
            print(f"FAIL: Content missing Windowed Context header. Got: {content[:50]}...")
            return False

        # Check for TOC
        if "_TOC.txt" in res['filename']:
             print("FAIL: TOC file returned.")
             return False

    print("PASS: Theory strategy looks correct.")
    return True

def test_code_strategy(adapter):
    print("\n--- TEST 2: CODE (Full Reconstruction) ---")
    query = "OnCalculate"
    results = adapter.search_full(query, "CODE", top_k=3)

    if not results:
        print("FAIL: No results found for CODE.")
        return False

    for res in results:
        print(f"Hit: {res['filename']}")
        content = res['content']

        # Check for Full File header
        if "--- FILE:" not in content:
            print(f"FAIL: Content missing FILE header. Got: {content[:50]}...")
            return False

        # Check if it looks like a full file (heuristic: lengthy, or starts with comments/properties)
        if len(content) < 50:
            print("WARN: Content seems very short for a full code file.")

    print("PASS: Code strategy looks correct.")
    return True

def test_mql5_dev_strategy(adapter):
    print("\n--- TEST 3: MQL5_DEV (Context ID) ---")
    query = "indicator handle"
    results = adapter.search_full(query, "MQL5_DEV", top_k=3)

    if not results:
        print("FAIL: No results found for MQL5_DEV.")
        return False

    for res in results:
        print(f"Hit: {res['filename']}")
        # Should NOT have (Windowed Context: ...) in filename for this strategy
        if "(Windowed Context:" in res['filename']:
            print("FAIL: MQL5_DEV is using Windowed Strategy unexpectedly.")
            return False

    print("PASS: MQL5_DEV strategy looks correct.")
    return True

if __name__ == "__main__":
    adapter = RAGAdapter()

    p1 = test_theory_strategy(adapter)
    p2 = test_code_strategy(adapter)
    p3 = test_mql5_dev_strategy(adapter)

    if p1 and p2 and p3:
        print("\n=== ALL TESTS PASSED ===")
        sys.exit(0)
    else:
        print("\n=== SOME TESTS FAILED ===")
        sys.exit(1)
