import os
import sys
import time
import subprocess

def log(msg):
    with open("dom_headless_test.log", "a") as f:
        f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    print(msg)

# Biztosítsuk a tiszta környezetet a futás előtt
os.system("pkill -f xvfb-run")
os.system("pkill -f dom_app_pyqt.py")

log("Headless DOM Teszt indul (1x sebességen)...")

try:
    # Futtatás virtuális framebufferben
    process = subprocess.Popen(["xvfb-run", "-a", "python3", "dom_app_pyqt.py"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Várunk 15 másodpercet (hogy a GUI biztosan olvasson jópár ticket az indulás után)
    time.sleep(15)

    if process.poll() is not None: # Ha azonnal kilépett
        stdout, stderr = process.communicate()
        log(f"HIBA: A DOM Monitor azonnal összeomlott. Kilépési kód: {process.returncode}")
        log(f"STDERR: {stderr}")
    else:
        log("SIKER: A DOM Monitor stabilan fut 15 másodperc után.")
        process.terminate()
        stdout, stderr = process.communicate()
        log(f"Befejezés. STDOUT statisztika a konzolról:\n{stdout}")
        if stderr:
            log(f"STDERR a futás alatt:\n{stderr}")

except Exception as e:
    log(f"KIVÉTEL: {e}")
finally:
    # Brutális kényszerleállítás minden háttérszálra, hogy a user gépén szabad maradjon a pálya
    os.system("pkill -f xvfb-run")
    os.system("pkill -f dom_app_pyqt.py")
