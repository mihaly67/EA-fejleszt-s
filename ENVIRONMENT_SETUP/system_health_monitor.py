import os
import time

def check_health():
    """
    Rövid Health Check script, ami megnézi:
    1. Él-e a szívverés (Keep-Alive Daemon)?
    2. Mikor írt utoljára az Agent a memóriába (agent_memory.jsonl)?
    """
    print("🩺 [AGENT SYSTEM HEALTH CHECK] Indítása...\n")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    heartbeat_file = os.path.join(script_dir, "skills", ".agent_heartbeat")
    memory_file = os.path.join(os.path.dirname(script_dir), "Knowledge_Base", "agent_memory.jsonl")

    current_time = time.time()

    # 1. Daemon ellenőrzés
    if os.path.exists(heartbeat_file):
        hb_age = current_time - os.path.getmtime(heartbeat_file)
        # Mivel a daemon 10 percenként (600mp) pulzál, a tűréshatárt 15 percre (900mp) állítjuk
        if hb_age < 900:
            print(f"✅ DAEMON: A Keep-Alive Daemon aktív (Utolsó szívverés: {int(hb_age)} mp-e).")
        else:
            print(f"❌ DAEMON: A Keep-Alive Daemon HALOTT vagy LEFAGYOTT! (Utolsó szívverés: {int(hb_age)} mp-e).")
            print("👉 Indítsd újra a `restore_envSWAT4.py` szkriptet!")
    else:
        print("❌ DAEMON: A `.agent_heartbeat` fájl nem létezik. A Daemon nem fut!")

    print("-" * 50)

    # 2. Memória frissesség ellenőrzése
    if os.path.exists(memory_file):
        mem_age = current_time - os.path.getmtime(memory_file)
        minutes = int(mem_age / 60)

        if minutes < 5:
            print(f"✅ MEMÓRIA: Friss és aktív. (Utolsó írás: {minutes} perce).")
        elif minutes < 15:
            print(f"⚠️ MEMÓRIA: Figyelem! {minutes} perce nem történt kontextus írás.")
            print("👉 Javasolt egy `Condense` sűrítés futtatása!")
        else:
            print(f"🚨 MEMÓRIA: KRITIKUS! {minutes} perce (több mint 15 perce) az Agent elfelejtett emlékezni!")
            print("👉 KÖTELEZŐ Futtatni az `agent_memory_manager.py --action write` parancsot!")
    else:
        print("❌ MEMÓRIA: Az `agent_memory.jsonl` fájl nem létezik. Az Agent emlékezetkiesésben szenved!")

    print("\n🩺 Health Check befejezve.")

if __name__ == "__main__":
    check_health()
