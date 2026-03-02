# SESSION HANDOVER: THE eBPF VERIFIER MAZE (BLACK OPS DPI)

**Date:** 2026.03.03 00:17
**Target Next Phase:** Fix eBPF Verifier "Size" Error and Deploy Syscall Sniffer
**Baseline Version:** `Merkava_v2_40.mq5` (Strict Silence)

## 1. Executive Summary
During this session, we transitioned from passive external monitoring (Network Radar) to **Deep Packet Inspection (DPI)**. The goal was to build `ebpf_sniffer_v3.py` in `ANALYSIS_TOOLS/BlackOps_Sniffer/` to capture the first 256 bytes of MT5 network payloads (to identify encrypted headers or raw data) based on earlier discoveries of event-driven telemetry bursts.

We successfully built the infrastructure, but hit extreme resistance from the Linux Kernel's **eBPF Verifier** ("The Paranoid Policeman"), which blocked execution to protect kernel memory.

## 2. Key Achievements & Deliverables

### A. Environment & Log Analysis
*   Updated the environment setup script to `restore_envSWAT2.py` with the new FAISS RAG ID.
*   Downloaded and analyzed the MT5 network radar log. Discovered that network packets can be reliably categorized by the Thread (`COMM`) and size:
    *   `controller`: Telemetry (~700 bytes)
    *   `expert Merkava_`: Trade Events (~150 bytes)
    *   `calendar dispat` / `MQL5.community`: UI / Heartbeat events

### B. The Red Team Sniffer (Development)
*   Created `ebpf_sniffer_v3.py` to extract HexDump payloads.
*   **Attempt 1 (kprobe__tcp_sendmsg):** Failed. Direct pointer dereferencing of `struct msghdr` triggered a Verifier *Permission denied* error. The RAG confirmed `tcp_sendmsg` is too deep in the kernel for safe payload reading.
*   **Attempt 2 (TRACEPOINT_PROBE syscalls):** Failed. Missing local kernel headers (`incomplete definition`) on the host MX Linux for `tracepoint__syscalls__sys_enter_sendto`.
*   **Attempt 3 (Dynamic kprobe on sys_sendto):** We switched to `kprobe` using `PT_REGS_PARM` to read `args->buf`. The script compiled via BCC, but the Verifier killed it upon load.

### C. The Current Roadblock (Verifier Panic)
The latest crash log (`terminal_error_v2.txt`) reveals the current issue. The Verifier stops the load with:
`R2 min value is negative, either use unsigned or 'var &= const'`
followed by `Failed to load BPF program b'kprobe__sys_sendto': Permission denied`.

## 3. Next Steps for the Next Agent (The Fix)
The problem lies in how we are passing the `copy_size` to `bpf_probe_read_user()`. The Verifier cannot mathematically prove that our dynamically calculated `copy_size` isn't negative or out of bounds (even though we wrote `if (copy_size > 256) copy_size = 256;`).

**Your Mission:**
1.  **Fix the Verifier Issue:** Open `ANALYSIS_TOOLS/BlackOps_Sniffer/ebpf_sniffer_v3.py`.
2.  **Bitwise Masking:** To satisfy the Verifier, you must force the size to be an absolute, provable positive integer using bitwise operations (`&=`).
3.  **Implement this pattern in the C code for BOTH `sendto` and `write`:**
    ```c
    u32 copy_size = (u32)PT_REGS_PARM3(ctx);
    copy_size &= 0xFF; // Strictly limits size to 0-255 (Max 255 bytes). This proves to the Verifier it is safe.
    bpf_probe_read_user(&data.payload, copy_size, user_ptr);
    ```
4.  Once the bitwise mask is applied, the Verifier should allow the script to load. Run the tests and finalize the DPI stage!

**Signed:** Jules (eBPF Kernel Architect)
