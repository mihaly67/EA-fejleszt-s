# Adaptive Hybrid System Design (Draft)

## 1. Core Concept
The system acts as a "Trading Assistant" that first identifies the **Market Regime** (Trend vs. Range, High vs. Low Volatility) and then adjusts the **Indicator Parameters** and **Risk Management** (Trailing Stop) accordingly.

## 2. Market Regime Detector (`CRegimeDetector`)
Based on MQL5 Articles 17737/17781.
- **Inputs:** Price series (Close), Volatility (ATR).
- **Logic:**
    - **Trend Detection:** Uses ADX > 25 (Trend) or Autocorrelation > Threshold.
    - **Volatility Classification:** ATR vs. Moving Average of ATR (High/Low).
- **Output States (Enum):**
    - `REGIME_TREND_UP` / `REGIME_TREND_DOWN`
    - `REGIME_RANGE_STABLE` / `REGIME_RANGE_VOLATILE`

## 3. Adaptive Indicator (`CHybridAdaptive`)
A wrapper around standard indicators (e.g., WPR, MACD) that changes behavior based on the Regime.
- **Trend Mode:** Uses longer periods or trend-following logic (e.g., MACD with standard settings).
- **Range Mode:** Uses oscillators (WPR/Stochastic) with faster settings to catch reversals.
- **Self-Optimization:** Could use `Indi_FractalAdaptiveMA` (FRAMA) logic to automatically adjust smoothing based on fractal dimension (D).

## 4. Adaptive Profit Management (`CAdaptiveProfit`)
Integrates `Trailings.mqh`.
- **Trend Regime:** Uses `CTrailingByAMA` or `CTrailingByFRAMA` (Looser stops to ride the trend).
- **Range Regime:** Uses `CTrailingByValue` with tight fixed stops or `CTrailingByPSAR` (Parabolic SAR) for quick exits.
- **Volatility Scaling:** Stop Loss distance = `k * ATR`.

## 5. Implementation Roadmap
1.  **Extract `MarketRegimeDetector`:** from Article 17737/17781 logic (need to find the code or recreate it).
2.  **Create `Adaptive_System_Showcase.mq5`:** A visual indicator showing the Regime State as a background color or histogram.
3.  **Integrate `Trailings.mqh`:** Demonstrate switching trailing methods on the fly.
