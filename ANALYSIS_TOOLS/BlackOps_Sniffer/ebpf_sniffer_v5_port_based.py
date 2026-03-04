import sys
import time
import datetime
import os
import ctypes as ct
import socket
from bcc import BPF

LOG_DIR = "logs"
MAX_PAYLOAD_SIZE = 256
# Csak azokat a csomagokat fogjuk meg, amik a broker portokra mennek.
# MT5 gyakori portjai: 443 (HTTPS/TLS), egyéb TCP portok.
TARGET_PORT = 443

# Feketelista a folyamat/szál nevekhez, amiket ignorálni akarunk a logból
BLACKLIST_COMMS = ["chrome", "vivaldi", "conky", "firefox", "swapper"]

def init_logs():
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)

def hexdump(src, length=16):
    FILTER = ''.join([(len(repr(chr(x))) == 3) and chr(x) or '.' for x in range(256)])
    lines = []
    for c in range(0, len(src), length):
        chars = src[c:c+length]
        hex_str = ' '.join([f"{x:02x}" for x in chars])
        printable = ''.join([FILTER[x] for x in chars])
        lines.append(f"{c:04x}  {hex_str:<{length*3}}  |{printable}|")
    return '\n'.join(lines)


# --- BPF KÓD (C) - PORT-ALAPÚ KPROBE (NINCS PID / NINCS SOCKET MAP) ---
bpf_text = """
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>
#include <linux/skbuff.h>
#include <uapi/linux/ip.h>
#include <uapi/linux/tcp.h>
#include <uapi/linux/if_ether.h>
#include <net/sock.h>

#define MAX_PAYLOAD 256

struct data_t {
    u32 pid;
    char comm[TASK_COMM_LEN];
    u32 saddr;
    u32 daddr;
    u16 dport;
    u32 size;
    char payload[MAX_PAYLOAD];
};

BPF_PERF_OUTPUT(events);

// Az ip_local_out az IP rétegen kapja meg az skb-t, amikor már a TCP + IP fejléc rajta van.
int trace_ip_local_out(struct pt_regs *ctx, struct net *net, struct sock *sk, struct sk_buff *skb) {
    if (!skb) return 0;

    // Kinyerjük a payload címet (a data mutatót)
    char *head = NULL;
    bpf_probe_read_kernel(&head, sizeof(head), &skb->head);

    u16 network_header = 0;
    u16 transport_header = 0;
    bpf_probe_read_kernel(&network_header, sizeof(network_header), &skb->network_header);
    bpf_probe_read_kernel(&transport_header, sizeof(transport_header), &skb->transport_header);

    // Kiszámoljuk az IP fejléc helyét
    struct iphdr *ip = (struct iphdr *)(head + network_header);
    u8 protocol = 0;
    bpf_probe_read_kernel(&protocol, sizeof(protocol), &ip->protocol);

    // Csak TCP forgalom érdekel minket
    if (protocol != IPPROTO_TCP) return 0;

    // TCP fejléc
    struct tcphdr *tcp = (struct tcphdr *)(head + transport_header);
    u16 dport = 0;
    bpf_probe_read_kernel(&dport, sizeof(dport), &tcp->dest);
    dport = ntohs(dport);

    // Szűrés a TARGET_PORT-ra (pl. 443)
    if (dport != TARGET_PORT) return 0;

    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    bpf_probe_read_kernel(&data.saddr, sizeof(data.saddr), &ip->saddr);
    bpf_probe_read_kernel(&data.daddr, sizeof(data.daddr), &ip->daddr);
    data.dport = dport;

    u32 len = 0;
    bpf_probe_read_kernel(&len, sizeof(len), &skb->len);
    data.size = len;

    if (len == 0) return 0;

    u32 copy_size = len;
    if (copy_size > MAX_PAYLOAD - 1) {
        copy_size = MAX_PAYLOAD - 1;
    }

    // Olvasás a bufferből
    char *data_ptr = NULL;
    bpf_probe_read_kernel(&data_ptr, sizeof(data_ptr), &skb->data);
    if (data_ptr) {
        bpf_probe_read_kernel(&data.payload, copy_size, data_ptr);
        events.perf_submit(ctx, &data, sizeof(data));
    }

    return 0;
}
"""

bpf_text = bpf_text.replace("TARGET_PORT", str(TARGET_PORT))

print("⚙️ eBPF (BCC) 'Port-Based' kód fordítása és betöltése (Kérlek várj)...")
b = BPF(text=bpf_text)

try:
    b.attach_kprobe(event="ip_local_out", fn_name="trace_ip_local_out")
    print(f"✅ Sikeres kprobe attach: ip_local_out")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a ip_local_out-ra: {e}")
    sys.exit(1)

# --- PYTHON FELDOLGOZÓ (USERSPACE) ---
def print_event(cpu, data, size):
    event = b["events"].event(data)

    comm = event.comm.decode('utf-8', 'replace').strip()
    comm_lower = comm.lower()

    # 1. Szűrés: Feketelista alkalmazása a szál/folyamat nevekre
    for bl in BLACKLIST_COMMS:
        if bl in comm_lower:
            return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    payload_size = min(event.size, MAX_PAYLOAD_SIZE)
    payload_bytes = bytes(event.payload[:payload_size])

    src_ip = socket.inet_ntoa(ct.c_uint32(event.saddr).value.to_bytes(4, 'little'))
    dst_ip = socket.inet_ntoa(ct.c_uint32(event.daddr).value.to_bytes(4, 'little'))

    # 2. Opcionális: Ha az adat csak 52 byte, az sokszor csak egy üres TCP ACK csomag (header only),
    # A logok csökkentése érdekében ezt is szűrhetjük, ha a méret túl kicsi (csak TCP fejléc),
    # de egyelőre mindent kiírunk a feketelistán kívül.

    print(f"[TCP OUT] {comm} (PID: {event.pid}) | {src_ip} -> {dst_ip}:{event.dport} | Size: {event.size} bytes")

    with open(f"{LOG_DIR}/MT5_PORT_{TARGET_PORT}_OUT.log", "a") as f:
        f.write(f"\n[{timestamp}] PID: {event.pid} | Thread: {comm}\n")
        f.write(f"Direction: SEND | {src_ip} -> {dst_ip}:{event.dport} | Total Size: {event.size} bytes\n")
        f.write("Payload + Headers (First 256 bytes):\n")
        f.write(hexdump(payload_bytes))
        f.write("\n--------------------------------------------------\n")

b["events"].open_perf_buffer(print_event)

if __name__ == '__main__':
    init_logs()
    print(f"📡 RED TEAM SNIFFER AKTÍV (V5 - Port-Based). Figyelt port: {TARGET_PORT}. Payload mentése ide: {LOG_DIR}/")
    print("   Nyomj Ctrl+C-t a leállításhoz.")
    try:
        while True:
            b.perf_buffer_poll(timeout=500)
    except KeyboardInterrupt:
        sys.exit(0)
