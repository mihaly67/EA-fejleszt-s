# Research Consolidation Report (Final Blueprint)

## 1. Architectural Foundation
### 1.1 Event-Driven Core (`OnTradeTransaction`)
- **Source:** MQL5 Cookbook (Article 1111).
- **Decision:** The "Cyborg Mode" (Manual Override) MUST use `OnTradeTransaction`.
- **Reason:** It provides the granular `TRADE_TRANSACTION_ORDER_UPDATE` event, allowing the EA to distinguish between its own actions (via Magic Number) and User actions (Manual drag on chart).
- **Optimization:** Use `OrderSendAsync` for scalping entries to prevent `OnTick` blocking (Article 2635).

## 2. Profit & Risk Subsystems
### 2.1 Profit Maximizer (Trailing TP)
- **Concept:** "Free Running" = Dynamic Take Profit.
- **Logic:** `NewTP = Price + (Factor * Volatility)`.
- **Validation:** Article 20347 supports "Channel Breakout" logic for expanding targets.
- **Safety:** Must use `Maximum Adverse Excursion` (MAE) logic. If pullback > `2 * TickSD`, lock profit immediately.

### 2.2 Advanced Risk Manager
- **Position Sizing:** "Volatility Adjusted Kelly".
    - Base Risk = 1-2%.
    - Adjust by `ConvictionScore` (0.5x to 1.5x).
    - Normalization: `MinSL = 3 * TickSD` prevents noise-outs.
- **Leverage:** Use `OrderCalcMargin` (Article 15394) to ensure `UsedMargin < 90%` regardless of 1:1 or 1:500 leverage.

## 3. Implementation Patterns (Cookbook)
- **Dashboard:** `CAppDialog` (Standard Library) is the verified "Cookbook" standard (Article 16084).
- **Data Structures:** Use Collection Classes (Article 11260) for managing Tick History buffers efficiently (Welford).

## 4. Refined Roadmap (Next Session)
1.  **Refactor `TradingAssistant`**: Inject `OnTradeTransaction` handler.
2.  **Implement `CProfitMaximizer`**: The "Chaser" logic.
3.  **Implement `CHybridSwitch`**: The Auto/Manual toggle system.
