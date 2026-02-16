# Session Handover - Stabilized & Advanced Momentum

## 🟢 Current Status: v1.8 Stabilized (Gain Control)
1.  **Overshoot Protection (DEMA Gain):** Introduced `InpDemaGain` to allow fine-tuning the DEMA "boost" factor.
    *   **Default:** `2.0` (Standard DEMA).
    *   **Recommendation:** If the indicator shows false reversals in long, smooth trends, reduce this to **1.5 - 1.8**. This dampens the "overshoot artifact" while retaining speed.
2.  **Phase Advance:** The logic from v1.7 is preserved (`InpPhaseAdvance`), helping to shift crossovers earlier.
3.  **Normalization:** Tanh Normalization ensures the histogram and curves share the Y-axis peacefully.

## 📂 Key Artifacts
*   `Showcase_Indicators/HybridMomentumIndicator_v1.8.mq5` (Current Best)
*   `Showcase_Indicators/HybridMomentumIndicator_v1.7.mq5` (Phase Advance Only)

## 📌 Instructions for Next Session
*   **Optimization:** The DEMA loop currently recalculates full history for stability. For a production EA, this should be optimized to use incremental buffers or `iDEMA` handles if the gain factor is fixed to 2.0.
*   **Visual Check:** Verify that reducing `InpDemaGain` eliminates the "false crossover" in 30-40 min trends as reported.
*   **Next Step:** Integrate this logic into the "Hybrid Scalper" EA as the primary signal engine.
