# Handover Report - 2026.01.24 (Final)
**Status:** Resolved / Stable
**Architecture:** `IndicatorCreate` Implementation

## 🔬 The "Void/Placeholder" Hypothesis
The user asked if `void` or `NULL` could be used to "trick" `iCustom` into filling the gap caused by `input group`.
*   **Result:** **Negative.** MQL5's `iCustom` function expects parameters to match the defined `input` variables. `input group` is not a variable type. Passing extra parameters (like `NULL` or strings) typically results in a "Wrong parameters count" error or type mismatch, rather than correcting the internal offset.
*   **Conclusion:** There is no safe way to "hack" `iCustom` to respect input groups.

## 🛠️ The Final Solution: `IndicatorCreate`
To satisfy both requirements:
1.  **Readability:** `input group` is kept in `Hybrid_Conviction_Monitor.mq5` (visual separators are active).
2.  **Stability:** The EA (`Mimic_Trap_Research_EA.mq5`) now uses `IndicatorCreate()` instead of `iCustom()`.

### How it works
Instead of blindly passing values, we define an explicit array of parameters:
```cpp
MqlParam params[8];
params[0].string_value = "Path/To/Indicator";
params[1].integer_value = InpFastPeriod; // Explicitly targeting the first integer input
...
```
This method is immune to the "Parameter Shift" bug because it maps values by type and structure, bypassing the ambiguous varargs parsing of `iCustom`.

## 📦 System State
*   **EA:** `Mimic_Trap_Research_EA.mq5` (v2.01) - Updated to use `IndicatorCreate`.
*   **Indicator:** `Hybrid_Conviction_Monitor.mq5` (v1.1) - Groups restored (`input group` active), warnings fixed.
*   **Environment:** Clean (Test scripts deleted).

## ✅ Verification
The system is now robust against parameter shifting while maintaining the user's preferred visual layout in the indicator settings.
