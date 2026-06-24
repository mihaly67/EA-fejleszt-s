# Session Handover - Indicator Fine-Tuning (Final Polish)

## 🟢 Current Status: Indicators "Unlocked" & Adaptive
The user has validated the fine-tuning of the core indicators. The system is now responsive to low-volatility "night" conditions and visually accurate for extreme volume flows.

## 📂 Key Artifacts (Factory Ready)
*   **`HybridMomentumIndicator_v2.5.mq5` (Factory_System/Indicators/)**
    *   **Feature:** Adaptive Volatility Boost.
    *   **Logic:** Uses an **Inverse Volatility** formula (`Multiplier = 1 + (Max-1)*exp(-Vol)`) to inject Stochastic momentum (5-3-3) into the MACD line when the market is flat.
    *   **Benefit:** Prevents the "sluggishness" of the Kalman filter in ranging markets without adding noise to trends.
    *   **Visuals:** Fixed Signal Line visibility (Solid/2px).

*   **`HybridFlowIndicator_v1.10.mq5` (Factory_System/Indicators/)**
    *   **Feature:** Unbounded Peaks & Auto-Scaling.
    *   **Logic:** Implements "Hybrid MFI" by adding the Scaled Delta offset to a **hidden Raw MFI buffer**. This prevents `CopyBuffer` from overwriting history on every tick, allowing the curve to retain its "boosted" shape (exceeding 0/100) across updates.
    *   **Visuals:** Default `InpUseFixedScale=false` allows the chart to expand dynamically to fit peaks (e.g., 150+).

*   **`Hybrid_SMI_Histogram.mq5` (Showcase_Indicators/)**
    *   **Role:** Backup/Confirmation.
    *   **Logic:** Standard Stochastic Momentum Index.

## 🔧 Technical Insights
*   **Buffer Management:** For cumulative/hybrid indicators in MQL5, `CopyBuffer` must target a *separate* array (RawBuffer), not the display buffer, if the display buffer contains calculated offsets. Otherwise, the history resets on every tick.
*   **Plot Indices:** `PlotIndexSetInteger` uses *visual* plot indices (0..N), which may not match Buffer indices. Mismatch causes invisible lines.

## 📌 Next Steps (New Session)
1.  **EA Assembly:** The indicators are now considered "Final". The next logical step is to integrate them into the `Hybrid_Visual_Assistant` (EA).
2.  **Live Testing:** Continue monitoring v2.5 and v1.10 behaviors on live charts.

## 🕒 Timestamp
Session completed: 2025-12-22.
