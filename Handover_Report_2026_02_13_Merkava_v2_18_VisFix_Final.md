# Handover Report: Merkava v2.18 Critical Visualization Fix (v3)

**Date:** 2026-02-13
**Version:** v2.18
**Author:** Jules (AI Assistant)

## Issue Description
Users reported severe visual artifacts ("huge black squares") when running Merkava v2.18. This was traced to the `HybridContextIndicator` attempting to draw invisible buffers (Pivot Points) which contained valid but non-visual data. The previous attempt to use `DRAW_NONE` was insufficient because the buffers were still treated as `INDICATOR_DATA` by the rendering engine in some contexts.

## Summary of Changes

### 1. HybridContextIndicator v3.18 (Final Visualization Fix)
*   **Buffer Retyping:** Changed the "Hidden" Pivot Buffers (Indices 0, 3, 6) from `INDICATOR_DATA` to `INDICATOR_CALCULATIONS`.
    *   **Effect:** Buffers marked as `CALCULATIONS` are *never* sent to the chart rendering pipeline. They are purely for internal calculation and external access via `CopyBuffer` (which `NavSystem` uses). This guarantees no visual artifacts (black squares/lines) can occur from these buffers.
*   **Visible Plots:** Reduced `indicator_plots` from 11 to 8 (only R, S, and Trend lines are plots).
*   **Buffer Mapping:** Updated `SetIndexBuffer` calls to reflect the mixed types while preserving the index order (0-10) required by `NavSystem`.
*   **Style:** Visible lines (R/S) are now `STYLE_SOLID` for clarity.

### 2. Merkava v2.18 & NavSystem v2.10
*   No changes were required to the EA or NavSystem code because `CopyBuffer` accesses buffers by index regardless of their type (Data vs Calculation). The data flow remains intact and correct.

## Files
*   `MQL5/Indicators/Jules/HybridContextIndicator_v3.18.mq5` (Updated with `INDICATOR_CALCULATIONS`)
*   `MQL5/Indicators/Jules/Merkava_v2_18.mq5` (Unchanged, included for completeness)
*   `MQL5/Indicators/Indicators/NavSystem_v2_10.mqh` (Unchanged, included for completeness)

## Usage Instructions
1.  **Compile:** Compile `Merkava_v2_18.mq5`.
2.  **Verify:** Run the EA. The chart should now be perfectly clean, displaying only the valid Support/Resistance lines (Red/Green solid lines) and Trend lines (Orange/Turquoise). The "black squares" artifact is architecturally impossible with this change.
