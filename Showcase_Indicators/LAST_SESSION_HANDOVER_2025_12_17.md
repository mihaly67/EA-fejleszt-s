# Session Handover - Hybrid Momentum Scaling & Visualization

## 🔴 Current Status: v1.5 Functional but Visually Flawed
The `HybridMomentumIndicator_v1.5.mq5` correctly implements:
1.  **Lag Reduction:** Signal Line uses DEMA (Faster response).
2.  **Soft Gate:** Low conviction signals are displayed as "Gray Ghosts" (Index 10) instead of holes.
3.  **Decoupled Math:** The histogram calculation mathematically removes the `SignalGain`.

**The Problem:**
Despite mathematical separation, **MQL5 indicators share a single Y-Axis** in a subwindow.
*   If `SignalGain` is high (to separate curves), the curves get large values.
*   If `HistScale` is also high, the histogram gets huge.
*   The Auto-Scale flattens whichever component is smaller relative to the other.
*   **User Feedback:** "The separation doesn't work because the scale is shared."

## 🔬 Research & Next Steps (Next Session)
The user has authorized a deep research phase to solve this "Multi-Scale" problem.

**Target Solutions to Investigate:**
1.  **Overlay Technique (`ChartIndicatorAdd`):**
    *   Can we spawn a *second* indicator (containing just the Histogram) and attach it to the *same subwindow* as the Curves, but with a different scale?
    *   MQL5 allows `ChartIndicatorAdd(0, subwindow_index, handle)`. Does it merge scales or keep them separate?
2.  **Normalization (Fixed Range):**
    *   Transform both MACD lines and Histogram to a fixed -100..+100 range (Oscillator style).
    *   This forces them to fill the screen regardless of raw price values.

## 📂 Key Artifacts
*   `Showcase_Indicators/HybridMomentumIndicator_v1.5.mq5` (Current Code)
*   `Showcase_Indicators/HASZNALATI_UTMUTATO_HybridMomentum.md` (Manual)

## 📌 Context for Agent
The user explicitly praised the **"Syntactic error-free MQL5 coding" (+1 Point)**.
Start the next session with **RAG Research** on `ChartIndicatorAdd` and dual-scale subwindows.
