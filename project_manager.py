#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import os
import json
import datetime
import time
import shutil
import kutato  # A Munkas
from kutato import WorkerAgent

# --- KONFIGURACIO ---
INBOX_DIR = "tasks_inbox"
ARCHIVE_DIR = "tasks_archive"
REPORT_DIR = "project_reports"
STOP_FILE = "STOP_MANAGER"
POLL_INTERVAL = 2  # Masodperc

class ProjectManager:
    def __init__(self):
        self.worker = WorkerAgent()
        self.is_loaded = False

    def ensure_resources(self):
        if not self.is_loaded:
            print("[MŰSZAKVEZETŐ]: Munkások és erőforrások inicializálása...")
            self.worker.load_resources()
            self.is_loaded = True
            print("[MŰSZAKVEZETŐ]: A gyár üzemkész.")

    def run_daemon(self):
        print(f"[MŰSZAKVEZETŐ]: Szolgálatba léptem. Figyelem a '{INBOX_DIR}' mappát.")
        self.ensure_resources()

        while True:
            if os.path.exists(STOP_FILE):
                print("[MŰSZAKVEZETŐ]: Leállítási parancs érkezett. Műszak vége.")
                break

            # 1. Bejovo feladatok keresese
            task_files = [f for f in os.listdir(INBOX_DIR) if f.endswith('.json')]
            task_files.sort() # Sorbarendezes (FIFO)

            if task_files:
                current_file = task_files[0]
                full_path = os.path.join(INBOX_DIR, current_file)

                print(f"[MŰSZAKVEZETŐ]: Új megbízás érkezett: {current_file}")

                try:
                    self.execute_project(full_path)

                    # Sikeres vegrehajtas utan archivalas
                    shutil.move(full_path, os.path.join(ARCHIVE_DIR, current_file))
                    print(f"[MŰSZAKVEZETŐ]: Megbízás teljesítve. Akták archiválva.")

                except Exception as e:
                    print(f"[MŰSZAKVEZETŐ]: KRITIKUS HIBA a '{current_file}' feldolgozása közben: {e}")
                    # Hiba eseten is atmozgatjuk, hogy ne blokkolja a sort (vagy .err kiterjesztessel?)
                    error_dest = os.path.join(ARCHIVE_DIR, current_file + ".error")
                    shutil.move(full_path, error_dest)

            # Pihenes a kovetkezo ellenorzesig
            time.sleep(POLL_INTERVAL)

    def execute_project(self, project_file):
        """Egy konkrét projektfájl végrehajtása."""
        with open(project_file, 'r', encoding='utf-8') as f:
            project_data = json.load(f)

        project_name = project_data.get("project_name", "Névtelen_Projekt")
        tasks = project_data.get("tasks", [])

        # Jelentes fajl elokeszitese
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        report_filename = f"{project_name.replace(' ', '_')}_{timestamp}.txt"
        report_path = os.path.join(REPORT_DIR, report_filename)

        self.log(f"--- PROJEKT START: {project_name} ---", report_path, mode='w')
        self.log(f"Időpont: {timestamp}", report_path)

        for i, task in enumerate(tasks):
            if os.path.exists(STOP_FILE):
                self.log("\n[MŰSZAKVEZETŐ]: Vészleállás a feladatok közben!", report_path)
                return

            task_id = task.get("id", i+1)
            description = task.get("description", "Nincs leírás")
            
            self.log(f"\n=== FELADAT {task_id}: {description} ===", report_path)
            
            if task.get("type") == "research":
                query = task.get("query")
                scope = task.get("scope") # ELMELET / KOD / None
                depth = task.get("depth", 0)

                self.log(f"[MŰSZAKVEZETŐ]: Kutató kiküldése... (Query: '{query}', Scope: {scope})", report_path)

                # Munkas vegrehajtja
                results = self.worker.search(query, scope=scope, depth=depth)

                self.log(f"[MŰSZAKVEZETŐ]: Jelentés beérkezett ({len(results)} találat).", report_path)
                self.write_results(results, report_path)

            elif task.get("type") == "manual":
                self.log(f"[MANUÁLIS]: {task.get('instruction')}", report_path)

            time.sleep(1) # Rövid szünet

        self.log("\n--- PROJEKT VÉGE ---", report_path)

    def write_results(self, results, report_path):
        with open(report_path, "a", encoding="utf-8") as f:
            for res in results:
                doc = res['doc']
                f.write(f"\n> TALÁLAT (Relevancia: {res['score']:.2f}) [{doc['source_type']}] {doc['final_filename']}\n")
                f.write("-" * 80 + "\n")
                content = (doc.get('content') or "")[:1500]
                f.write(content)
                f.write("\n" + "=" * 80 + "\n")

    def log(self, message, report_path, mode='a'):
        print(message)
        with open(report_path, mode, encoding="utf-8") as f:
            f.write(message + "\n")
            f.flush()
            os.fsync(f.fileno())

if __name__ == "__main__":
    # Konyvtarak ellenorzese
    for d in [INBOX_DIR, ARCHIVE_DIR, REPORT_DIR]:
        if not os.path.exists(d):
            os.makedirs(d)

    manager = ProjectManager()
    manager.run_daemon()
