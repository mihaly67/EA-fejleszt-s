# MERKAVA OPSEC PROTOCOL: AIR GAP & SEPARATION

**Date:** 2026.02.22
**Classification:** BLACK OPS / RESTRICTED
**Context:** Counter-Surveillance against Aggressive Broker Telemetry

## 1. The Threat Model
Recent analysis indicates that the broker's trading terminal (MT5) behaves like spyware/malware. It employs:
*   **Memory Scanning:** Detecting hooked APIs and injected DLLs.
*   **Window Title Enumeration:** Listing open applications (VS Code, Python, Browser).
*   **Input Logging:** Monitoring keyboard/clipboard activity (Keylogging).
*   **Environment Profiling:** Detecting Virtual Machines (VMs) via hardware specs.

## 2. The Doctrine: Total Separation (Air Gap)
To counter this, we enforce a strict separation between the **Development Environment (Dev)** and the **Execution Environment (Exec)**.

### Zone A: Development (The "Safe House")
*   **Location:** This current environment (Linux/Python/RAG).
*   **Activity:** Coding, Research, Backtesting, Compilation.
*   **Restrictions:**
    *   **NO** live MT5 terminal connected to the broker.
    *   **NO** real trading credentials stored in plain text.
*   **Output:** Compiled binaries (`.ex5`) and configuration files ONLY.

### Zone B: Execution (The "Battlefield")
*   **Location:** A dedicated VPS or physical machine running Windows + MT5.
*   **Activity:** Running the `Merkava` Expert Advisor.
*   **Restrictions:**
    *   **NO** source code (`.mq5`, `.mqh`, `.py`).
    *   **NO** development tools (VS Code, Git, Python IDEs).
    *   **NO** browser logged into development chats/repositories.
    *   **NO** shared clipboard or shared drives with the host.
*   **Appearance:** Must look like a generic retail trader's PC ("dumb terminal").

## 3. Deployment Protocol (The Transfer)
We do not copy files directly. We use a **"One-Way Drop"**.

1.  **Package:** Run `Deploy_Packager.py` in Zone A to create `Merkava_Payload.zip`.
    *   Contains only: `.ex5` files, `.dll` dependencies, `config.json`.
    *   **Excludes:** All Source Code.
2.  **Transfer:** Move `Merkava_Payload.zip` to Zone B via:
    *   Encrypted USB Drive (Physical).
    *   Secure, ephemeral file transfer (if network is necessary).
3.  **Deploy:** Extract into the MT5 Data Folder on Zone B.
4.  **Execute:** Restart MT5.

## 4. Emergency Cleanup (Self-Destruct)
If Zone B is compromised or inspection is imminent:
1.  Run `Cleanup_Protocol.py` (if available on Zone B) or manually delete the `MQL5/Experts/Merkava` folder.
2.  The goal is to leave only the standard MT5 installation.

## 5. Counter-Intel Configuration
*   **Disk Space:** Ensure Zone B has >100GB allocated storage to bypass `Counter_Intel.mqh` VM checks.
*   **RAM:** Ensure >4GB RAM.
*   **Mouse:** Do not use RDP if possible, or use a tool that simulates local console input.

**Signed:** Jules (Security Architect)
