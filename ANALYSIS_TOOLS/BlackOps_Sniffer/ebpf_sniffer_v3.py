#!/usr/bin/python3
"""
Black Ops Sniffer (Red Team) - eBPF TCP Payload Interceptor
Cél: Az MT5 (terminal64.exe) telemetria, kereskedési események és UI hálózati csomagok
tényleges tartalmának (payload) elfogása a Linux kerneltől (tcp_sendmsg) és azok kategorizált mentése.
Figyelem: A payload valószínűleg TLS titkosított, ezért HexDump/ASCII formátumban mentjük az első 256 byte-ot.
"""
from bcc import BPF
import psutil
import time
import socket
import struct
import threading
import os
import signal
import sys
import datetime

# --- BEÁLLÍTÁSOK ---
PROCESS_NAME = "terminal64.exe"
MAX_PAYLOAD_SIZE = 256  # Hány byte-ot mentsünk le a csomagból elemzésre
LOG_DIR = os.path.dirname(os.path.abspath(__file__))

# Kategóriák naplófájljai
LOG_FILES = {
    "TELEMETRY": os.path.join(LOG_DIR, "TELEMETRY.log"),
    "TRADE": os.path.join(LOG_DIR, "TRADE_EVENTS.log"),
    "UI": os.path.join(LOG_DIR, "MISC_UI_EVENTS.log"),
    "SYSTEM": os.path.join(LOG_DIR, "SYSTEM_HEARTBEAT.log"),
    "UNKNOWN": os.path.join(LOG_DIR, "UNKNOWN_EVENTS.log")
}

def init_logs():
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header = f"--- BLACK OPS SNIFFER STARTED AT {timestamp} ---\n"
    for path in LOG_FILES.values():
        with open(path, "a") as f:
            f.write(header)

def categorize_packet(comm, daddr_str, size):
    """
    Az előzetes RADAR napló alapján csoportosítja a csomagokat.
    """
    comm_lower = comm.lower()
    if "controller" in comm_lower:
        return "TELEMETRY"
    elif "expert" in comm_lower:
        return "TRADE"
    elif "calendar" in comm_lower or "community" in comm_lower or "history" in comm_lower:
        return "UI"
    elif "ioport" in comm_lower or "net dispat" in comm_lower or "main" in comm_lower:
        return "SYSTEM"
    return "UNKNOWN"

def hexdump(src, length=16):
    """Visszaadja a byte tömb HexDump/ASCII reprezentációját."""
    FILTER = ''.join([(len(repr(chr(x))) == 3) and chr(x) or '.' for x in range(256)])
    lines = []
    for c in range(0, len(src), length):
        chars = src[c:c+length]
        hex_str = ' '.join([f"{x:02x}" for x in chars])
        printable = ''.join([FILTER[x] for x in chars])
        lines.append(f"{c:04x}  {hex_str:<{length*3}}  |{printable}|")
    return '\n'.join(lines)


# --- BPF KÓD (C) ---
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>
#include <linux/sched.h>

BPF_HASH(target_pids, u32, u32); // [pid -> 1]

struct data_t {
    u32 pid;
    char comm[TASK_COMM_LEN];
    u32 daddr;
    u16 dport;
    u32 size;
    u8 payload[256]; // Első 256 byte mentése
};

BPF_PERF_OUTPUT(events);

int kprobe__tcp_sendmsg(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;

    u32 *is_target = target_pids.lookup(&pid);
    if (is_target == 0) {
        return 0; // Nem target process
    }

    struct data_t data = {};
    data.pid = pid;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    // IPv4 csak
    u16 family = sk->__sk_common.skc_family;
    if (family != AF_INET) {
        return 0;
    }

    data.daddr = sk->__sk_common.skc_daddr;
    data.dport = sk->__sk_common.skc_dport;
    data.size = size;

    // Payload olvasása az iter-ből
    struct iov_iter *iter = &msg->msg_iter;
    if (iter->iov_offset < iter->count) {
        // bcc bpf_probe_read memóriakorlátai miatt manuálisan csak egy részét másoljuk
        // A msg_iter.iov báziscíme (usermode ptr)
        void *user_ptr = iter->iov->iov_base + iter->iov_offset;

        // Biztonságos olvasás usermode-ból
        u32 copy_size = size;
        if (copy_size > 256) {
            copy_size = 256;
        }
        bpf_probe_read_user(&data.payload, copy_size, user_ptr);
    }

    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
"""

print("⚙️ eBPF kód fordítása és betöltése (Kérlek várj)...")
b = BPF(text=bpf_text)

# --- PYTHON FELDOLGOZÓ (USERSPACE) ---
def print_event(cpu, data, size):
    event = b["events"].event(data)

    # Destination IP és Port
    daddr = socket.inet_ntoa(struct.pack("<I", event.daddr))
    dport = socket.ntohs(event.dport)

    comm = event.comm.decode('utf-8', 'replace').strip()
    category = categorize_packet(comm, daddr, event.size)
    log_file = LOG_FILES.get(category, LOG_FILES["UNKNOWN"])

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    # Payload kivágása a megfelelő méretre (max 256)
    payload_size = min(event.size, MAX_PAYLOAD_SIZE)
    payload_bytes = bytes(event.payload[:payload_size])

    # Konzolos kiírás (rövid)
    print(f"[{category}] {comm} -> {daddr}:{dport} | Size: {event.size} bytes")

    # Fájlba mentés (részletes + hexdump)
    with open(log_file, "a") as f:
        f.write(f"\n[{timestamp}] PID: {event.pid} | Thread: {comm}\n")
        f.write(f"Direction: SEND -> {daddr}:{dport} | Total Size: {event.size} bytes\n")
        f.write("Payload (First 256 bytes):\n")
        f.write(hexdump(payload_bytes))
        f.write("\n--------------------------------------------------\n")

b["events"].open_perf_buffer(print_event)

# --- PID KÖVETŐ SZÁL ---
active_pids = set()
running = True

def update_pids():
    global active_pids
    target_map = b["target_pids"]
    while running:
        current_pids = set()
        for proc in psutil.process_iter(['pid', 'name']):
            try:
                if proc.info['name'] == PROCESS_NAME:
                    current_pids.add(proc.info['pid'])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        new_pids = current_pids - active_pids
        dead_pids = active_pids - current_pids

        for pid in new_pids:
            target_map[target_map.Key(pid)] = target_map.Leaf(1)
            print(f"[+] 🔄 RADAR TRACKING NEW PID: {pid} ({PROCESS_NAME})")

        for pid in dead_pids:
            try:
                del target_map[target_map.Key(pid)]
            except KeyError:
                pass
            print(f"[-] 🛑 RADAR DROPPED DEAD PID: {pid} ({PROCESS_NAME})")

        active_pids = current_pids
        time.sleep(2)

def signal_handler(sig, frame):
    global running
    print("\n🛑 Leállítás folyamatban...")
    running = False
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

if __name__ == '__main__':
    init_logs()
    print("🔍 Dinamikus PID követés indítása...")
    pid_thread = threading.Thread(target=update_pids, daemon=True)
    pid_thread.start()

    print(f"📡 RED TEAM SNIFFER AKTÍV. Payload mentése ide: {LOG_DIR}/")
    print("   Nyomj Ctrl+C-t a leállításhoz.")
    try:
        while running:
            b.perf_buffer_poll(timeout=500)
    except KeyboardInterrupt:
        pass
    finally:
        running = False
