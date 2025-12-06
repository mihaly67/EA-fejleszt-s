# Research Report: Hybrid Scalper Strategy (Simulated)

## Overview
Due to the unavailability of the RAG environment (missing environment variables for download), this report is based on the analysis of existing `Showcase_Indicators` and expert knowledge of MQL5 scalping strategies.

## Objective
Design a "Hybrid Scalper" indicator for 1-3 minute timeframes that is:
1. **Lag-Free:** Utilizing advanced smoothing (HMA, JMA).
2. **Noise-Reduced:** Filtering out low-volatility regimes.
3. **Composite:** Combining Momentum (Velocity) and Trend.

## Existing Showcase Analysis
- **Hybrid_Conviction_Oscillator (v2.00):**
  - Fuses MACD, RSI, and Velocity.
  - Uses `InverseFisher` for normalization.
  - *Current Weakness:* Uses `CalculateLWMA` (Linear Weighted MA) which has some lag compared to HMA/JMA.
- **Stoch_Hybrid_Showcase:**
  - Uses TEMA-smoothed Stochastic.
  - Good volatility filter (ATR).

## Proposed Strategy: "Velocity-HMA Scalper"

### Core Logic
The strategy will fuse **Price Velocity** with a **Hull Moving Average (HMA)** baseline to detect trend shifts instantly.

1. **Trend Component (HMA):**
   - HMA is known for being extremely responsive and minimizing lag.
   - Formula: `WMA(2*WMA(n/2) - WMA(n), sqrt(n))`

2. **Momentum Component (Velocity):**
   - Calculate the first derivative (slope) of the HMA, not just raw price.
   - `Vel = HMA[0] - HMA[1]`
   - Normalized via `Tanh` or `InverseFisher`.

3. **Volatlity Filter (Noise Reduction):**
   - Use **Kaufman Efficiency Ratio (KER)** or **ADX**.
   - If `Efficiency < Threshold`, force signal to 0 (Flat).

### Implementation Plan (Next Session)
1. **Create `Showcase_Indicators/HMA_Velocity_Scalper.mq5`**.
2. **Implement HMA Class/Function:**
   - Must handle the 3-step WMA calculation efficiently.
3. **Implement Normalization:**
   - Use the proven `InverseFisher` from `Hybrid_Conviction`.
4. **Visual Testing:**
   - Plot the HMA color-coded by Velocity slope.
   - Plot entry arrows when Velocity crosses zero *and* Volatility is high.

## Technical Requirements for RAG
- The `rag_mql5_dev` index contains crucial code for optimized HMA and JMA algorithms.
- **Action Required:** Ensure `MQL5_RAG_DRIVE_LINK` is accessible in the next session to download the real data.
