# Session Handover - Hybrid Scalper Debugging Phase

## 🔴 Current Status: Prototype Live, Critical Bugs Identified
The environment is stable, and the "Hybrid Scalper" system files are in the repository. However, the user reports significant functional issues with the indicator (`Hybrid_MTF_Scalper.mq5`).

## 🐛 Known Bugs & User Feedback
1.  **No History Data:** The indicator shows a flat line (0) and only updates for new ticks.
    *   *Cause:* The `OnCalculate` optimization `limit = prev_calculated` is too aggressive or the `Amplitude_Booster` state isn't initializing correctly for historical bars.
2.  **Histogram Scaling Failed:** "Minden oszlop egyforma magas".
    *   *Cause:* The "Visual Auto-Scaling" logic is likely normalizing everything to 1.0 or failing to detect the true range.
3.  **Parameter Confusion:** User cannot find/adjust WPR and MACD settings easily.
    *   *Action:* Simplify `input` groups and names.

## 📂 Key Artifacts (All in `Showcase_Indicators/` & `MQL5/`)
*   `Hybrid_MTF_Scalper.mq5` (v2.1 - Needs Fix)
*   `Amplitude_Booster.mqh` (v2.0 - Working, but needs sequential feed)
*   `Test_Amplitude_Booster.mq5` (Test Script)
*   `INSTALL_GUIDE.md` (Reference)

## 🚀 Tasks for Next Session (Immediate)
1.  **Refactor `Hybrid_MTF_Scalper.mq5`:**
    *   **Force History Calculation:** Ensure `limit = 0` runs on the first call to populate the chart history.
    *   **Simplify Histogram:** Remove complex auto-scaling. Use a simple manual multiplier input (e.g., `InpHistScale = 1.0`).
    *   **Ungroup Inputs:** Flatten the input parameters for better visibility in MetaTrader.
2.  **Verify Booster Logic:** Ensure `Amplitude_Booster` can handle a historical loop without resetting incorrectly.

## 📌 Context for Agent
The user is testing on **Crypto** (weekend). Focus on **robustness** and **usability** (fixing the flat line) before adding new features. The goal is a working, visible curve on the chart history.
