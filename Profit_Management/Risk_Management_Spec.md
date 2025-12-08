# Advanced Risk Management Specification

## 1. Overview
The **Risk Manager** is responsible for determining the optimal **Position Size (Volume)** and validating trades against safety constraints (Drawdown, Exposure). It works downstream from the `TradingAssistant`.

## 2. Core Logic: `CRiskManager`

### 2.1 Inputs
- **Account Equity/Balance:** Current capital.
- **Tick Volatility:** From `TickVolatility.mqh` (Market Noise).
- **Conviction Score:** From `TradingAssistant.mqh` (Strategy Confidence).
- **Stop Loss Distance:** In points.

### 2.2 Sizing Algorithms
1.  **Fixed Fractional Risk:**
    -   `RiskAmount = AccountEquity * RiskPercent`
    -   `Volume = RiskAmount / (SL_Distance * TickValue)`
2.  **Volatility Adjusted Risk:**
    -   `RiskPercent` scales with `TickVolatility`. Low vol = Higher risk allowed? Or High Vol = Lower risk?
    -   *Rule:* If Volatility is Extreme (> 2*Avg), reduce RiskPercent by 50%.
3.  **Conviction Sizing (Kelly-like):**
    -   Base Risk = 1.0%
    -   If Conviction > 80 (Strong Buy), Risk = 1.5% or 2.0%.
    -   If Conviction < 50 (Weak), Risk = 0.5%.

### 2.3 Safety Checks (The "Brakes")
-   **Max Daily Drawdown:** If `(StartEquity - CurrentEquity) > MaxDD`, return Volume = 0.
-   **Exposure Limit:** Max total lots per symbol.
-   **Martingale Protection:** Explicitly forbid doubling lots on losing trades (unless configured).

## 3. Implementation Plan
-   **Class:** `CRiskManager`
-   **Methods:**
    -   `CalcLotSize(double sl_points, double conviction)`
    -   `CheckSafetyConstraints()`
-   **Integration:** The EA (`Assistant_Showcase` or final EA) calls `CalcLotSize` before `OrderSend`.

## 4. Tick Volatility Integration
The `TickVolatility` class (already built) provides the `GetStdDev()` metric.
`CRiskManager` will use this to normalize Stop Loss:
-   `Safe_SL = Max(Fixed_SL, 3.0 * Tick_Vol_Points)`
This ensures we don't calculate huge lots for a tiny SL that is within the noise.
