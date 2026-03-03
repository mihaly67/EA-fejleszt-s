# SESSION HANDOVER: THE WINE WALL & eBPF VERIFIER (BLACK OPS DPI)

**Date:** 2026.03.03 22:42
**Target Next Phase:** Fix WINE PID Tracking in Python & Extract Valid TCP Payload
**Baseline Version:** `Merkava_v2_40.mq5` (Strict Silence)

## 1. Executive Summary
This was a brutal, hard-fought session. We achieved significant breakthroughs against the Linux Kernel's eBPF Verifier and adapted to the architectural nuances of modern x86_64 systems. However, we hit a "Wine Wall": our payload logs are empty. Not because the BPF code is wrong, but because the TCP traffic isn't being sent by `terminal64.exe` itself.

## 2. Key Achievements & Deliverables

### A. The eBPF Verifier Defeated (Strict Bounds)
*   **The Problem:** The Verifier rejected our `kprobe` logic with `R2 min value is negative`.
*   **The Solution:** We removed complex `if (size > 255)` branches that confused the verifier's branching bounds tracker. We implemented a mathematically absolute, single-line bitwise constraint:
    `u32 copy_size = data.size & 0xFF;`
    `if (copy_size == 0) return 0;`
    This provided mathematical certainty to the Verifier, and the scripts now compile and load successfully.

### B. x86_64 Syscall Wrappers Unveiled (`pt_regs`)
*   **The Problem:** We were getting `00 00` (NULL) bytes and absurd payload sizes (`4294967295`) because we were directly reading `PT_REGS_PARM1(ctx)`.
*   **The Solution:** Modern Linux kernels (>= 4.17) wrap syscalls. `ctx` points to a wrapper, and `PT_REGS_PARM1` is actually a pointer to the *real* inner `pt_regs` struct. We updated the C code to cast `PT_REGS_PARM1` to `struct pt_regs *` and safely unpack the real `di`, `si`, and `dx` registers using `bpf_probe_read_kernel`.

### C. The `sys_sendmsg` Hook & BCC Header Fixes
*   We discovered that WINE often translates Windows `WSASend` calls into Linux `sys_sendmsg` calls instead of `sendto`.
*   We added a `kprobe__sys_sendmsg` function.
*   **BCC Compilation Fix:** To prevent "incomplete type" errors for `struct user_msghdr` and `struct iovec`, we explicitly included `<linux/socket.h>` and `<linux/uio.h>` in the BCC C code string.
*   We safely unpack the payload by reading `user_msghdr` -> `msg_iov` -> `iov_base`.

### D. The SWAT RAG Interrogation Protocol
*   We codified the "Kihallgatási Protokoll" (Interrogation Protocol) provided by Gemini.
*   It is now embedded directly in `AGENTS.md` and `SWAT_RAG_SEARCH_PROTOCOL.md`.
*   **The 3 Pillars:** 1. Hybrid SQL/Vector Filtering. 2. Functional Prompting (Concepts over Syntax). 3. Context Neighborhood (Fetching adjacent SQL rows). This will guide all future RAG queries.

## 3. The Current Roadblock (The "Wine Wall")
We successfully hooked the syscalls, but our log files (`TRADE_EVENTS.log`, `MISC_UI_EVENTS.log`) are completely empty, and `TELEMETRY.log` only captures small 64-byte IPC messages (File Descriptor 4, 13).
*   **The Cause:** Our Python script tracks processes by name: `PROCESS_NAME = "terminal64.exe"`. Under WINE, network I/O operations (like `sys_sendmsg`) are usually delegated to background proxy threads/processes like `wineserver` or `winedevice.exe`.
*   Because `terminal64.exe` isn't making the actual TCP syscall, our eBPF filter (`target_pids.lookup(&pid)`) immediately drops the packets.

## 4. Next Steps for the Next Agent
**Your Mission:**
1.  **Read the Protocol:** Read `SWAT_RAG_SEARCH_PROTOCOL.md` as instructed by `AGENTS.md`.
2.  **Fix PID Tracking:** Modify `ANALYSIS_TOOLS/BlackOps_Sniffer/ebpf_sniffer_v3.py`. The `update_pids()` Python thread must be expanded to track **both** `terminal64.exe` AND `wineserver` (and potentially `winedevice.exe`).
    *   *Challenge:* If you track all `wineserver` traffic, you might capture unrelated Wine apps. You may need to filter by Destination IP in the eBPF code (e.g., matching the broker's IP) rather than just the PID, or correlate the `wineserver` process associated specifically with the MT5 Wine prefix.
3.  **Capture the Payload:** Once the correct wineserver process is tracked, the `sys_sendmsg` hook should finally extract the raw MT5 TCP payload.

**Signed:** Jules (eBPF Kernel Architect)
