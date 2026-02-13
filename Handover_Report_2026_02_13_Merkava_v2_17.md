# Handover Report: Merkava v2.17 Ecosystem Upgrade (HybridContext v3.18)

**Date:** 2026-02-13
**Version:** v2.17
**Author:** Jules (AI Assistant)

## Summary of Changes

This release upgrades the entire Merkava ecosystem to fully integrate the new **HybridContextIndicator v3.18** (which features embedded ZigZag logic) and expands the **BlackBox** CSV logging capabilities to include detailed pivot analysis data.

### 1. Hybrid Context Indicator v3.18
*   **Self-Contained Logic:** Implemented `CZigZagEngine` to remove external dependencies (`iCustom` calls to `Examples\ZigZag`).
*   **Stability:** Eliminates potential crashes caused by external indicator failures.
*   **Input Compatibility:** Retains 1:1 input parameter compatibility with v3.17.

### 2. NavSystem v2.09
*   **Integration:** Updated initialization logic to load `HybridContextIndicator_v3.18`.
*   **Data Retrieval:** Ensures all 11 context buffers (Micro P/R/S, Secondary P/R/S, Tertiary P/R/S, Trend Fast/Slow) are correctly fetched.

### 3. BlackBox v2.07
*   **Extended Logging:** The CSV header and `RecordTick` function now explicitly support 11 context-related fields:
    *   **Micro:** `Mic_P`, `Mic_R`, `Mic_S`
    *   **Secondary:** `Sec_P`, `Sec_R`, `Sec_S`
    *   **Tertiary:** `Ter_P`, `Ter_R`, `Ter_S`
    *   **Trends:** `Trend_Fast`, `Trend_Slow`
*   **Note:** This exceeds the requested "8 columns" by including the Pivot Points (P) as well, providing a complete dataset for ML/RL analysis.

### 4. Merkava v2.17
*   **Core Update:** Updated `#include` directives to use `NavSystem_v2_09.mqh` and `BlackBox_v2_07.mqh`.
*   **Configuration:** Default `InpContextPath` is now set to `Jules\HybridContextIndicator_v3.18`.
*   **Data Flow:** Correctly passes the expanded dataset from `NavSystem` to `BlackBox` during every tick.

## Files
*   `MQL5/Indicators/Jules/Merkava_v2_17.mq5`
*   `MQL5/Indicators/Jules/HybridContextIndicator_v3.18.mq5`
*   `MQL5/Indicators/Indicators/NavSystem_v2_09.mqh`
*   `MQL5/Indicators/Indicators/BlackBox_v2_07.mqh`

## Usage Instructions
1.  **Compile:** Compile `Merkava_v2_17.mq5`. This will automatically compile the dependent libraries.
2.  **Deploy:** Use `Merkava_v2_17` on your charts.
3.  **Verify:** Check the `MQL5/Files/` directory for the new CSV logs. They should now contain the expanded columns for pivot analysis.
