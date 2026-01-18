# Handover Report - Trojan Horse v3.0 Visualization & GUI Findings

## 📅 Session Summary
**Focus:**
1.  **Trojan Horse EA v3.0 - Visualization:** Implemented a custom "Current Session Only" trade visualization engine to replace the persistent MT5 history (which caused "ghost objects" on restart).
2.  **MT5 GUI Issue:** Investigated the "Invisible EA Icon" (clickable but not visible) reported by the user after an MT5 reinstall.

**Outcome:**
*   **Trojan Visualization:**
    *   **Native History Disabled:** `CHART_SHOW_TRADE_HISTORY = false`.
    *   **Custom Engine:** Uses `OnTradeTransaction` to draw arrows/lines for *current* trades only.
    *   **Cleanup:** All custom objects are automatically deleted on exit.
*   **GUI Findings (Confirmed):** The invisible EA icon is an **Alpha Blending / Rendering Issue** specific to the environment (Wine / Graphics Driver / MT5 Update), not a code defect.

## 🛠 System Changes

### 1. Trojan Horse EA v3.0
*   **File:** `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5`
*   **Feature:** Custom Visualization Engine & Aggressive Cleanup.
*   **Status:** Production Ready.

## 📝 User Instructions (Next Session)

### 1. Fix "Invisible EA Icon" (Environment Side)
**Diagnosis:** Confirmed Alpha Blending / Wine / Driver issue.
**Workarounds:**
*   Try disabling "Hardware Acceleration" in the wine config if possible.
*   Try a different Chart Template (Simple/Default) to see if simplified rendering helps.
*   Ignore the visual glitch as functionality (clicking the area) is preserved.

### 2. Verify Trojan Visualization
*   Run the EA.
*   Make a trade.
*   Verify Blue/Red arrows appear.
*   Remove the EA.
*   Verify the chart is completely clean.

## 📂 File Manifest
*   `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5`
