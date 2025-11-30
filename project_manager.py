#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import os
import json
import datetime
import kutato_ugynok_v3 as expert

# --- KONFIGURACIO ---
LOG_FILE = "PROJECT_LOG.md"
REPORT_FILE = "PROJECT_REPORT.md"

def log_project(msg):
    """Naplozas konzolra es fajlba."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{timestamp}] [MANAGER]: {msg}"
    print(entry)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(entry + "\n")

def execute_research_task(query, docs, model):
    """Kutatasi feladat vegrehajtasa a Szakertovel."""
    log_project(f"Kutatas inditasa: '{query}'")
    
    # A kutato ugynok rekurziv keresojet hasznaljuk
    results = expert.recursive_search(query, docs, model)
    
    # Eredmenyek rendezese
    results.sort(key=lambda x: (x['depth'], -x['score']))
    
    # Jelentes irasa
    with open(REPORT_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n## Kutatási Eredmény: {query}\n")
        f.write(f"*(Talalatok szama: {len(results)})*\n\n")
        
        seen = set()
        count = 0
        for res in results:
            content = res['doc'].get('content') or ""
            sig = content[:100]
            if sig in seen: continue
            seen.add(sig)
            
            fname = res['doc'].get('final_filename') or '?'
            stype = res['doc'].get('source_type', 'RAG')
            
            f.write(f"### [{stype}] {fname} (Score: {res['score']:.2f})\n")
            f.write(f"**Kontextus:** {res['query']}\n")
            f.write("```cpp\n")
            f.write(content[:1000] + "...\n")
            f.write("```\n\n")
            
            count += 1
            if count >= 5: break # Max 5 talalat a jelentesbe
            
    log_project("Kutatas kesz. Eredmeny a jelentésfájlban.")

def execute_code_analysis(file_path):
    """Meglevo kod elemzese."""
    log_project(f"Kod elemzese: {file_path}")
    if not os.path.exists(file_path):
        log_project(f"HIBA: A fajl nem talalhato: {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    lines = content.split('\n')
    functions = [l for l in lines if "void" in l or "int" in l or "double" in l]
    
    with open(REPORT_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n## Kód Elemzés: {file_path}\n")
        f.write(f"- Sorok szama: {len(lines)}\n")
        f.write(f"- Becsült fuggvenyek szama: {len(functions)}\n")
        f.write("\n")

def run_project(tasks):
    # Inicializalas
    if os.path.exists(REPORT_FILE): os.remove(REPORT_FILE)
    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write("# PROJEKT JELENTÉS (Jules Manager)\n\n")

    log_project("--- UJ PROJEKT INDITASA ---")
    
    # 1. Eroforrasok betoltese (Csak egyszer!)
    try:
        docs, model = expert.load_resources()
        log_project("RAG Tudasbazis betoltve.")
    except Exception as e:
        log_project(f"KRITIKUS HIBA a betoltesnel: {e}")
        return

    # 2. Feladatok vegrehajtasa
    for i, task in enumerate(tasks):
        log_project(f"Feladat {i+1}/{len(tasks)} feldolgozasa...")
        
        t_type = task.get('type', 'research')
        
        if t_type == 'research':
            execute_research_task(task['query'], docs, model)
        elif t_type == 'analysis':
            execute_code_analysis(task['file'])
        elif t_type == 'manual':
            log_project(f"MANUALIS UTASITAS: {task['instruction']}")
            with open(REPORT_FILE, "a", encoding="utf-8") as f:
                f.write(f"\n## Manuális Teendő\n{task['instruction']}\n")

    log_project("--- PROJEKT BEFEJEZVE ---")
    print(f"\nTELJES JELENTES: {os.path.abspath(REPORT_FILE)}")

if __name__ == "__main__":
    # Alapertelmezett feladatlista (ha nincs argumentum)
    default_tasks = [
        {"type": "research", "query": "MQL5 ChartIndicatorAdd subwindow overlay"},
        {"type": "research", "query": "MQL5 CAppDialog button color hex codes"}
    ]
    
    tasks = default_tasks
    
    # Ha parancssorbol kap JSON-t, azt hasznalja
    if len(sys.argv) > 1:
        try:
            input_json = sys.argv[1]
            # Ha fajlnevet kapott
            if input_json.endswith('.json') and os.path.exists(input_json):
                with open(input_json, 'r') as f:
                    tasks = json.load(f)
            else:
                # Ha raw json stringet kapott
                tasks = json.loads(input_json)
        except:
            print("Hiba a bemeneti JSON feldolgozasakor. Az alapertelmezett listat hasznalom.")

    run_project(tasks)
