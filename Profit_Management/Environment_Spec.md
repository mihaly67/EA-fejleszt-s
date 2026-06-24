# Global Environment Specification

## 1. Concept: The "Nervous System"
The `CEnvironment` class acts as the central state manager for external factors. It abstracts the complexity of Time, Broker constraints, and News events into simple queryable states.

## 2. Components

### 2.1 Broker Info (`CBrokerInfo`)
Wraps `CSymbolInfo` (Standard Library).
- **Responsibilities:**
    - `IsSpreadAcceptable(max_spread)`: Returns false if spread is too wide.
    - `GetStopsLevel()`: Returns minimum distance for SL/TP.
    - `IsTradeAllowed()`: Checks `SYMBOL_TRADE_MODE`.
    - `GetSwapCost()`: Estimates swap impact (for swing trades).

### 2.2 Time Manager (`CTimeManager`)
Handles Session Logic and Rollover Avoidance.
- **Inputs:** Server Time (`TimeCurrent()`).
- **Sessions:**
    - `SESSION_ASIAN`: 00:00 - 08:00 (GMT offset adjustable).
    - `SESSION_LONDON`: 07:00 - 16:00.
    - `SESSION_NY`: 13:00 - 22:00.
- **Rollover Zone:** E.g., 23:55 - 00:05.
- **Output:** `IsTradingTime()`, `GetCurrentSession()`.

### 2.3 News Watcher (`CNewsWatcher`)
Interfaces with the MQL5 Economic Calendar.
- **Logic:**
    - Scans for upcoming events with `CALENDAR_IMPORTANCE_HIGH` or `MODERATE`.
    - Filters by Currency (e.g., EUR, USD for EURUSD).
- **Output:**
    - `IsNewsImminent(minutes)`: True if high impact news is within X minutes.
    - `GetNextEventTime()`: For dashboard display.

## 3. Integration Logic (`CEnvironment`)
Combines the above components.
- `Init(symbol)`
- `Refresh()`: Called every tick (or timer).
- `GetConvictionPenalty()`:
    - If News < 15 mins: Penalty = -100 (Block).
    - If Rollover: Penalty = -100 (Block).
    - If Spread > Limit: Penalty = -50.

## 4. Implementation Plan
1.  **`BrokerInfo.mqh`**: Wrapper for `SymbolInfoDouble`.
2.  **`TimeManager.mqh`**: Time struct parsing.
3.  **`NewsWatcher.mqh`**: `CalendarValueLast` usage.
4.  **`Environment.mqh`**: The aggregate class.
5.  **Update `TradingAssistant`**: To use `CEnvironment`.
