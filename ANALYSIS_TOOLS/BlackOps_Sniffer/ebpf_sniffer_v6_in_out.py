import sys
import time
import datetime
import os
import ctypes as ct
import socket
from bcc import BPF

LOG_DIR = "logs"
MAX_PAYLOAD_SIZE = 256
TARGET_PORT = 443

# Feketelista a folyamat/szál nevekhez, amiket ignorálni akarunk a logból (Kimenő forgalomnál számít főleg)
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


# --- BPF KÓD (C) - PORT-ALAPÚ KPROBE (IN és OUT) ---
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
    u16 sport;
    u16 dport;
    u32 size;
    u8 direction; // 0 = OUT, 1 = IN
    char payload[MAX_PAYLOAD];
};

BPF_PERF_OUTPUT(events);

// === KIMENŐ FORGALOM (OUT) ===
int trace_ip_local_out(struct pt_regs *ctx, struct net *net, struct sock *sk, struct sk_buff *skb) {
    if (!skb) return 0;

    char *head = NULL;
    bpf_probe_read_kernel(&head, sizeof(head), &skb->head);

    u16 network_header = 0;
    u16 transport_header = 0;
    bpf_probe_read_kernel(&network_header, sizeof(network_header), &skb->network_header);
    bpf_probe_read_kernel(&transport_header, sizeof(transport_header), &skb->transport_header);

    struct iphdr *ip = (struct iphdr *)(head + network_header);
    u8 protocol = 0;
    bpf_probe_read_kernel(&protocol, sizeof(protocol), &ip->protocol);
    if (protocol != IPPROTO_TCP) return 0;

    struct tcphdr *tcp = (struct tcphdr *)(head + transport_header);
    u16 dport = 0;
    bpf_probe_read_kernel(&dport, sizeof(dport), &tcp->dest);
    dport = ntohs(dport);

    if (dport != TARGET_PORT) return 0;

    u32 len = 0;
    bpf_probe_read_kernel(&len, sizeof(len), &skb->len);

    // Szűrés: Üres csomagok (Csak TCP/IP Header <= 64 byte) eldobása
    if (len <= 64) return 0;

    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    bpf_probe_read_kernel(&data.saddr, sizeof(data.saddr), &ip->saddr);
    bpf_probe_read_kernel(&data.daddr, sizeof(data.daddr), &ip->daddr);
    data.dport = dport;

    u16 sport = 0;
    bpf_probe_read_kernel(&sport, sizeof(sport), &tcp->source);
    data.sport = ntohs(sport);

    data.size = len;
    data.direction = 0; // OUT

    u32 copy_size = len;
    if (copy_size > MAX_PAYLOAD - 1) {
        copy_size = MAX_PAYLOAD - 1;
    }

    char *data_ptr = NULL;
    bpf_probe_read_kernel(&data_ptr, sizeof(data_ptr), &skb->data);
    if (data_ptr) {
        bpf_probe_read_kernel(&data.payload, copy_size, data_ptr);
        events.perf_submit(ctx, &data, sizeof(data));
    }

    return 0;
}

