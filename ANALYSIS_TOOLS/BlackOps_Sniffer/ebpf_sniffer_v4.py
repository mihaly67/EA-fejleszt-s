import sys
import time
import psutil
import datetime
import threading
import signal
import os
from bcc import BPF

# --- KONFIGURÁCIÓ ---
LOG_DIR = "logs"
MAX_PAYLOAD_SIZE = 256
# WINE alatt a hálózati kéréseket gyakran a háttérfolyamatok intézik, ezért a wineserver-t is figyeljük
TARGET_PROCESSES = ["terminal64.exe", "wineserver", "winedevice.exe"]

LOG_FILES = {
    "TELEMETRY": f"{LOG_DIR}/TELEMETRY.log",
    "TRADE": f"{LOG_DIR}/TRADE_EVENTS.log",
    "UI": f"{LOG_DIR}/MISC_UI_EVENTS.log",
    "SYSTEM": f"{LOG_DIR}/SYSTEM_HEARTBEAT.log",
    "UNKNOWN": f"{LOG_DIR}/UNKNOWN_EVENTS.log"
}

def init_logs():
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)
    header = f"=== eBPF SNIFFER LOG STARTED AT {datetime.datetime.now()} ===\n"
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


# --- BPF KÓD (C) - TWO-STAGE ANCHOR ---
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>
#include <linux/socket.h>
#include <net/sock.h>
#include <linux/skbuff.h>
#include <net/tcp.h>

BPF_HASH(target_pids, u32, u32); // [pid -> 1]
BPF_HASH(mt5_socks, u64, u32);   // [sk_ptr -> pid]

#define MAX_PAYLOAD 256

struct data_t {
    u32 pid;
    char comm[TASK_COMM_LEN];
    u32 size;
    char payload[MAX_PAYLOAD];
};

BPF_PERF_OUTPUT(events);

// 1. Lépés: Megjelöljük az MT5/Wineserver socketeket
// kprobe a tcp_sendmsg kernel belső hívására, itt még megvan a PID kontextus!
int kprobe__tcp_sendmsg(struct pt_regs *ctx, struct sock *sk) {
    u32 pid = bpf_get_current_pid_tgid() >> 32;

    u32 *is_target = target_pids.lookup(&pid);
    if (is_target == 0) return 0;

    u64 sk_ptr = (u64)sk;
    mt5_socks.update(&sk_ptr, &pid);

    return 0;
}

// 2. Lépés: Elkapjuk a kész csomagot, mielőtt a hálózati kártyára menne
// Itt az skb már tartalmazza a fizikai network payloadot
int kprobe__tcp_transmit_skb(struct pt_regs *ctx, struct sock *sk, struct sk_buff *skb) {
    u64 sk_ptr = (u64)sk;

    // Csak a mi általunk felcímkézett socketeket dolgozzuk fel
    u32 *pid_ptr = mt5_socks.lookup(&sk_ptr);
    if (pid_ptr == 0) return 0;

    struct data_t data = {};
    data.pid = *pid_ptr;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    // skb->len tartalmazza a teljes méretet, próbáljuk kinyerni az iov_len-ből (ami header + adat is lehet)
    u32 len = skb->len;
    data.size = len;

    // Biztonsági korlát (Bitwise AND a Verifier miatt)
    u32 copy_size = len & 0xFF; // max 255 bytes payload (limitáltuk MAX_PAYLOAD=256)
    if (copy_size == 0) return 0;

    // Az skb->data mutat a csomag elejére (TCP header + Payload)
    char *data_ptr;
    bpf_probe_read_kernel(&data_ptr, sizeof(data_ptr), &skb->data);

    // Kiolvassuk a nyers bitfolyamot! Nincs több üres nullázás WINE userspace miatt.
    bpf_probe_read_kernel(&data.payload, copy_size, data_ptr);

    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
"""

print("⚙️ eBPF (BCC) 'Two-Stage Anchor' Syscall kód fordítása és betöltése (Kérlek várj)...")
b = BPF(text=bpf_text)

try:
    b.attach_kprobe(event="tcp_sendmsg", fn_name="kprobe__tcp_sendmsg")
    print(f"✅ Sikeres kprobe attach: tcp_sendmsg")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a tcp_sendmsg-re: {e}")

try:
    b.attach_kprobe(event="tcp_transmit_skb", fn_name="kprobe__tcp_transmit_skb")
    print(f"✅ Sikeres kprobe attach: tcp_transmit_skb")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a tcp_transmit_skb-re: {e}")


# --- PYTHON FELDOLGOZÓ (USERSPACE) ---
def print_event(cpu, data, size):
    event = b["events"].event(data)

    comm = event.comm.decode('utf-8', 'replace').strip()
    category = categorize_packet(comm, event.size)
    log_file = LOG_FILES.get(category, LOG_FILES["UNKNOWN"])

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    payload_size = min(event.size, MAX_PAYLOAD_SIZE)
    payload_bytes = bytes(event.payload[:payload_size])

    print(f"[{category}] {comm} | Size: {event.size} bytes (Includes TCP Header)")

    with open(log_file, "a") as f:
        f.write(f"\n[{timestamp}] PID: {event.pid} | Thread: {comm}\n")
        f.write(f"Direction: SEND (Skb Extracted) | Total Size: {event.size} bytes\n")
        f.write("Payload + TCP Header (First 256 bytes):\n")
        f.write(hexdump(payload_bytes))
        f.write("\n--------------------------------------------------\n")

b["events"].open_perf_buffer(print_event)

# --- PID KÖVETŐ SZÁL ---
active_pids = set()
running = True

def update_pids():
    global active_pids
    target_map = b["target_pids"]
    pid_names = {}

    while running:
        current_pids = set()
        for proc in psutil.process_iter(['pid', 'name']):
            try:
                name = proc.info['name']
                if name in TARGET_PROCESSES:
                    pid = proc.info['pid']
                    current_pids.add(pid)
                    pid_names[pid] = name
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        new_pids = current_pids - active_pids
        dead_pids = active_pids - current_pids

        for pid in new_pids:
            target_map[target_map.Key(pid)] = target_map.Leaf(1)
            name = pid_names.get(pid, "Unknown")
            print(f"[+] 🔄 RADAR TRACKING NEW PID: {pid} ({name})")

        for pid in dead_pids:
            try:
                del target_map[target_map.Key(pid)]
            except KeyError:
                pass
            name = pid_names.pop(pid, "Unknown")
            print(f"[-] 🛑 RADAR DROPPED DEAD PID: {pid} ({name})")

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

    print(f"📡 RED TEAM SNIFFER AKTÍV (V4 - Two-Stage Anchor). Payload mentése ide: {LOG_DIR}/")
    print("   Nyomj Ctrl+C-t a leállításhoz.")
    try:
        while running:
            b.perf_buffer_poll(timeout=500)
    except KeyboardInterrupt:
        pass
    finally:
        running = False
