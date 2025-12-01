#!/usr/bin/env python
import os
import sys
import time
import subprocess

PID_FILE = "factory.pid"
CHECK_INTERVAL = 60 # masodperc

def is_running(pid):
    try:
        os.kill(pid, 0) # Check signal
    except OSError:
        return False

    # Opcionalis: Ellenorizni a folyamat nevet is (/proc/pid/cmdline)
    # De a sandboxban egyszeru check is eleg
    return True

def main():
    print("[WATCHDOG]: Figyelo szolgalat inditasa...")
    while True:
        running = False
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                if is_running(pid):
                    running = True
            except:
                pass

        if not running:
            print(f"[WATCHDOG]: A Manager nem fut! Ujrainditas...")
            subprocess.run([sys.executable, "start_factory.py"])
        else:
            # print("[WATCHDOG]: A Manager fut.")
            pass

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