// === BEJÖVŐ FORGALOM (IN) ===
// A bejövő csomagokat az ip_local_deliver függvény kapja meg (már MAC nélkül)
int trace_ip_local_deliver(struct pt_regs *ctx, struct sk_buff *skb) {
    if (!skb) return 0;

    char *head = NULL;
    bpf_probe_read_kernel(&head, sizeof(head), &skb->head);

    u16 network_header = 0;
    u16 transport_header = 0;
    bpf_probe_read_kernel(&network_header, sizeof(network_header), &skb->network_header);
    bpf_probe_read_kernel(&transport_header, sizeof(transport_header), &skb->transport_header);

    // BEJÖVŐ esetén a transport_header néha nincs inicializálva pontosan ezen a ponton (offset számítás)
    // De az IP fejléc után azonnal a TCP fejléc jön (opcióktól függően 20 byte).
    struct iphdr *ip = (struct iphdr *)(head + network_header);
    u8 protocol = 0;
    bpf_probe_read_kernel(&protocol, sizeof(protocol), &ip->protocol);
    if (protocol != IPPROTO_TCP) return 0;

    // Az ip->ihl egy bitmező, nem kérhetjük le a címét a memóriából (&ip->ihl).
    // Helyette a struct iphdr első bájtját olvassuk be, ami a version + ihl mezőket tartalmazza,
    // majd egy bitmaszkkal (0x0F) kinyerjük belőle az ihl értékét.
    u8 ihl_version = 0;
    bpf_probe_read_kernel(&ihl_version, sizeof(ihl_version), (void *)ip);
    u8 ihl = ihl_version & 0x0F;

    // IP header hossza = ihl * 4
    struct tcphdr *tcp = (struct tcphdr *)(head + network_header + (ihl * 4));
    u16 sport = 0;
    bpf_probe_read_kernel(&sport, sizeof(sport), &tcp->source);
    sport = ntohs(sport);

    // Szűrés a TARGET_PORT-ra a forrás portnál (bejövőnél a bróker a feladó)
    if (sport != TARGET_PORT) return 0;

    u32 len = 0;
    bpf_probe_read_kernel(&len, sizeof(len), &skb->len);

    // Szűrés: Üres csomagok eldobása bejövő ágon is
    if (len <= 64) return 0;

    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32; // Lehet, hogy itt ksoftirqd lesz
    bpf_get_current_comm(&data.comm, sizeof(data.comm));

    bpf_probe_read_kernel(&data.saddr, sizeof(data.saddr), &ip->saddr);
    bpf_probe_read_kernel(&data.daddr, sizeof(data.daddr), &ip->daddr);
    data.sport = sport;

    u16 dport = 0;
    bpf_probe_read_kernel(&dport, sizeof(dport), &tcp->dest);
    data.dport = ntohs(dport);

    data.size = len;
    data.direction = 1; // IN

    u32 copy_size = len;
    if (copy_size > MAX_PAYLOAD - 1) {
        copy_size = MAX_PAYLOAD - 1;
    }

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

print("⚙️ eBPF (BCC) 'V6 IN/OUT Port-Based' kód fordítása és betöltése...")
b = BPF(text=bpf_text)

try:
    b.attach_kprobe(event="ip_local_out", fn_name="trace_ip_local_out")
    print(f"✅ Kimenő (OUT) hook aktív: ip_local_out")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a kimenő hook-ot: {e}")

try:
    # A bejövő (IN) csomagokhoz az ip_local_deliver_finish vagy ip_local_deliver függvény a legjobb
    b.attach_kprobe(event="ip_local_deliver", fn_name="trace_ip_local_deliver")
    print(f"✅ Bejövő (IN) hook aktív: ip_local_deliver")
except Exception as e:
    print(f"⚠️ Nem sikerült attach-olni a bejövő hook-ot: {e}")


# --- PYTHON FELDOLGOZÓ (USERSPACE) ---
def print_event(cpu, data, size):
    event = b["events"].event(data)

    comm = event.comm.decode('utf-8', 'replace').strip()
    comm_lower = comm.lower()

    # Feketelista alkalmazása (Kimenőnél van értelme, bejövőnél a bróker küldi, így az mindig releváns)
    if event.direction == 0:
        for bl in BLACKLIST_COMMS:
            if bl in comm_lower:
                return

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    payload_size = min(event.size, MAX_PAYLOAD_SIZE)
    payload_bytes = bytes(event.payload[:payload_size])

    src_ip = socket.inet_ntoa(ct.c_uint32(event.saddr).value.to_bytes(4, 'little'))
    dst_ip = socket.inet_ntoa(ct.c_uint32(event.daddr).value.to_bytes(4, 'little'))

    direction_str = "IN" if event.direction == 1 else "OUT"
    color = "\033[92m" if event.direction == 1 else "\033[91m" # Zöld bejövő, Piros kimenő
    reset = "\033[0m"

    print(f"[{color}TCP {direction_str}{reset}] {comm} (PID: {event.pid}) | {src_ip}:{event.sport} -> {dst_ip}:{event.dport} | Size: {event.size} bytes")

    with open(f"{LOG_DIR}/MT5_PORT_{TARGET_PORT}_IN_OUT.log", "a") as f:
        f.write(f"\n[{timestamp}] PID: {event.pid} | Thread: {comm} | Dir: {direction_str}\n")
        f.write(f"{src_ip}:{event.sport} -> {dst_ip}:{event.dport} | Total Size: {event.size} bytes\n")
        f.write("Payload + Headers (First 256 bytes):\n")
        f.write(hexdump(payload_bytes))
        f.write("\n--------------------------------------------------\n")

b["events"].open_perf_buffer(print_event)

if __name__ == '__main__':
    init_logs()
    print(f"📡 RED TEAM SNIFFER AKTÍV (V6 - IN/OUT). Figyelt port: {TARGET_PORT}. Payload mentése ide: {LOG_DIR}/")
    print("   Nyomj Ctrl+C-t a leállításhoz.")
    try:
        while True:
            b.perf_buffer_poll(timeout=500)
    except KeyboardInterrupt:
        sys.exit(0)
