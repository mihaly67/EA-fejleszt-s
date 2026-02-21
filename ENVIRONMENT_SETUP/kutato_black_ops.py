#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# kutato_black_ops.py
# Kifejezetten a Black Ops / Frida / API Hooking témák kutatására optimalizálva.

import sys
import json
import os
import argparse
import time

# === KONFIGURÁCIÓ ===
# A tudásbázis fájl helye
BLACK_OPS_DB = "Knowledge_Base/Black_Ops/Black_Ops.jsonl"
OUTPUT_FILE = "BLACK_OPS_INTELLIGENCE.json"

# Kulcsszavak, amikre vadászunk (Frida, API Hooking, Anti-Cheat)
TARGET_KEYWORDS = [
    "frida", "hook", "interceptor", "attach", "spawn",
    "user32.dll", "kernel32.dll",
    "GetCursorPos", "SetCursorPos", "GetAsyncKeyState", "GetForegroundWindow",
    "anti-cheat", "detection", "debugger", "isdebuggerpresent",
    "memory", "inject", "payload", "javascript", "python"
]

def search_black_ops(query=None):
    print(f"🕵️ Black Ops Kutatás Indítása...")

    if not os.path.exists(BLACK_OPS_DB):
        print(f"❌ HIBA: Nem található a fájl: {BLACK_OPS_DB}")
        return []

    results = []
    line_count = 0
    match_count = 0

    try:
        with open(BLACK_OPS_DB, 'r', encoding='utf-8') as f:
            for line in f:
                line_count += 1
                try:
                    entry = json.loads(line)
                    code = entry.get("code", "").lower()
                    filename = entry.get("filename", "").lower()

                    # Ha van specifikus query, arra szűrünk
                    if query and query.lower() not in code and query.lower() not in filename:
                        continue

                    # Kulcsszó keresés
                    found_keywords = [kw for kw in TARGET_KEYWORDS if kw in code or kw in filename]

                    if found_keywords:
                        match_count += 1
                        results.append({
                            "file": entry.get("filename"),
                            "keywords": found_keywords,
                            "snippet": entry.get("code")[:500] + "...", # Rövidített tartalom
                            "full_content": entry.get("code") # Teljes tartalom elemzéshez
                        })
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        print(f"❌ Hiba olvasás közben: {e}")

    print(f"✅ Kutatás kész. {match_count} releváns találat {line_count} sorból.")
    return results

def save_results(results):
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2)
    print(f"📄 Eredmények mentve: {OUTPUT_FILE}")

def main():
    parser = argparse.ArgumentParser(description="Black Ops Intelligence Tool")
    parser.add_argument("--query", help="Opcionális specifikus keresőszó (pl. 'GetCursorPos')")
    args = parser.parse_args()

    results = search_black_ops(args.query)
    save_results(results)

if __name__ == "__main__":
    main()
