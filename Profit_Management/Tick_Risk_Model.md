# Tick-Based Risk Model (Specification)

## 1. Problem Definition
Standard trailing stops often use Bar High/Low or fixed Points. In high-frequency scalping:
1.  **Noise Risk:** A single tick spike can hit a tight TS.
2.  **TP Interference:** If TS moves too close to TP, the probability of hitting TS (drawdown) before TP (profit) increases drastically if volatility is high.
3.  **Spread Vulnerability:** Variable spreads can widen and hit SL/TS even if Bid/Ask didn't move effectively.

## 2. Mathematical Model
We use **Tick-Level Standard Deviation (TickSD)** of the Price differences to estimate immediate volatility.

### 2.1 Variance Calculation (Welford's Algorithm)
For efficiency in `OnTick`:
- `M_k = M_{k-1} + (x_k - M_{k-1}) / k`
- `S_k = S_{k-1} + (x_k - M_{k-1}) * (x_k - M_k)`
- `Variance = S_k / (k - 1)`
- `TickSD = Sqrt(Variance)`
Where `x_k` is the price change (`tick.bid - prev_tick.bid`).

### 2.2 Dynamic Safe Distance (DSD)
`DSD = Spread + (k * TickSD)`
- `k`: Safety factor (e.g., 2.0 or 3.0).
- `Spread`: Current `Ask - Bid`.

## 3. Implementation Logic (`CAdaptiveProfit` extension)

### 3.1 Proximity Protection Rule
**Before modifying Trailing Stop:**
Check: `Distance(Proposed_TS, TakeProfit) > (m_volatility_multiplier * TickSD)`
- If `True`: Allow modification.
- If `False`: **Freeze TS**. Do not move it closer. Let the trade hit TP or revert to the *previous* safer TS.

### 3.2 Maximum Drop protection (SL)
`StopLoss = EntryPrice +/- (MaxDropProbability * TickSD * Sqrt(TimeHorizon))`
- This is a simplified "Square Root of Time" volatility scaling for determining initial SL.

## 4. Integration with `Trailings.mqh`
We will **extend** `CSimpleTrailing` into `CTickSmartTrailing`.
- **Override:** `CheckCriterion()`
- **Logic:**
    1. Calculate standard criterion.
    2. *Add Check:* Is `NewSL` too close to `TP`?
    3. *Add Check:* Is `NewSL` within `Spread + 2*TickSD` of current price? (Noise filter).

## 5. Artifacts to Create
- `TickVolatility.mqh`: A helper class to calculate running TickSD.
- `SmartTrailing.mqh`: The extended trailing class.
