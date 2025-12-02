#!/usr/bin/env python
import os
import sys
import time
import subprocess
import datetime

PID_FILE = "factory.pid"
CHECK_INTERVAL = 60 # masodperc
ALERT_DIR = "ALERTS"

def is_running(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True

def create_alert(msg):
    if not os.path.exists(ALERT_DIR):
        os.makedirs(ALERT_DIR)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    alert_file = os.path.join(ALERT_DIR, f"RESTART_{timestamp}.log")

    with open(alert_file, "w") as f:
        f.write(f"WATCHDOG ALERT: {msg}\n")
        f.write(f"Time: {timestamp}\n")

    print(f"[WATCHDOG]: ALERT letrehozva: {alert_file}")

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
            msg = "A Manager leallt! Ujrainditas..."
            print(f"[WATCHDOG]: {msg}")
            create_alert(msg)
            subprocess.run([sys.executable, "start_factory.py"])
        else:
            pass

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
