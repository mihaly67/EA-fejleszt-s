# Advanced Profit & Risk Specification v2 (Hybrid Control)

## 1. Hybrid Control Philosophy
The system operates in a **"Cyborg" Mode**:
- **Default:** Automatic management (EA calculates and sets SL/TP/TS).
- **Override:** If the user manually modifies a trade (drags SL line), the EA **detects** this change and **adopts** it as the new strategy. It does *not* fight the user by resetting the old SL.

## 2. Global & Granular Switches (`CProfitManager`)
### 2.1 State Variables
- `m_mode_global`: `ENUM_MODE_AUTO`, `ENUM_MODE_MANUAL`, `ENUM_MODE_ASSISTANT_ONLY`
- `m_switch_sl`: `AUTO`/`MANUAL`
- `m_switch_tp`: `AUTO`/`MANUAL`
- `m_switch_ts`: `AUTO`/`MANUAL` (Trailing Stop)
- `m_switch_be`: `AUTO`/`MANUAL` (BreakEven)

### 2.2 Behavior
- If `m_switch_sl == MANUAL`: EA never sends SL modifications.
- If `m_switch_sl == AUTO`: EA sets initial SL.
    - **Override Logic:** If `OnTradeTransaction` detects a SL change *not* sent by the EA (MagicNum check?), the EA updates its internal `m_target_sl` to the new value.
    - *Correction:* MT5 `OnTradeTransaction` doesn't easily distinguish "who" modified it if the Magic Number is on the *Position*. The Position Magic doesn't change.
    - *Solution:* We track the `last_known_sl`. If `current_sl != last_known_sl` and `current_sl != internal_target_sl`, then User changed it. **Action:** Update `internal_target_sl = current_sl`. Recalculate Trailing distance based on this new SL if TS is active.

## 3. Exit Logic (Profit Management)
### 3.1 Scalping Rules
- **Min Profit:** `1.5 * AverageSpread`.
    - If `FloatingProfit < MinProfit`, do not trigger "Early Exit" signals (unless Emergency).
- **Free Running (Max Profit):**
    - Concept: "Let winners run" but with targets.
    - Implementation: **Trailing Take Profit**.
    - Logic: See `Profit_Maximizer_Spec.md`. The TP is actively pushed away (`NewTP = Price + Volatility`) as long as Momentum is strong and Pullback is within `MaxAdverseExcursion` limits.

### 3.2 Dynamic Trailing Distance
- User can "pull back" or "tighten" the TS manually.
- **Logic:**
    - Current TS Distance = `Price - SL`.
    - If User moves SL manually -> New Distance is calculated.
    - The EA uses this *new* distance for subsequent trailing steps.

## 4. Environment Updates
- **Local Time:** Hardcoded "Budapest" (GMT+1/GMT+2).
    - `CTimeManager` needs `TimeLocal()` vs `TimeGMT()` offset calculation or manual input `InpGMTOffset`.
- **Leverage Fallback:**
    - Input `InpManualLeverage` (Default 500). Used if `AccountInfoInteger(ACCOUNT_LEVERAGE)` returns 0 or fails.

## 5. Implementation Roadmap
1.  **Refactor `RiskManager`**: Add switches for SL/TP/TS.
2.  **Create `ProfitManager`**: Separate class for Exit Logic (MinProfit, BreakEven, Manual Override detection).
3.  **Update `SmartTrailing`**: Add method `UpdateDistance(double new_dist)` to support overrides.
