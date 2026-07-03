import os
import sys
import time
import subprocess
from PyQt5.QtWidgets import QApplication

def log(msg):
    with open("dom_headless_test.log", "a") as f:
        f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    print(msg)

log("Headless DOM Teszt indul...")

try:
    # Futtatás virtuális framebufferben
    process = subprocess.Popen(["xvfb-run", "-a", "python3", "dom_app_pyqt.py"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    time.sleep(5) # Várjunk, amíg betölt a GUI és a CSV player

    if process.poll() is not None: # Ha már kilépett, akkor hiba van
        stdout, stderr = process.communicate()
        log(f"HIBA: A DOM Monitor azonnal összeomlott. Kilépési kód: {process.returncode}")
        log(f"STDOUT: {stdout}")
        log(f"STDERR: {stderr}")
    else:
        log("SIKER: A DOM Monitor stabilan fut 5 másodperc után.")
        process.terminate()
        log("Processz leállítva.")

except Exception as e:
    log(f"KIVÉTEL: {e}")
