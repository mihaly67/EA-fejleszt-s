# Handover Report - Mimic Research EA v2.0 (Debugging Phase)

## 📅 Date: 2026.01.24
**Session Focus:** Development of `Mimic_Trap_Research_EA.mq5` (v2.0) for Data Mining.

## 🛠 Deliverables (Current State)
### 1. `Mimic_Trap_Research_EA.mq5`
*   **Path:** `Factory_System/Experts/Mimic_Trap_Research_EA.mq5`
*   **Purpose:** Manual Trap Execution + Continuous CSV Logging.
*   **Features:**
    *   **Continuous Logging:** Creates a new CSV on attach, logs every tick (Phase, Price, Physics, Indicators, P/L).
    *   **External Indicators:** Configured to load `HybridMomentum`, `HybridFlow`, and `VA` (Velocity/Accel).
    *   **Visualization:** Uses `ChartIndicatorAdd` to display these indicators on the chart automatically.
    *   **Configurable Path:** `InpIndPath` defaults to `"Jules\\"` (User Environment).

## ⚠️ Known Issues (BUG LIST - Next Session)
The user tested the current build and reported critical visualization/data errors:

1.  **HybridFlow Issue:** The indicator appears "empty" (blank or zero values) on the chart.
    *   *Hypothesis:* Parameter mismatch in `iCustom` or incorrect buffer index reading for the histogram.
2.  **HybridMomentum Issue:** Visualizes "meaningless lines" or "flattened bars" instead of the expected v2.81 curves. User suspects it might be loading an internal/wrong version or parameters are scrambled.
    *   *Action:* Must rigorously audit the `iCustom` parameter list against `HybridMomentumIndicator_v2.81.mq5` input by input.
3.  **Parameter Logic:** Confirmed that the EA **must** mirror the indicator's parameters exactly in its own Inputs to ensure the visualized instance matches the logged data.

## 🚀 Next Steps (Immediate Actions)
1.  **Strict Audit:** Open EA and Indicator source codes side-by-side. Verify every `input` type (int/double/enum) and order.
2.  **Debug Flow:** Check `HybridFlow` buffer indices (is the EA reading the calculation buffer or the drawing buffer?).
3.  **Validate Pathing:** Ensure `InpIndPath` + Name matches the actual file on the user's disk exactly.

_Session Closed. Ready for debugging._
