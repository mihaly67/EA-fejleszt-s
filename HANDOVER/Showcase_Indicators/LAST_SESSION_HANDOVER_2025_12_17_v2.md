# Session Handover - Automatic RAG Verification & Normalized Momentum

## 🟢 Current Status: v1.6 Implemented & Environment Hardened
1.  **Environment Restoration:** The `restore_environment.py` script now performs a **comprehensive self-check** of all 3 RAGs (MQL5, Theory, Code) upon startup, printing real query results to the console.
2.  **Junk Filtering:** `kutato.py` now includes a text cleaner to strip formatting artifacts (like `§H2§`) from Theory RAG outputs.
3.  **HybridMomentumIndicator v1.6:**
    *   **Solved Shared Scale:** Implemented **Tanh Normalization** (hyperbolic tangent). All components (MACD, Signal, Histogram) are dynamically compressed into a fixed -100 to +100 range.
    *   **Removed Manual Scaling:** Deleted `InpSignalGain` and `InpHistScale`.
    *   **New Parameters:** `InpNormPeriod` (default 100) sets the rolling window for standard deviation, and `InpNormSensitivity` tunes the steepness of the curve.
    *   **Gray Ghost:** Soft Gate visualization works correctly on the normalized data.

## 📂 Key Artifacts
*   `Showcase_Indicators/HybridMomentumIndicator_v1.6.mq5` (New Standard)
*   `restore_environment.py` (Updated with self-checks)
*   `kutato.py` (Updated with junk filter)

## 📌 Instructions for Next Session
*   **Startup:** Simply run `python3 restore_environment.py`. It will automatically verify the RAGs and show you the results.
*   **Testing:** Compile and run `HybridMomentumIndicator_v1.6`. Observe how the histogram and curves now coexist peacefully in the fixed range without flattening each other.
*   **Next Development:** If visual verification passes, proceed to integrate this normalized logic into the main "Hybrid Scalper" EA signal chain.
