# MI6 Initial Assessment: MT5 Broker Telemetry & Fingerprinting
**Date:** 2026.02.18
**Phase:** 3 (Counter-Intelligence)
**Scope:** MI6 Knowledge Base (Passive Analysis)
**Status:** INITIAL FINDINGS

## 1. Executive Summary
The initial passive analysis of the `MI6` knowledge base reveals a strong presence of **web-based fingerprinting technologies** (`fingerprintjs2`, `amiunique`, `modernizr`) within the collected data. This suggests that modern trading terminals (like MT5) or their associated broker services likely leverage **embedded web technologies (WebViews, HTML5 panels)** to perform client-side tracking.

The observed "nervous" broker behavior (price flickering on mouse hover, rapid execution shifts) aligns with **JavaScript-based event listeners** (`mouseenter`, `focus`, `cursor: pointer`) running in these embedded views.

## 2. Key Findings

### 2.1. Browser-Based Fingerprinting
The dataset contains references to `amiunique` and `fingerprintjs2`, which are advanced libraries for identifying users based on:
*   **Canvas Fingerprinting:** Rendering hidden graphics to detect GPU/Driver differences.
*   **Font Enumeration:** Checking installed fonts.
*   **AudioContext:** Analyzing audio hardware.

**Implication for MT5:** If the broker uses an embedded browser for "News", "Market", or even the "One-Click Trading" panel (if implemented as a web component), they can uniquely identify the machine even if the IP changes or the MT5 instance is reinstalled.

### 2.2. Input Monitoring (Mouse & Focus)
Multiple hits were found for:
*   `cursor: pointer` / `cursor: default` (CSS/JS control of mouse appearance).
*   `focus` events (detecting when a window or element is active).
*   `mouseenter` / `mouseleave` events.

**Mechanism:**
Brokers can attach JS event listeners to trading buttons in their custom panels.
*   **Hover Detection:** When the mouse hovers over "Buy", a `mouseenter` event fires.
*   **Telemetry:** This event is sent to the server *before* the click.
*   **Reaction:** The server algorithms adjust the price feed (slippage/spread) in milliseconds, anticipating the trade.

### 2.3. "Heartbeat" & Connection
References to `heartbeat` (e.g., in `font-awesome`) and various `ActiveX` / `plugin` checks suggest mechanisms to ensure the client is "live" and not a static script.

## 3. Theoretical Attack Vector (The "Nervous Broker")
1.  **Stage 1 (Hover):** User moves mouse over "Buy".
2.  **Stage 2 (Detection):** Embedded JS fires `mouseenter` or detects `cursor` state change.
3.  **Stage 3 (Transmission):** A lightweight packet (or WebSocket message) is sent to the broker's risk server.
4.  **Stage 4 (Reaction):** The risk server shifts the price spread slightly or prepares a "requote" logic.
5.  **Stage 5 (Click):** User clicks, but the environment has already been "prepared" against them.

## 4. Countermeasure Recommendations (Black Ops Preparation)

### 4.1. Network Filtering (SIGINT)
*   **Action:** Block traffic to known tracking domains (e.g., `google-analytics`, `hotjar`, or broker-specific telemetry endpoints) at the firewall/hosts file level.
*   **Tool:** `mitmproxy` (on the dedicated research machine) to identify these hidden HTTPS requests.

### 4.2. Input Spoofing (Client Sovereignty)
*   **Action:** "Jitter" the mouse coordinates programmatically to break the smooth "human" hover patterns that tracking scripts look for.
*   **Action:** Inject fake `focus` events to confusing the "attention tracking" logic.

### 4.3. Environment Hardening
*   **Disable WebRequest:** In MT5 Options, strictly limit allowed URLs.
*   **Disable Embedded Browser:** (If possible via config) or block its network access.

## 5. Next Steps
1.  **Active SIGINT (Dedicated Machine):** Verify these theoretical findings by capturing actual traffic from the MT5 terminal using `mitmproxy` on the snapshot-based MX Linux machine.
2.  **Black Ops:** Once the `Black_Ops` library is available, implement the "Input Jitter" countermeasures.
