# Handover Report: Merkava Test Protocol (v2.19 HybridMomentum & v3.18 VisFix)

**Date:** 2026-02-13
**Version:** v2.19 (Test) & v2.18 (Fix)
**Author:** Jules (AI Assistant)

## Summary of Changes

This release provides **two distinct paths** to solve the visualization issues and verify system integrity:

1.  **Merkava v2.18 (Production Fix):**
    *   Integrates `HybridContextIndicator v3.18` (Self-contained ZigZag).
    *   **FIX:** The indicator now uses `INDICATOR_CALCULATIONS` for hidden buffers (Pivot P) and `STYLE_SOLID` for visible buffers (R/S). This guarantees that hidden data cannot cause "black square" artifacts on the chart, while remaining accessible to the EA logic.

2.  **Merkava v2.19 (Diagnostic Test):**
    *   **Purpose:** To verify if the EA's indicator loading mechanism (`NavSystem`) is working correctly by testing with a completely different, known-good indicator (`HybridMomentumIndicator v2.82`).
    *   **Changes:**
        *   Replaced `HybridContextIndicator` logic with `HybridMomentumIndicator_v2.82` integration.
        *   Updated `NavSystem` to load the new indicator into a separate subwindow (3).
        *   Updated `BlackBox` to log Momentum Histogram, MACD, and Signal values instead of Pivot levels.
        *   Exposed all v2.82 input parameters in the EA.

## Files

### Production Fix (Context ZigZag)
*   `MQL5/Indicators/Jules/Merkava_v2_18.mq5` (Context Integration)
*   `MQL5/Indicators/Jules/HybridContextIndicator_v3.18.mq5` (Visual Fix + Embedded ZigZag)
*   `MQL5/Indicators/Indicators/NavSystem_v2_10.mqh` (Context Support)
*   `MQL5/Indicators/Indicators/BlackBox_v2_07.mqh` (Context Logging)

### Diagnostic Test (Momentum 2.82)
*   `MQL5/Indicators/Jules/Merkava_v2_19.mq5` (Momentum Integration)
*   `MQL5/Indicators/Jules/HybridMomentumIndicator_v2.82.mq5` (External Indicator)
*   `MQL5/Indicators/Indicators/NavSystem_v2_11.mqh` (Momentum Support)
*   `MQL5/Indicators/Indicators/BlackBox_v2_08.mqh` (Momentum Logging)

## Usage Instructions

**To Verify the Fix (Priority):**
1.  Compile and run `Merkava_v2_18.mq5`.
2.  Check the chart. The black artifacts should be gone, replaced by clean solid pivot lines.

**To Perform the Control Test (If artifacts persist in v2.18):**
1.  Compile and run `Merkava_v2_19.mq5`.
2.  Check if `HybridMomentumIndicator` appears in a subwindow and functions correctly.
3.  If v2.19 works but v2.18 still has artifacts, the issue is strictly within the Context Indicator's rendering pipeline (though v3.18 fixes are designed to eliminate this).
