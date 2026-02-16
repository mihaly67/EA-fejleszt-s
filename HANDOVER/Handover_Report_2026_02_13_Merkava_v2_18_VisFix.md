# Handover Report: Merkava v2.18 Critical Visualization Fix (v2)

**Date:** 2026-02-13
**Version:** v2.18
**Author:** Jules (AI Assistant)

## Issue Description
Users reported severe visual artifacts ("huge black squares") when running Merkava v2.18, even though the data logged was correct (as proven by debug logs). Investigation confirmed this was a rendering issue within the `HybridContextIndicator` when attached by an EA, likely caused by `STYLE_DOT` artifacts or hidden buffers (`DRAW_NONE`) being rendered improperly (e.g., as lines at 0.0).

## Summary of Changes

### 1. HybridContextIndicator v3.18 (Visualization Fix)
*   **Style Update:** Changed the default style for visible Pivot Lines (R1, S1) from `STYLE_DOT` to `STYLE_SOLID`. This ensures clear, unambiguous lines are drawn.
*   **Hidden Buffer Enforcement:** Explicitly set `PLOT_DRAW_TYPE` to `DRAW_NONE` and `PLOT_SHOW_DATA` to `false` for the internal Pivot Point (P) buffers (Indices 0, 3, 6).
*   **Value Initialization:** Updated the calculation loop to initialize empty buffer values to `0.0` instead of `EMPTY_VALUE` (DBL_MAX) when a tier is disabled. This prevents "infinite" lines from being drawn if the EA attempts to render them.

### 2. Merkava v2.18 & NavSystem v2.10
*   These files remain chemically identical to the previous submission but rely on the updated indicator file for the visual fix.
*   Debug logging confirms data integrity is perfect.

## Files
*   `MQL5/Indicators/Jules/HybridContextIndicator_v3.18.mq5` (Updated)
*   `MQL5/Indicators/Jules/Merkava_v2_18.mq5` (Unchanged from previous fix, included for completeness)
*   `MQL5/Indicators/Indicators/NavSystem_v2_10.mqh` (Unchanged from previous fix, included for completeness)

## Usage Instructions
1.  **Compile:** Compile `Merkava_v2_18.mq5`.
2.  **Verify:** Run the EA. The "black squares" should be completely gone, replaced by solid Red/Green lines for the pivot levels.
3.  **Note:** If you preferred dots, you can change the input parameter `InpMicroStyle` back to `STYLE_DOT`, but `STYLE_SOLID` is recommended for stability.
