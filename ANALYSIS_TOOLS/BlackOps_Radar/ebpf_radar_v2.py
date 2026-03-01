#!/usr/bin/python3
# -*- coding: utf-8 -*-
# BlackOps eBPF Radar v2.0 (Dynamic PID Tracking)
# Passive out-of-band monitoring of outbound WINE/MT5 network traffic.
# Automatically tracks process restarts without needing to reload the eBPF program.

import sys
import os
import time
import threading
import psutil
from bcc import BPF
import ctypes as ct
import socket
import struct
import logging
from datetime import datetime

# --- Setup Logging ---
# Ensure logs are saved in the same directory as the script, regardless of execution path
script_dir = os.path.dirname(os.path.abspath(__file__))
log_filename = os.path.join(script_dir, f"radar_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    handlers=[
        logging.FileHandler(log_filename),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# --- 1. Auto-PID Finder ---
def get_target_pids(process_name="terminal64.exe"):
    """
    Keresi a megadott nevű folyamat PID-jeit a rendszeren.
    WINE alatt futó folyamatoknál a linuxos host PID-t kapjuk meg.
    """
    pids = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmd = " ".join(proc.info.get('cmdline', []) or [])
            if process_name.lower() in cmd.lower() or process_name.lower() in (proc.info.get('name') or "").lower():
                pids.append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return pids

# --- 2. eBPF C Kód (Kernel Tér) ---
# A V2-ben a BPF_HASH-t használjuk. A Python folyamatosan frissíti ezt a táblázatot
# az aktuálisan futó MT5 PID-kkel. A kernel minden TCP küldésnél megnézi,
# hogy a küldő PID-je benne van-e ebben a hash map-ben.
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>

BPF_PERF_OUTPUT(ipv4_send_events);

// Dinamikus PID tábla (kulcs: PID, érték: 1)
BPF_HASH(target_pids, u32, u32);

struct data_t {
    u32 pid;
    u64 ts;         // Timestamp
    u32 saddr;      // Source IP
    u32 daddr;      // Destination IP
    u16 lport;      // Source Port
    u16 dport;      // Destination Port
    u32 size;       // Payload size
    char comm[TASK_COMM_LEN]; // Process name
};

// Kprobe a kimenő TCP hívásokra
int kprobe__tcp_sendmsg(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size)
{
    u32 pid = bpf_get_current_pid_tgid() >> 32;

    // Megnézzük, hogy a jelenlegi PID benne van-e a figyelt listában
    u32 *is_tracked = target_pids.lookup(&pid);
    if (is_tracked == NULL) {
        return 0; // Ha nincs a listában, ignoráljuk
    }

    // Csak IPv4 csomagokat dolgozunk fel a példában
    u16 family = sk->__sk_common.skc_family;
    if (family != AF_INET) {
        return 0;
    }

    struct data_t data = {};
    data.pid = pid;
    data.ts = bpf_ktime_get_ns();
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    // Címek kinyerése a kernel socket struktúrából
    data.saddr = sk->__sk_common.skc_rcv_saddr;
    data.daddr = sk->__sk_common.skc_daddr;
    data.lport = sk->__sk_common.skc_num;
    data.dport = sk->__sk_common.skc_dport;

    data.size = (u32)size;

    ipv4_send_events.perf_submit(ctx, &data, sizeof(data));

    return 0;
}
"""

# --- 3. Python Event Handler (User Tér) ---

def inet_ntoa(addr):
    return socket.inet_ntoa(struct.pack("I", addr))

def print_ipv4_event(cpu, data, size):
    class Data(ct.Structure):
        _fields_ = [
            ("pid", ct.c_uint32),
            ("ts", ct.c_uint64),
            ("saddr", ct.c_uint32),
            ("daddr", ct.c_uint32),
            ("lport", ct.c_uint16),
            ("dport", ct.c_uint16),
            ("size", ct.c_uint32),
            ("comm", ct.c_char * 16)
        ]

    event = ct.cast(data, ct.POINTER(Data)).contents
    dport = socket.ntohs(event.dport)

    log_msg = (f"[{event.ts}] {event.comm.decode('utf-8', 'replace')} (PID: {event.pid}) "
               f"TCP SEND -> {inet_ntoa(event.daddr)}:{dport} "
               f"[Size: {event.size} bytes]")
    logger.info(log_msg)

# --- 4. Dinamikus PID Frissítő Szál (Daemon Thread) ---
def update_pid_map(bpf_obj, target_process):
    """
    Ez a funkció a háttérben fut. Folyamatosan keresi az adott nevű processzeket,
    és frissíti a Kernelben lévő BPF_HASH map-et. Ha a WINE újraindul, automatikusan
    felveszi az új PID-t.
    """
    tracked_pids = set()
    while True:
        try:
            current_pids = set(get_target_pids(target_process))

            # Új PID-k hozzáadása a kernel map-hez
            new_pids = current_pids - tracked_pids
            for pid in new_pids:
                bpf_obj["target_pids"][ct.c_uint32(pid)] = ct.c_uint32(1)
                logger.info(f"\n[+] 🔄 RADAR TRACKING NEW PID: {pid} ({target_process})")

            # Régi (már nem futó) PID-k törlése a kernel map-ből (opcionális tisztítás)
            dead_pids = tracked_pids - current_pids
            for pid in dead_pids:
                try:
                    del bpf_obj["target_pids"][ct.c_uint32(pid)]
                    logger.info(f"\n[-] 🛑 RADAR DROPPED DEAD PID: {pid} ({target_process})")
                except KeyError:
                    pass

            tracked_pids = current_pids

        except Exception as e:
            logger.error(f"Hiba a PID frissítése közben: {e}")

        time.sleep(2) # 2 másodpercenként ellenőrzi a processzeket

# --- 5. Főprogram ---
if __name__ == "__main__":
    if os.geteuid() != 0:
        logger.error("❌ Hiba: Az eBPF szkriptek futtatásához root (sudo) jogosultság szükséges!")
        sys.exit(1)

    target_process = "terminal64.exe"

    logger.info(f"⚙️ eBPF (BCC) kód fordítása és betöltése a Linux Kernelbe...")
    try:
        b = BPF(text=bpf_text)
    except Exception as e:
        logger.error(f"❌ Fordítási hiba: {e}")
        sys.exit(1)

    # Elindítjuk a háttérszálat, ami folyamatosan frissíti a BPF_HASH map-et
    logger.info(f"🔍 Dinamikus PID követés indítása a(z) '{target_process}' folyamathoz...")
    pid_thread = threading.Thread(target=update_pid_map, args=(b, target_process))
    pid_thread.daemon = True # Így automatikusan leáll, ha a főprogram kilép
    pid_thread.start()

    logger.info(f"📡 RADAR AKTÍV. Figyeljük a kifelé menő TCP telemetriát (Csomagméretek). Naplózás fájlba: {log_filename}")
    logger.info("   Nyomj Ctrl+C-t a leállításhoz.\n")
    logger.info(f"{'TIMESTAMP':<20} {'COMM':<15} {'PID':<8} {'DESTINATION':<22} {'PAYLOAD SIZE'}")
    logger.info("-" * 80)

    b["ipv4_send_events"].open_perf_buffer(print_ipv4_event)

    try:
        while True:
            b.perf_buffer_poll()
    except KeyboardInterrupt:
        logger.info("\n🛑 RADAR LEÁLLÍTVA. Kapcsolat bontva a Kernellel.")
        sys.exit(0)
