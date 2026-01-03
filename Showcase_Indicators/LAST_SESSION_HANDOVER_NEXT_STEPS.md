# Session Handover - Next Steps for HybridContextIndicator v3.6

## 🔴 Current Status
*   **Last Tested Version:** `v3.5`
*   **Verdict:** **FAILED**. The Secondary (M30) and Tertiary (H1) pivots were drawn as `OBJ_HLINE` (Chart Objects), which appear as infinite lines across the chart. This hides the historical progression ("steps") of the pivot levels, making backtesting and visual analysis impossible.
*   **Environment:** The `rag_mql5_dev` database was restored (renamed from `rag_mql5`) and is now fully functional for research.

## 📝 Plan for Next Session: `v3.6` Implementation

The goal is to create `HybridContextIndicator_v3.6.mq5` to solve the "Infinite Line" and "Cascading" issues.

### 1. Visualization Fix (Critical)
*   **Action:** Convert Secondary and Tertiary Pivots from **Objects** to **Indicator Buffers**.
*   **Detail:** Increase `#property indicator_buffers` to 11 (3 tiers * 3 lines + 2 trends).
*   **Result:** This will render the pivot levels as "Stepped Lines" (like a stair), showing exactly where the levels changed historically.

### 2. Logic Implementation: "Cascading Reference"
*   **Requirement:** The user requested a "Rolling/Cascading" logic where the Primary (M15) pivot dictates the reference for the higher timeframes.
*   **Algorithm:**
    1.  Calculate `shift_pri = iBarShift(..., time[i])` to find the **Primary (M15) Bar**.
    2.  Get `time_pri = iTime(..., shift_pri)` -> The **Start Time** of that M15 block.
    3.  Use `time_pri` (NOT `time[i]`) to look up the correct M30 and H1 pivot values (`GetPivotData`).
*   **Benefit:** This ensures that the M30 and H1 levels only "step" or update when they structurally align with the Primary M15 block, creating a clean hierarchical view.

### 3. Fibo Fixes (Maintain)
*   Ensure the v3.3/v3.5 fixes for **Smart Fibo** are preserved:
    *   **Creeping Zero Fix:** Scan for High/Low starting from index `1` (completed bars).
    *   **Auto-Reverse:** Flip 0/100 based on Swing direction.
    *   **Manual Lock:** Respect `OBJPROP_SELECTED` to pause updates.

## 📂 Code Reference
The drafted code for v3.6 (including the 11-buffer setup and Cascading Reference logic) was generated in the previous session's chat log and should be used as the base.
