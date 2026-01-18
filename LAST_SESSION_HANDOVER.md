# Handover Report - Trojan Horse v3.0 History Fix

## 📅 Session Summary
**Focus:**
1.  **Trojan Horse EA v3.0 - Ghost Object Fix:** Addressing the issue where historical trade arrows and lines would reappear (from the Terminal's history) when the EA was restarted, even after being deleted.

**Outcome:**
*   **Root Cause Identified:** The MT5 Terminal's "Show Trade History" property (`CHART_SHOW_TRADE_HISTORY`) causes the terminal to automatically redraw history objects for the account's trades, overriding the EA's cleanup attempts.
*   **Solution:** The EA now explicitly sets `ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false)` in `OnInit` to disable this behavior.
*   **Behavior:**
    1.  **Startup:** The EA runs `CleanupChart()` and disables history drawing immediately.
    2.  **Shutdown:** The EA runs `CleanupChart()` in `OnDeinit` to leave a clean chart.

## 🛠 System Changes

### 1. Trojan Horse EA v3.0
*   **File:** `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5`
*   **Changes:**
    *   Added `ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);` to `OnInit`.
    *   Added `CleanupChart()` call to `OnInit` (in addition to `OnDeinit`).
*   **Impact:** Prevents "Ghost Arrows" from reappearing when the EA is restarted.

## 📝 User Instructions (Next Session)
1.  **Verify Fix:**
    *   Attach `Trojan_Horse_EA_v3.0` to a chart that has old trade history arrows.
    *   **Expectation:** The arrows should vanish immediately upon attachment.
    *   Close the EA.
    *   **Expectation:** The chart remains clean.
    *   Attach the EA again.
    *   **Expectation:** The chart remains clean (no old arrows reappear).

## 📂 File Manifest
*   `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5` (Updated with History Disable)
