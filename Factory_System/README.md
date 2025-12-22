# Hybrid System Blueprint v1.0

## 🏗️ Architecture Overview

The Hybrid System is designed as a modular Expert Advisor ecosystem, strictly separating Logic (Brain), Execution (Hands), Visualization (Face), and Environment (Context).

```mermaid
graph TD
    EA[Hybrid_System_EA.mq5] --> Panel[Hybrid_Panel (Face)]
    EA --> Brain[Hybrid_Signal_Aggregator (Brain)]
    EA --> Agent[Hybrid_TradingAgent (Hands)]
    EA --> Env[Environment Manager]

    Panel -- Displays --> Brain
    Panel -- Controls --> Agent

    Brain -- Reads --> Ind[Hybrid Indicators]

    Agent -- Uses --> Risk[RiskManager]
    Agent -- Uses --> Profit[ProfitMaximizer]
    Agent -- Uses --> Vol[TickVolatility]

    Env -- Contains --> News[NewsManager]
    Env -- Contains --> Session[SessionManager]
    Env -- Contains --> Spread[SpreadMonitor]
```

## 🧩 Components

### 1. The Brain (`Hybrid_Signal_Aggregator.mqh`)
*   **Role:** Signal Aggregation & Conviction Scoring.
*   **Inputs:**
    *   `Momentum v2.3` (Trend Direction)
    *   `Flow v1.7` (Volume Validation)
    *   `Context v2.2` (Trend Filter)
    *   `WVF v1.3` (Sentiment/Contrarian)
    *   `Institutional v1.0` (Smart Money Levels)
*   **Output:** `HybridSignalStatus` (Score: -1.0 to +1.0).

### 2. The Face (`Hybrid_Panel.mqh`)
*   **Role:** User Interface & Visualization.
*   **Structure:** `CAppDialog` with Tabbed Interface.
    *   **Tab 1: Dashboard:** Real-time visualization of the Brain's components and Total Conviction.
    *   **Tab 2: Trade:** Manual Trading Controls (Buy/Sell/Close), Risk inputs.
    *   **Tab 3: Profit:** (Placeholder) Future settings for Profit Maximizer.
*   **Feature:** "Auto-Lot" mode (Input 0) triggers Risk Manager calculation.

### 3. The Hands (`Hybrid_TradingAgent.mqh`)
*   **Role:** Execution & Risk Management.
*   **Dependencies:**
    *   `RiskManager`: Enforces **Max Margin 70%** and calculates Dynamic Lots based on Conviction.
    *   `ProfitMaximizer`: Manages open positions (Trailing, MAE exit).
    *   `TickVolatility`: Provides market noise data for Stop Loss distance.
*   **Safety:** Always validates Spread (Min Profit > 1.5x Spread).

### 4. The Environment (Planned)
*   **NewsManager (`NewsManager.mqh`):**
    *   *Status:* **To Be Implemented**.
    *   *Logic:* Use `CalendarValueHistory` to detect High Impact news.
    *   *Action:* Block entry +/- 30 mins around news.
*   **SessionManager (`SessionManager.mqh`):**
    *   *Status:* **To Be Implemented**.
    *   *Logic:* Define active hours (London/NY).
*   **SpreadMonitor (`SpreadMonitor.mqh`):**
    *   *Status:* **To Be Implemented**.
    *   *Logic:* Block trade if Spread > MaxSpread.

## 🚀 Integration Map (`Hybrid_System_EA.mq5`)

The Master EA binds everything together:

1.  **OnInit:**
    *   Initialize `Brain`.
    *   Initialize `Panel` (injecting Brain pointer).
    *   Initialize `Agent` (inside Panel logic or separate).
    *   *Future:* Initialize `Environment`.

2.  **OnTick:**
    *   `Brain.Update()` -> Refreshes signals.
    *   `Panel.OnTick()` -> Triggers Agent -> Triggers ProfitMaximizer.
    *   `Panel.Update()` -> Refreshes GUI.
    *   *Future:* `Environment.Update()` -> Check News/Session.

3.  **OnChartEvent:**
    *   `Panel.OnEvent()` -> Handle clicks.

## 📝 Next Steps (Testing Phase)

Since the code has been written but **not compiled/tested** in a live terminal, the following verification steps are required:

1.  **Compile Check:** Ensure all `#include` paths are correct (`MQL5/Include/Hybrid/`, `MQL5/Include/Profit_Management/`).
2.  **Indicator Setup:** Ensure all `Showcase_Indicators/*.mq5` are compiled and present in `MQL5/Indicators/Showcase_Indicators/` (Note: the `iCustom` paths in `Hybrid_Signal_Aggregator.mqh` assume this path).
3.  **Visual Test:** Attach `Hybrid_System_EA` to a chart.
    *   Verify Panel appears.
    *   Verify Dashboard shows values (not zeros).
    *   Verify Buttons work (Buy/Sell).
    *   Verify Risk Manager logs (Check Journal for "RiskManager initialized").

## ⚠️ Known Constraints
*   **News Filter:** Currently missing. Trading is allowed during news.
*   **Session Filter:** Currently missing. 24/7 trading allowed.
*   **Paths:** `iCustom` paths are hardcoded to `Showcase_Indicators\`. Ensure folder matches.

_Document Generated: 2024-12-20_
