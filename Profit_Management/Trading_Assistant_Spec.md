# Trading Assistant & Panel Specification

## 1. Overview
The **Trading Assistant** is a decision-support module that aggregates Market Regime, Trend Strength, and Signal Quality to provide actionable advice (e.g., "STRONG TREND - HOLD", "DIVERGENCE - PREPARE EXIT").
The **Trading Panel** is the visual interface (Dashboard) displaying this advice.

## 2. Trading Assistant Logic (`CTradingAssistant`)
This class synthesizes data from the *Market Regime Detector* and *Hybrid Indicators*.

### 2.1 Synthesis Matrix
The assistant calculates a **Conviction Score** (-100 to +100) based on:
1.  **Regime Weight (40%):**
    *   `REGIME_TREND_UP` (+40) / `REGIME_TREND_DOWN` (-40)
    *   `REGIME_RANGE` (0)
2.  **Momentum Weight (30%):**
    *   Adaptive MACD/FRAMA Slope.
3.  **Volatility Weight (20%):**
    *   Low Volatility (Accumulation) vs High Volatility (Breakout/Exhaustion).
4.  **Anomaly Deduction (-10%):**
    *   Divergence detected (Price vs Oscillator) reduces conviction.

### 2.2 Output States
| Conviction | Status Text | Suggested Action | Color |
| :--- | :--- | :--- | :--- |
| > 75 | **STRONG BUY** | Aggressive Entry / Add Pos | Green |
| 25 to 75 | **WEAK BUY** | Conservative Entry | Lime |
| -25 to 25 | **NEUTRAL/RANGE** | Scalp / Wait | Gray |
| -75 to -25 | **WEAK SELL** | Conservative Entry | Orange |
| < -75 | **STRONG SELL** | Aggressive Entry / Add Pos | Red |

### 2.3 Strategic Exit Logic (Profit Management)
The Assistant triggers `EXIT_SIGNAL` events when:
1.  **Regime Collapse:** Trend Regime changes to Range Regime (e.g., ADX drops below 20).
2.  **Momentum Reversal:** Adaptive MACD Crosses Zero against position.
3.  **Divergence:** RSI Divergence detected on M1/M5.

## 3. Panel Visualization (`CTradingPanel`)
Inherits from `CAppDialog` (Standard Library) for robustness.

### 3.1 Layout (Wireframe)
+--------------------------------------------------+
|  [Header: WPR Analyst Assistant]      [Min/Max]  |
+--------------------------------------------------+
|  Regime:   [ TRENDING UP ]  (Gauge: [||||||  ])  |
|  Strength: [ 85%         ]  (Bar:   [||||||||])  |
|  Volat:    [ HIGH        ]  (Text)               |
+--------------------------------------------------+
|  ADVICE:   STRONG BUY                            |
|  "Consider adding on pullbacks"                  |
+--------------------------------------------------+
|  [ AUTO-TRADING: ON ]   [ CLOSE ALL POSITIONS ]  |
+--------------------------------------------------+

### 3.2 Components
1.  **Regime Gauge:** A graphical object (`CBmpButton` or `CLabel`) changing color.
2.  **Advice Text:** Large, bold text field updating dynamically.
3.  **Action Buttons:** Direct interaction with `Profit_Management` module (e.g., "Close All").

## 4. Implementation Plan
1.  **`MarketRegimeDetector.mqh`**: Implement the ADX/ATR logic.
2.  **`TradingAssistant.mqh`**: Implement the Scoring & Synthesis logic.
3.  **`TradingPanel.mqh`**: Implement the `CAppDialog` GUI.
4.  **`Assistant_Showcase.mq5`**: An indicator/EA to demonstrate the panel live.
