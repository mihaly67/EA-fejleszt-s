# Handover Report: Merkava v2.18 Critical Fix (Buffer & Visual Artifacts)

**Date:** 2026-02-13
**Version:** v2.18
**Author:** Jules (AI Assistant)

## Issue Description
Users reported severe visual artifacts ("huge black squares" and "staircase lines") and slow loading times when running Merkava v2.17. Debugging revealed this was caused by the EA/NavSystem reading `EMPTY_VALUE` (DBL_MAX) from the `HybridContextIndicator` buffers and attempting to process or draw them, resulting in scale distortion and graphic glitches. Additionally, the Fibo lines were appearing despite being disabled in settings.

## Summary of Changes

### 1. NavSystem v2.10 (Fix)
*   **Buffer Sanitization:** Implemented a rigorous check in `Refresh()`:
    ```cpp
    if(b[0]==EMPTY_VALUE || b[0]==DBL_MAX) val = 0.0;
    ```
    This ensures that any "empty" sections of the pivot lines are returned as `0.0` to the EA, preventing the "black square" artifacts caused by drawing infinite values.
*   **Fibo Force-Off:** Explicitly passes `false` and `0` to the `iCustom` call for the Fibo parameters, overriding any potential struct misalignment or default value issues.

### 2. Merkava v2.18 (Fix)
*   **Integration:** Updated to use `NavSystem_v2_10.mqh`.
*   **Debug Logging:** Added a temporary debug log in `OnTick` (every 10 ticks) to print the raw Micro/Sec/Ter R & S values. This allows verification that the values are now correct (e.g., actual prices or 0.0) and not `1.79769e+308`.
*   **Safety:** Retains all v2.17 features (Extended CSV, Profit Management).

### 3. HybridContextIndicator v3.18
*   *No changes to the indicator file itself were necessary for this specific fix, as the issue was in how the data was being consumed.* However, using `v3.18` is required for the embedded ZigZag logic.

## Files
*   `MQL5/Indicators/Jules/Merkava_v2_18.mq5`
*   `MQL5/Indicators/Indicators/NavSystem_v2_10.mqh`

## Usage Instructions
1.  **Compile:** Compile `Merkava_v2_18.mq5`.
2.  **Verify:** Run the EA. The "black squares" should be gone. The Journal will show "DEBUG TICK" logs. If these logs show valid prices (e.g., 1.0543) or 0.0, the fix is working.
3.  **Performance:** Loading times should improve as the EA is no longer struggling with DBL_MAX calculations.
