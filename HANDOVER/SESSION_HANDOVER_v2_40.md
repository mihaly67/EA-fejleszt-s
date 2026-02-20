# Session Handover: Merkava v2.40 (Phase 3: Counter-Intelligence)

**Date:** 2026.02.18
**Status:** GOLDEN MASTER CANDIDATE (Pending Broker Audit)
**Phase:** 3 (Reconnaissance & Client Sovereignty)
**Version:** v2.40 (TC4 Environment Active)

## 1. System State Overview
This session successfully transitioned the environment to **TC4** (Phase 3), integrating advanced Counter-Intelligence capabilities.

### Environment Status (TC4)
*   **Script:** `ENVIRONMENT_SETUP/restore_envTC4.py` is fully operational.
    *   **New Libraries:** Successfully integrated `MI6` (SIGINT/Network Analysis).
    *   **Pending:** `Black_Ops` library download failed due to temporary Google Drive quota limits (link is valid, just needs retry).
    *   **Cleanup:** Deprecated `THIEFS` and `COLUMBO` libraries removed (superseded by `_EXTND` versions).
    *   **Constraint Adherence:** Strictly NO vectorization (`sentence-transformers`, `faiss` removed) to respect hardware limits.
*   **DevOps:** `.gitignore` updated to exclude new large knowledge bases.

## 2. Research Findings (MI6 Initial Assessment)
The initial passive analysis of the `MI6` knowledge base, combined with expert insights (Gemini), has revealed a critical vulnerability in the broker's surveillance strategy:

*   **The "Hybrid Monster" Theory:** MT5 is not just a native C++ app; it embeds web technologies (WebView2/IE) for key functions (Market, News, Signals).
*   **Web-Based Fingerprinting:** The broker likely uses standard web tracking techniques (`fingerprintjs2`, `amiunique`) within these embedded views to profile the client (Canvas fingerprinting, AudioContext, Font enumeration).
*   **Input Monitoring:** References to `cursor: pointer`, `focus`, and `mouseenter` events suggest that "nervous" broker behavior (price flickering on hover) is triggered by JavaScript event listeners in these embedded panels, which send telemetry *before* a click occurs.

## 3. Gemini Insights (Critical for Next Steps)
The following mechanisms were identified as key targets for "Network Filtering":
1.  **Startup Ping:** MT5 sends HWID/OS version to MetaQuotes immediately upon launch (License Check).
2.  **LiveUpdate:** Continuous background HTTP/HTTPS requests for updates.
3.  **Silent Crash Reports:** WINE/Memory errors are silently uploaded, revealing system anatomy.
4.  **Telemetry Channel:** Standard HTTPS traffic is used for these "Trojan" functions, making them susceptible to `mitmproxy` interception (unlike the encrypted trade protocol).

## 4. Pending Tasks & Next Steps

### Immediate Actions (Next Session)
1.  **Black Ops Library:** Retry downloading `Knowledge_Base/Black_Ops` via `restore_envTC4.py` (quota should reset).
2.  **Dedicated Research Machine:**
    *   **Status:** User is building a dedicated MX Linux machine with MT5 snapshot for deep packet inspection.
    *   **Goal:** Use this machine to run `mitmproxy` and validate the "Hybrid Monster" theory by intercepting `crash-reports.metaquotes.net` and similar traffic.
3.  **Network Hardening:**
    *   Based on the `MI6` findings, begin creating a `hosts` file blocklist for known telemetry domains.
    *   Investigate disabling "WebRequest" and embedded browser features in MT5 config.

**Signed:** Jules (AI Engineer)
