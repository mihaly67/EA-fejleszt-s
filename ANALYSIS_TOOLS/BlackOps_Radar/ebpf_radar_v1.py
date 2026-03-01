#!/usr/bin/python3
# -*- coding: utf-8 -*-
# BlackOps eBPF Radar v1.0
# Passive out-of-band monitoring of outbound WINE/MT5 network traffic from the Linux Host.
# Requires: sudo, bcc (BPF Compiler Collection), python3-psutil

import sys
import os
import psutil
from bcc import BPF
import ctypes as ct

# --- 1. Auto-PID Finder ---
def get_target_pids(process_name="terminal64.exe"):
    """
    Keresi a megadott nevű folyamat PID-jeit a rendszeren.
    WINE alatt futó folyamatoknál a linuxos host PID-t kapjuk meg.
    Gyakori nevek: terminal64.exe (MT5), wineserver.
    """
    pids = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            # A cmdline-ban vagy a process névben is szerepelhet a ".exe" WINE esetén
            cmd = " ".join(proc.info.get('cmdline', []) or [])
            if process_name.lower() in cmd.lower() or process_name.lower() in (proc.info.get('name') or "").lower():
                pids.append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return pids

# --- 2. eBPF C Kód (Kernel Tér) ---
# A kód kprobe-ot használ a tcp_sendmsg függvényen, ami minden kimenő TCP csomag
# küldésekor lefut. Megvizsgálja a hívó PID-t, és ha egyezik a célponttal,
# elküldi az adatokat (méret, cél IP, port) a user-space-be egy PERF_OUTPUT map-en keresztül.
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>

BPF_PERF_OUTPUT(ipv4_send_events);

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

    // FILTER_PID lesz kicserélve a Python szkript által fordítás előtt
    if (pid != FILTER_PID) {
        return 0;
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
    // Figyelem: A kernelben a dport hálózati bájtsorrendben (big endian) van tárolva.
    // Ezt a Python oldalon alakítjuk át (ntohs).

    data.size = (u32)size;

    ipv4_send_events.perf_submit(ctx, &data, sizeof(data));

    return 0;
}
"""

# --- 3. Python Event Handler (User Tér) ---
import socket
import struct

def inet_ntoa(addr):
    """32 bites egész IP cím konvertálása olvasható string formátumba."""
    return socket.inet_ntoa(struct.pack("I", addr))

def print_ipv4_event(cpu, data, size):
    """Callback függvény, ami meghívódik minden kernelből érkező eseménynél."""
    # A BPF kód struktúrájának megfelelő Python ctypes osztály
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

    # Destination port konverzió hálózati bájtsorrendből (ntohs egyenértékű)
    dport = socket.ntohs(event.dport)

    # Formázott kiírás: [Időbélyeg] Folyamat (PID) -> Cél_IP:Port [Méret Bájt]
    print(f"[{event.ts}] {event.comm.decode('utf-8', 'replace')} (PID: {event.pid}) "
          f"TCP SEND -> {inet_ntoa(event.daddr)}:{dport} "
          f"[Size: {event.size} bytes]")

# --- 4. Főprogram ---
if __name__ == "__main__":
    if os.geteuid() != 0:
        print("❌ Hiba: Az eBPF szkriptek futtatásához root (sudo) jogosultság szükséges!")
        sys.exit(1)

    target_process = "terminal64.exe" # Az MT5 alapértelmezett folyamatneve
    print(f"🔍 Keresés a(z) '{target_process}' folyamat PID-jére a rendszeren...")

    pids = get_target_pids(target_process)

    if not pids:
        print(f"⚠️ Nem található futó '{target_process}' WINE folyamat!")
        print("   Tipp: Próbáld meg a 'wineserver' nevet, vagy add meg manuálisan a kódban a PID-t.")
        sys.exit(1)

    # Egyszerűség kedvéért az első talált PID-re akasztjuk rá a figyelést
    # WINE esetén több terminal64.exe is futhat, ilyenkor összetettebb szűrésre lehet szükség
    target_pid = pids[0]
    print(f"✅ Megtalálva! PID: {target_pid}. Több találat esetén: {pids}")

    # Behelyettesítjük a PID-t a C kódba
    bpf_source = bpf_text.replace("FILTER_PID", str(target_pid))

    print(f"⚙️ eBPF (BCC) kód fordítása és betöltése a Linux Kernelbe...")
    try:
        b = BPF(text=bpf_source)
    except Exception as e:
        print(f"❌ Fordítási hiba (Lehet, hogy hiányoznak a linux-headers csomagok a hoston): {e}")
        sys.exit(1)

    print("📡 RADAR AKTÍV. Figyeljük a kifelé menő TCP telemetriát (Csomagméretek).")
    print("   Nyomj Ctrl+C-t a leállításhoz.\n")
    print(f"{'TIMESTAMP':<20} {'COMM':<15} {'PID':<8} {'DESTINATION':<22} {'PAYLOAD SIZE'}")
    print("-" * 80)

    # Feliratkozunk a perf puffer eseményekre
    b["ipv4_send_events"].open_perf_buffer(print_ipv4_event)

    try:
        # Végtelen ciklus az események olvasására
        while True:
            b.perf_buffer_poll()
    except KeyboardInterrupt:
        print("\n🛑 RADAR LEÁLLÍTVA. Kapcsolat bontva a Kernellel.")
        sys.exit(0)
