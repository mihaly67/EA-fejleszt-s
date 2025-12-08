# Profit Maximizer Specification ("Free Running")

## 1. Concept: Trailing Take Profit
Instead of a fixed TP, the system "chases the trend". As long as the trend is strong and volatility supports it, the TP is pushed further away to avoid premature exit, while the Trailing Stop secures the gains from behind.

## 2. Mathematical Logic
### 2.1 Dynamic TP Expansion
- **Condition:** Price approaches current TP (within `ApproachDistance`).
- **Confirmation:** Trend Momentum is STRONG (ADX > 30) AND Accelerating.
- **Action:** `NewTP = CurrentPrice + (ExpansionFactor * ATR)`.
    - *ExpansionFactor:* Usually 1.0 to 2.0.

### 2.2 Maximum Adverse Excursion (Pullback Limit)
The "Free Run" must end if the market turns.
- **Logic:** Track `PeakProfit`.
- **Constraint:** If `CurrentProfit < PeakProfit - (PullbackLimit * Volatility)`, STOP moving TP.
    - Let the price hit the existing TP or the Trailing Stop.
- **Volatility Metric:** Use `TickVolatility` (TickSD) for scalping precision.

## 3. Algorithm: `CProfitMaximizer`
1.  **Init:** `PeakProfit = 0`.
2.  **OnTick:**
    -   `CurrentProfit = (Price - OpenPrice)`.
    -   If `CurrentProfit > PeakProfit` -> Update `PeakProfit`.
    -   Calculate `Pullback = PeakProfit - CurrentProfit`.
    -   Calculate `SafePullback = 2.0 * TickSD` (or `1.0 * ATR` if TickSD unstable).
    -   **Decision:**
        -   If `Pullback > SafePullback`: **LOCK MODE**. Do not move TP further. Tighten TS immediately.
        -   Else If `Dist(Price, TP) < (1.0 * TickSD)`: **EXPAND MODE**. Move TP away (`+10 Points` or similar).
        -   *Optimization:* Use `CTrade::OrderModify` only if `NewTP` differs significantly (> 1.0 Point) to avoid "Trade Flood".

## 4. Integration with `ProfitManager`
- The `CProfitManager` delegates the TP handling to `CProfitMaximizer` when in `MODE_FREE_RUN`.
- `SmartTrailing` handles the Stop Loss (defensive).
- `ProfitMaximizer` handles the Take Profit (offensive).
- **Execution:** Uses standard `CTrade` library for robust error handling (Requotes, Busy Server).
