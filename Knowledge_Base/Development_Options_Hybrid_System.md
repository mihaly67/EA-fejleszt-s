# Hybrid System Development Options

Based on deep research into Lag-Free Scalping, here are the three concrete development paths identified:

## 1. "The Robust Scalper" (MQL5 - ALMA + IFT)
*   **Concept:** Pure MQL5 speed using advanced digital filters.
*   **Noise Reduction:** Use **ALMA (Arnaud Legoux Moving Average)** with `Offset = 0.99`. This pushes the weighting to the most recent bars, practically eliminating lag compared to EMA/SMA.
*   **MTF Logic:** M1 ALMA signal filtered by M5 Trend direction.
*   **Lag Compensation:** Immediate **Inverse Fisher Transform (IFT)** normalization to "stretch" the flattened signals so they cross levels (0.8/-0.8) earlier.
*   **Pros:** Extremely fast execution, no external dependencies, mathematically robust.

## 2. "The Adaptive Booster" (MQL5 - AGC)
*   **Concept:** Solves the specific problem of "flattened curves" causing delayed signals.
*   **Core Component:** **`Amplitude_Booster.mqh`** library implementing **AGC (Automatic Gain Control)**.
*   **Logic:** The system monitors the signal's amplitude over a sliding window. If volatility drops and the curve flattens (e.g., oscillating between -0.2 and +0.2 instead of -1 and +1), the AGC dynamically amplifies the signal to fill the range [-1, +1].
*   **Benefit:** Allows the use of heavy smoothing (Kalman/DEMA) without losing signal timing. The crossing happens on time because the slope is restored.

## 3. "The Hybrid Motor" (Python - Kalman + CUSUM)
*   **Concept:** Offloading complex math to a Python co-pilot.
*   **Noise Reduction:** **Non-linear Kalman Filter** (via `pykalman`) which adapts covariance dynamically.
*   **Signal Detection:** Instead of level crossings, use **CUSUM (Cumulative Sum)** filters to statistically detect significant shifts away from the noise floor.
*   **Pros:** Mathematically superior signal quality.
*   **Cons:** Architecture complexity (Python must run in background).

## Selected Path
**Start with Option 2 (Amplitude Booster)** and integrate it into **Option 1 (Hybrid MTF Scalper)**. This provides a robust, standalone MQL5 solution that directly addresses the user's concern about "flattened curves" causing lag.
