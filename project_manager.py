#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import os
import json
import datetime
import time
import shutil
import subprocess

# --- KONFIGURACIO ---
INBOX_DIR = "tasks_inbox"
ARCHIVE_DIR = "tasks_archive"
REPORT_DIR = "project_reports"
STOP_FILE = "STOP_MANAGER"
POLL_INTERVAL = 5
BATCH_COOLDOWN = 60

class ProjectManager:
    def __init__(self):
        pass

    def run_daemon(self):
        print(f"[MŰSZAKVEZETŐ]: Szolgálatba léptem (Batch Mode). Figyelem a '{INBOX_DIR}' mappát.")

        while True:
            if os.path.exists(STOP_FILE):
                print("[MŰSZAKVEZETŐ]: Leállítási parancs érkezett. Műszak vége.")
                break

            task_files = [f for f in os.listdir(INBOX_DIR) if f.endswith('.json')]
            task_files.sort()

            if task_files:
                current_file = task_files[0]
                full_path = os.path.join(INBOX_DIR, current_file)

                print(f"[MŰSZAKVEZETŐ]: Új megbízás érkezett: {current_file}")

                try:
                    self.execute_project(full_path)

                    if os.path.exists(full_path):
                        shutil.move(full_path, os.path.join(ARCHIVE_DIR, current_file))
                        print(f"[MŰSZAKVEZETŐ]: Megbízás teljesítve. Akták archiválva.")

                except Exception as e:
                    print(f"[MŰSZAKVEZETŐ]: KRITIKUS HIBA a '{current_file}' feldolgozása közben: {e}")
                    if os.path.exists(full_path):
                        error_dest = os.path.join(ARCHIVE_DIR, current_file + ".error")
                        shutil.move(full_path, error_dest)

            time.sleep(POLL_INTERVAL)

    def execute_project(self, project_file):
        with open(project_file, 'r', encoding='utf-8') as f:
            project_data = json.load(f)

        project_name = project_data.get("project_name", "Névtelen_Projekt")
        tasks = project_data.get("tasks", [])

        # --- PROGRESS KEZELES ---
        progress_file = project_file + ".progress"
        completed_ids = []
        report_path = ""
        current_task_id = None
        retry_count = 0

        if os.path.exists(progress_file):
            try:
                with open(progress_file, 'r') as pf:
                    prog_data = json.load(pf)
                    completed_ids = prog_data.get("completed_ids", [])
                    report_path = prog_data.get("report_path", "")
                    current_task_id = prog_data.get("current_task_id")
                    retry_count = prog_data.get("retry_count", 0)
                    print(f"[MŰSZAKVEZETŐ]: Korábbi állapot helyreállítva. Kész: {completed_ids}, Hiba ennél: {current_task_id} (Retry: {retry_count})")
            except: pass

        if not report_path or not os.path.exists(report_path):
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            report_filename = f"{project_name.replace(' ', '_')}_{timestamp}.txt"
            report_path = os.path.join(REPORT_DIR, report_filename)
            self.log(f"--- PROJEKT START (Batch Mode): {project_name} ---", report_path, mode='w')
            self.log(f"Időpont: {timestamp}", report_path)
        else:
            self.log(f"\n--- PROJEKT FOLYTATÁSA (Resume) ---", report_path, mode='a')

        # --- FELADATOK ---
        for i, task in enumerate(tasks):
            if os.path.exists(STOP_FILE):
                self.log("\n[MŰSZAKVEZETŐ]: Vészleállás!", report_path)
                return

            task_id = task.get("id", i+1)
            
            if task_id in completed_ids:
                print(f"[MŰSZAKVEZETŐ]: Feladat {task_id} kész. Kihagyás.")
                continue

            # Crash Detection & Skip Logic
            if task_id == current_task_id:
                if retry_count >= 3:
                    self.log(f"[MŰSZAKVEZETŐ]: FIGYELEM! A feladat {task_id} túl sokszor okozott leállást. KIHAGYÁS.", report_path)
                    completed_ids.append(task_id)
                    with open(progress_file, 'w') as pf:
                        json.dump({"completed_ids": completed_ids, "report_path": report_path, "current_task_id": None, "retry_count": 0}, pf)
                    continue
                else:
                    print(f"[MŰSZAKVEZETŐ]: Újrapróbálkozás ({retry_count + 1}/3)...")

            # Progress mentese (Indulas elott)
            with open(progress_file, 'w') as pf:
                json.dump({
                    "completed_ids": completed_ids,
                    "report_path": report_path,
                    "current_task_id": task_id,
                    "retry_count": retry_count + 1 if task_id == current_task_id else 1
                }, pf)

            description = task.get("description", "Nincs leírás")
            self.log(f"\n=== FELADAT {task_id}: {description} ===", report_path)

            if task.get("type") == "research":
                query = task.get("query")
                scope = task.get("scope") or "KOD"
                depth = task.get("depth", 0)

                self.log(f"[MŰSZAKVEZETŐ]: Kutató indítása (Subprocess)... Query: '{query}'", report_path)

                cmd = [sys.executable, "kutato.py",
                       "--query", query,
                       "--scope", scope,
                       "--depth", str(depth),
                       "--output", "json"]

                try:
                    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)

                    if proc.returncode == 0:
                        try:
                            results = json.loads(proc.stdout)
                            self.log(f"[MŰSZAKVEZETŐ]: Eredmény beérkezett ({len(results)} találat).", report_path)
                            self.write_results(results, report_path)
                        except json.JSONDecodeError:
                            self.log(f"[MŰSZAKVEZETŐ]: HIBA - A kutató nem JSON-t küldött!\nRaw: {proc.stdout[:200]}...", report_path)
                    else:
                        self.log(f"[MŰSZAKVEZETŐ]: HIBA - A kutató hibával tért vissza (Code: {proc.returncode})\nStderr: {proc.stderr}", report_path)

                except subprocess.TimeoutExpired:
                     self.log(f"[MŰSZAKVEZETŐ]: HIBA - A kutatás túllépte az időkeretet (Timeout)!", report_path)

            elif task.get("type") == "manual":
                self.log(f"[MANUÁLIS]: {task.get('instruction')}", report_path)

            # --- PROGRESS MENTESE (SIKER) ---
            completed_ids.append(task_id)
            with open(progress_file, 'w') as pf:
                json.dump({
                    "completed_ids": completed_ids,
                    "report_path": report_path,
                    "current_task_id": None,
                    "retry_count": 0
                }, pf)

            if i < len(tasks) - 1:
                print(f"[MŰSZAKVEZETŐ]: Pihenőidő ({BATCH_COOLDOWN} mp)...")
                time.sleep(BATCH_COOLDOWN)

        self.log("\n--- PROJEKT VÉGE ---", report_path)
        if os.path.exists(progress_file): os.remove(progress_file)

    def write_results(self, results, report_path):
        with open(report_path, "a", encoding="utf-8") as f:
            for res in results:
                fname = res.get('filename') or res.get('doc', {}).get('final_filename') or '?'
                stype = res.get('type') or res.get('doc', {}).get('source_type') or '?'
                score = res.get('score', 0)
                content = res.get('content') or res.get('doc', {}).get('content') or ''

                f.write(f"\n> TALÁLAT (Score: {score:.2f}) [{stype}] {fname}\n")
                f.write("-" * 80 + "\n")
                f.write(content[:2000])
                f.write("\n" + "=" * 80 + "\n")
            f.flush()
            os.fsync(f.fileno())

    def log(self, message, report_path, mode='a'):
        print(message)
        with open(report_path, mode, encoding="utf-8") as f:
            f.write(message + "\n")
            f.flush()
            os.fsync(f.fileno())

if __name__ == "__main__":
    for d in [INBOX_DIR, ARCHIVE_DIR, REPORT_DIR]:
        if not os.path.exists(d): os.makedirs(d)
    manager = ProjectManager()
    manager.run_daemon()
