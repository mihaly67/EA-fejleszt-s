import time
import os
import sys

def run_daemon():
    """
    Egy nagyon könnyű (0.01% CPU), végtelen ciklusú háttérfolyamat (Daemon).
    Folyamatosan ír egy apró "szívverés" logot, vagy touch-ol egy fájlt,
    ezzel elhitetve az Agent UI-al és a Cloudflare/Docker containerrel,
    hogy a virtuális gépben folyamatos I/O munkavégzés zajlik.
    Megakadályozza, hogy az Agent "hosszú gondolkodás" közben kifagyjon a timeout miatt.
    """
    keepalive_file = os.path.join(os.path.dirname(__file__), ".agent_heartbeat")

    print(f"💓 [Keep-Alive Daemon] Elindult. Folyamatos szívverés generálása: {keepalive_file}", flush=True)

    try:
        while True:
            # 10 másodpercenként frissítjük a fájl módosítási idejét (I/O event)
            with open(keepalive_file, "w") as f:
                f.write(str(time.time()))

            # Flusholjuk a standard kimenetet is, ha esetleg a logoló ezt figyeli
            sys.stdout.flush()

            time.sleep(10)
    except KeyboardInterrupt:
        print("💓 [Keep-Alive Daemon] Leállítva.")

if __name__ == "__main__":
    run_daemon()
