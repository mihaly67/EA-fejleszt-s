# Handover Report - 2026.01.24 (Final & Next Steps)
**Status:** Stable / Functional
**Current Fix:** `Ungrouped` Parameters (Groups removed for stability)

## 🛑 Summary of the "Parameter Shift" Issue
*   **Problem:** Using `input group` in MQL5 indicators causes input parameter indexes to shift when called programmatically (`iCustom` or `IndicatorCreate`), leading to data corruption or type errors in the EA.
*   **Verified Fact:** This behavior necessitates removing `input group` to guarantee EA stability.

## 💡 NEXT SESSION: The "Naming Convention" Solution
The user specified a robust strategy to restore "readability" without using the broken `input group` feature.

### 🎯 Strategy: Group Context in Parameters
We will rename/comment the inputs so they appear grouped in the UI.

**Plan A (Comment-based - Cleaner):**
MQL5 uses trailing comments as UI labels.
```cpp
input uint InpFastPeriod = 5; // [DEMA] Fast Period
```
*If this appears correctly in the panel, it is the preferred method.*

**Plan B (Variable Name - Fallback):**
If comments are not sufficient, we rename the variables themselves.
```cpp
input uint InpFastPeriod_DEMA = 5;
```

### 📋 Action Items for Next Developer
1.  **Refactor Indicator:** Apply Plan A to `Hybrid_Conviction_Monitor.mq5`.
2.  **Sync EA:** Update `Mimic_Trap_Research_EA.mq5` to match any variable name changes (if Plan B is used).
3.  **Verify:** Ensure the EA panel shows "meaningful" labels to the user.

## 📦 System State (v2.04)
*   **EA:** `Mimic_Trap_Research_EA.mq5` (v2.04) - Using `IndicatorCreate` with 7 strict parameters.
*   **Indicator:** `Hybrid_Conviction_Monitor.mq5` (v1.2) - Ungrouped.
