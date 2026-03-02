#!/usr/bin/python3
"""
Black Ops Sniffer (Red Team) - eBPF TCP Payload Interceptor (Syscall Hook)
Cél: Az MT5 (terminal64.exe) telemetria, kereskedési események és UI hálózati csomagok
tényleges tartalmának (payload) elfogása a Linux kerneltől és azok kategorizált mentése.

[JAVÍTÁS 2 - MX Linux Kompatibilitás]:
A TRACEPOINT_PROBE syscalls tracepointjai 'incomplete definition' hibát dobtak a helyi
kernel headerek hiányosságai miatt. Ezért áttértünk a stabil kprobe-ra, dinamikusan
feloldva a sendto és write syscallok nevét (pl. __x64_sys_sendto). Itt a paraméterek egy
struct pt_regs *ctx mutatóban érkeznek, ahonnan a syscall argumentumok kinyerhetők.
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
    header = f"--- BLACK OPS SNIFFER (SYSCALL HOOK V2) STARTED AT {timestamp} ---\n"
    for path in LOG_FILES.values():
        with open(path, "a") as f:
            f.write(header)

def categorize_packet(comm, size):
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
    FILTER = ''.join([(len(repr(chr(x))) == 3) and chr(x) or '.' for x in range(256)])
    lines = []
    for c in range(0, len(src), length):
        chars = src[c:c+length]
        hex_str = ' '.join([f"{x:02x}" for x in chars])
        printable = ''.join([FILTER[x] for x in chars])
        lines.append(f"{c:04x}  {hex_str:<{length*3}}  |{printable}|")
    return '\n'.join(lines)


# --- BPF KÓD (C) - KPROBE ---
# A modern kerneleken a syscallokat a pt_regs ctx struktúrán keresztül kapjuk meg
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

BPF_HASH(target_pids, u32, u32); // [pid -> 1]

struct data_t {
    u32 pid;
    char comm[TASK_COMM_LEN];
    u32 fd;
    u32 size;
    u8 payload[256];
};

BPF_PERF_OUTPUT(events);

// kprobe a sendto syscallra. Az argumentumok elérése a PT_REGS_PARMx makrókkal történik.
// sendto(int fd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen)
int kprobe__sys_sendto(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;

    u32 *is_target = target_pids.lookup(&pid);
    if (is_target == 0) {
        return 0;
    }

    struct data_t data = {};
    data.pid = pid;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    // PT_REGS_PARM1: fd, PT_REGS_PARM2: buf, PT_REGS_PARM3: len
    data.fd = (u32)PT_REGS_PARM1(ctx);
    data.size = (u32)PT_REGS_PARM3(ctx);

    // Ha len nagyon pici, vagy 0, felesleges
    if (data.size == 0) return 0;

    void *user_ptr = (void *)PT_REGS_PARM2(ctx);

    u32 copy_size = data.size;
    if (copy_size > 256) {
        copy_size = 256;
    }

    // Payload másolása usermode memóriából
    bpf_probe_read_user(&data.payload, copy_size, user_ptr);

    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}

// kprobe a write syscallra (ha valamiért azon menne ki a hálózati adat, a WINE néha wrapeli)
// write(int fd, const void *buf, size_t count)
int kprobe__sys_write(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;

    u32 *is_target = target_pids.lookup(&pid);
    if (is_target == 0) {
        return 0;
    }

    struct data_t data = {};
    data.pid = pid;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    data.fd = (u32)PT_REGS_PARM1(ctx);
    data.size = (u32)PT_REGS_PARM3(ctx);

    // Kiszűrjük a stdout/stderr/stdin fd-ket (0,1,2), minket csak socket/file érdekel
    if (data.fd <= 2) return 0;
    if (data.size == 0) return 0;

    void *user_ptr = (void *)PT_REGS_PARM2(ctx);

    u32 copy_size = data.size;
    if (copy_size > 256) {
        copy_size = 256;
    }

    bpf_probe_read_user(&data.payload, copy_size, user_ptr);

    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
"""

print("⚙️ eBPF (BCC) Verifier-barát Syscall kód fordítása és betöltése (Kérlek várj)...")
b = BPF(text=bpf_text)

# Ha a modern kerneleken __x64_sys_sendto hívás van, attach-olunk ahhoz is.
# A get_syscall_fnname visszaadja az OS-specifikus nevet (pl. __x64_sys_sendto)
fnname_sendto = b.get_syscall_fnname("sendto")
fnname_write = b.get_syscall_fnname("write")

try:
    b.attach_kprobe(event=fnname_sendto, fn_name="kprobe__sys_sendto")
    print(f"✅ Sikeres kprobe attach: {fnname_sendto}")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a {fnname_sendto}-re: {e}")

try:
    b.attach_kprobe(event=fnname_write, fn_name="kprobe__sys_write")
    print(f"✅ Sikeres kprobe attach: {fnname_write}")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a {fnname_write}-re: {e}")

# --- PYTHON FELDOLGOZÓ (USERSPACE) ---
def print_event(cpu, data, size):
    event = b["events"].event(data)

    comm = event.comm.decode('utf-8', 'replace').strip()
    category = categorize_packet(comm, event.size)
    log_file = LOG_FILES.get(category, LOG_FILES["UNKNOWN"])

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    payload_size = min(event.size, MAX_PAYLOAD_SIZE)
    payload_bytes = bytes(event.payload[:payload_size])

    print(f"[{category}] {comm} (FD: {event.fd}) | Size: {event.size} bytes")

    with open(log_file, "a") as f:
        f.write(f"\n[{timestamp}] PID: {event.pid} | Thread: {comm}\n")
        f.write(f"Direction: SEND (FD: {event.fd}) | Total Size: {event.size} bytes\n")
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
