# SYSTEM ARCHITECTURE & CAPABILITIES

**Version:** 3.0 (Detailed Locations)
**Date:** 2025
**Status:** **ACTIVE REFERENCE**

## 1. The Core System (Modular Architecture)
The "Architect" of the system. These modules define the EA's capabilities.

### A. Trading Assistant (The Brain)
*   **Location:** `Profit_Management/TradingAssistant.mqh`
*   **Capabilities:**
    *   Synthesizes signals from Strategy, Environment, and Risk.
    *   Calculates "Conviction Score" (Regime + Momentum + Volatility).
    *   Manages Trade State Machine (Entry -> Manage -> Exit).

### B. Risk Manager (The Safety)
*   **Location:** `Profit_Management/RiskManager.mqh`
*   **Capabilities:**
    *   **Dynamic Sizing:** Lot = f(Account%, Margin%).
    *   **Tick Volatility:** Adapts Stop Loss to microstructure noise (TickSD).
    *   **Leverage Guard:** Prevents trades if margin usage > limit.

### C. Environment (The Context)
*   **Location:** `Profit_Management/Environment/`
    *   `BrokerInfo.mqh`: Normalizes Points/Pips/Lots.
    *   `TimeManager.mqh`: Session times, DST, Rollover protection.
    *   `NewsWatcher.mqh`: (Future) Economic event filtering.

### D. Profit Maximizer (The Exit)
*   **Location:** `Profit_Management/ProfitMaximizer.mqh`
*   **Dependencies:** `Trailings.mqh` (Standard Library wrapper).
*   **Capabilities:**
    *   **Trend Chasing:** Infinite TP expansion.
    *   **Smart Trailing:** ATR/AMA based trailing stops.
    *   **BreakEven:** Locks profit at defined R-multiples.

### E. Trading Panel (The Interface)
*   **Location:** `Profit_Management/TradingPanel.mqh`
*   **Capabilities:**
    *   **Cockpit Controls:** Granular Auto/Manual switches.
    *   **Dashboard:** Real-time P/L and Status display.
    *   **Manual Override:** Direct Buy/Sell buttons.

## 2. Python Hybrid Strategy (The Co-Pilot)
*   **Status:** **DESIGN / PLANNED** (Not implemented in code yet).
*   **Location:** `Profit_Management/Python_Hybrid_Strategy.md`
*   **Concept:**
    *   **DSP (Digital Signal Processing):** Use Python (`scipy`) to perform Zero-Phase Filtering (Lag removal) on price data.
    *   **Protocol:** CSV/JSON Shared File Exchange. MQL5 writes Ticks -> Python filters -> MQL5 reads Trend.
    *   **Goal:** Replace lagging MQL5 indicators with mathematical prediction.

## 3. Infrastructure
*   **Startup Script:** `restore_environment.py` (Root) - **MANDATORY STARTUP**.
*   **Search Engine:** `kutato.py` (Root).
*   **Protocol:** `AGENTS.md` (Root).

## 4. Deprecated / Excluded
*   `WPR_Analyst_*.mq5`: **OBSOLETE.** Do not reference.
*   `Colombo_*` code files: Deleted. (Concept survives in `Python_Hybrid_Strategy.md`).

---
*Use this map to locate any system component instantly.*
