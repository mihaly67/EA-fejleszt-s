# Session Handover Report: Merkava Project (2026-02-15)

**Date:** 2026.02.15 04:23
**Status:** Stable / Combat Ready
**Last Version:** Merkava v2.30

## Executive Summary
This session successfully resolved critical visualization and integration issues with the `HybridContextIndicator`. The previous "invisible pivot lines" and "confused trend lines" were traced to a mismatch between MQL5's `ChartIndicatorAdd` mechanism and the indicator's buffer architecture. By reordering buffers (visible data first, hidden calculations last) and flattening input parameters (removing groups), we achieved stable visualization and correct data flow. Dynamic versioning was also implemented for the UI panel.

## Achievements

### 1. Visualization & Buffer Reordering (SOLVED)
*   **Problem:** Pivot lines were invisible or trend lines appeared as stepped pivots.
*   **Root Cause:** MQL5 `iCustom` and `ChartIndicatorAdd` logic struggles when `INDICATOR_DATA` (visible) and `INDICATOR_CALCULATIONS` (hidden) buffers are interleaved.
*   **Solution:** Created `HybridContextIndicator_v3.27_StyleFix.mq5`.
    *   **New Architecture:** Buffers 0-7 are exclusively `INDICATOR_DATA` (Visible Plots). Buffers 8-10 are `INDICATOR_CALCULATIONS` (Hidden).
    *   **Result:** Lines render correctly on the main chart window.

### 2. Parameter Integrity (SOLVED)
*   **Problem:** Colors and styles were shifting, likely due to `input group` separators in the indicator properties interfering with `iCustom` parameter passing.
*   **Solution:** Removed all `input group` lines from the indicator (v3.27) and the EA (v2.30), enforcing a strictly linear parameter list.

### 3. Styling & UX (SOLVED)
*   **Styling:** Applied `STYLE_DOT` to Micro Pivots as requested.
*   **Versioning:** Updated `PanelControl_v2_21.mqh` to accept a dynamic version string. `Merkava_v2_30.mq5` passes "MERKAVA v2.30" during initialization, removing the need to edit the panel library for version bumps.

## Files State (Golden Copy)
*   **EA:** `MQL5/Indicators/Jules/Merkava_v2_30.mq5` (The Master EA)
*   **Navigation:** `MQL5/Indicators/Indicators/NavSystem_v2_20.mqh` (The Integration Layer)
*   **Indicator:** `MQL5/Indicators/Jules/HybridContextIndicator_v3.27_StyleFix.mq5` (The Visual Logic)
*   **Panel:** `MQL5/Indicators/Indicators/PanelControl_v2_21.mqh` (The UI)
*   **Logging:** `MQL5/Indicators/Indicators/BlackBox_v2_09.mqh` (The Recorder)

## Critical Learnings (Memory Updated)
*   **Buffer Order:** When using `ChartIndicatorAdd`, visible buffers **MUST** be defined first (0..N) and contiguous. Hidden buffers must follow at the end.
*   **Input Groups:** Avoid `input group` in indicators intended for `iCustom` calls if strict parameter alignment is critical; they can introduce subtle shifts in complex parameter lists.
*   **Dynamic UI:** Always pass version/state strings to UI classes via `Init()` rather than hardcoding them.

## Next Session Roadmap
**Primary Objective:** Repair and Upgrade RAG & JSONL Research Tools.
*   **Task:** Fix `kutato.py` and `kutato_v3_adapter.py` to correctly interface with the RAG database and handle JSONL source files, which were reported as missing/empty in this session.
