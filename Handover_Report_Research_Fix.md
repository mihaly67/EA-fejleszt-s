# Handover Report - 2026.01.24 (Corrected Final)
**Status:** Resolved / Stable
**Architecture:** `IndicatorCreate` Implementation (Clean)

## 🔬 "Dummy String" Hypothesis - REJECTED
Attempts to "shift" the parameter list by inserting dummy strings into the `IndicatorCreate` call (to account for visual groups) were technically unsound.
*   **Result:** Type mismatch errors or critical failures.
*   **Reason:** `IndicatorCreate` requires a 1-to-1 mapping with actual `input` variables. Groups are not variables.

## 🛠️ The Final Solution: Clean `IndicatorCreate`
To satisfy both requirements:
1.  **Readability:** `input group` is kept in `Hybrid_Conviction_Monitor.mq5` (visual separators are active).
2.  **Stability:** The EA (`Mimic_Trap_Research_EA.mq5`) uses `IndicatorCreate()` with a **strict** parameter array.

### How it works
We explicitly define only the **7 real inputs** in the `MqlParam` array. We completely ignore the visual groups in the parameter construction.
```cpp
MqlParam params[8]; // 1 Path + 7 Real Inputs
params[0].string_value = "Path/To/Indicator";
params[1].integer_value = InpFastPeriod; // Direct map to 1st variable
// ...
```
This forces MQL5 to bind values to variables by type and sequence, bypassing the ambiguity that caused the "Parameter Shift" when using `iCustom`.

## 📦 System State
*   **EA:** `Mimic_Trap_Research_EA.mq5` (v2.03) - Updated to use `IndicatorCreate` (Clean).
*   **Indicator:** `Hybrid_Conviction_Monitor.mq5` (v1.1) - Groups active (`input group`), warnings fixed.
*   **Environment:** Clean.

## ✅ Verification
The system correctly maps EA inputs to the Indicator without shifting, while preserving the visual groups in the Indicator's settings panel.
