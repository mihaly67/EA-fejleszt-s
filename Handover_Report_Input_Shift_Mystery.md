# Handover Report - The "Parameter Shift" Mystery

## 📅 Date: 2026.01.24
**Session Status:** Stuck on "Parameter Hallucination/Shift" bug.
**Current Branch:** `fix/mimic-ea-parameter-names`

## 🚨 The Issue
When `Mimic_Trap_Research_EA` calls `Hybrid_Conviction_Monitor` via `iCustom`, the input parameters appear **shifted** on the EA's property panel or in execution.
*   *Example:* The value for `InpSlowPeriod` (13) might appear in `InpFastPeriod`, or `InpDemaGain` (1.0) appears as 500 (the value of `InpNormPeriod`).
*   The logic is correct in code, but the runtime mapping is broken.

## 🛠 Status of Components
| Component | Status | Inputs | Notes |
| :--- | :--- | :--- | :--- |
| **VA (Velocity/Accel)** | ✅ **Working** | `uint`, `uint`, `ENUM` | **No Input Groups**. Simple structure. |
| **WVF (Williams Vix)** | ✅ **Working** | `uint`, `ENUM` | **No Input Groups**. Simple structure. |
| **Hybrid Conviction** | ❌ **Broken** | 7 params (`uint`, `double`) | **Has Input Groups**. Values are shifted. |
| **Hybrid Momentum** | 🗑️ **Removed** | Mixed (`int`, `enum`, `bool`) | Removed to simplify debugging. Was shifting. |
| **Hybrid Flow** | 🗑️ **Removed** | Mixed (`bool`, `int`) | Removed to simplify debugging. |

## 🧪 Attempted Fixes (All Failed to Fix Shift)
1.  **Type Sync**: Converted all `int` periods to `uint` (matching VA/WVF).
2.  **Explicit Casting**: Used `(uint)`, `(double)` casts in `iCustom` call.
3.  **Visual Parity**: Mirrored `input group` lines exactly in the EA.
4.  **Name Sync**: Renamed EA inputs to match Indicator inputs exactly (forcing cache reset).

## 🕵️ Hypothesis for Next Session
The "Smoking Gun" is likely **`input group`**.
*   Both working indicators (VA, WVF) do **not** use `input group`.
*   The failing indicator (Conviction) **does** use `input group`.
*   **Theory:** In MQL5, `input group` strings might effectively inject a hidden parameter or alter the memory alignment/offset of the input structure when accessed via `iCustom`, causing the values to "slide" by one position per group.

## 📝 Tasks for Next Session (Research & Fix)
**Objective:** Solve the parameter shift mystery using RAG research.

1.  **Prepare Researcher:**
    *   Ensure `kutato_ugynok_v3.py` is ready.
    *   Target Databases: `rag_theory` (MQL5 Internal mechanics) and `rag_code` (EAs with iCustom).

2.  **Execute Queries:**
    *   *"Does input group affect iCustom parameter order?"*
    *   *"MQL5 iCustom parameter shifting issue"*
    *   *"Passing parameters to indicator with input groups"*

3.  **Test Protocol (The "Group Removal" Test):**
    *   Create a temporary version of `Hybrid_Conviction_Monitor` **WITHOUT** any `input group` lines.
    *   Test if the EA (modified to match) reads it correctly.
    *   If it works, we have proven that `input group` is the cause. We must then find the syntax to skip/handle groups in `iCustom` (e.g., passing a string for the group?).

4.  **Final Fix:**
    *   Apply the finding to restore Momentum and Flow.
