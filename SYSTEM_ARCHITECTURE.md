# SYSTEM ARCHITECTURE & CAPABILITIES

**Version:** 2.0 (Modular Core)
**Date:** 2025
**Status:** **ACTIVE REFERENCE**

## 1. The Core System (Modular Architecture)
The true capabilities of the system are defined by the modular components located in `Profit_Management/`. This is the "Architect" of the system.

### A. Trading Assistant (`TradingAssistant.mqh`)
*   **Role:** The Central Brain.
*   **Capabilities:**
    *   **Signal Synthesis:** Combines multiple inputs (Strategy, Environment, Risk) to make trading decisions.
    *   **Conviction Scoring:** Calculates a weighted score (0-100%) for trade setups based on Market Regime (40%), Momentum (30%), etc.
    *   **State Management:** Tracks the current state of the trade (Entry, Managing, Exit).

### B. Risk Manager (`RiskManager.mqh`)
*   **Role:** Capital Protection & Sizing.
*   **Capabilities:**
    *   **Dynamic Sizing:** Calculates Lot Size based on Risk % or Margin %.
    *   **Tick Volatility:** Adapts Stop Loss distances to real-time market noise (TickSD).
    *   **Safety Checks:** Prevents over-leveraging and trading during unsafe conditions.

### C. Environment (`Environment/` folder)
*   **Role:** Situational Awareness.
*   **Capabilities:**
    *   **Time Manager:** Handles session times (London, NY), DST, and rollover avoidance.
    *   **Broker Info:** Normalizes instrument properties (Point vs Pip, Lot Steps).
    *   **News Watcher:** (Planned) Filters trades during high-impact news.

### D. Profit Maximizer (`ProfitMaximizer.mqh` & `Trailings.mqh`)
*   **Role:** Exit Optimization.
*   **Capabilities:**
    *   **Trend Chasing:** Dynamically adjusts Take Profit to "ride" the trend.
    *   **Smart Trailing:** Uses ATR, AMA, or Tick Volatility to trail stops without premature knockouts.
    *   **BreakEven:** Secures profit at defined thresholds.

### E. Trading Panel (`TradingPanel.mqh`)
*   **Role:** Human-Machine Interface (Cockpit).
*   **Capabilities:**
    *   **Manual Override:** Buttons for immediate Buy/Sell/Close.
    *   **Status Display:** Shows P/L, Balance, and current Algorithm State.
    *   **Cockpit Controls:** Granular toggles for Auto/Manual modes.

## 2. Infrastructure
*   **`restore_environment.py`:** The Unified Startup Script. Ensures RAG databases (Theory/Code) are ready.
*   **`kutato.py`:** The Deep Research Tool.

## 3. Deprecated / Excluded
*   `WPR_Analyst_*.mq5`: **OBSOLETE.** Do not use as reference logic.
*   `Colombo_*`: Experimental/Failed prototypes.

---
*This architecture defines the actual capabilities of the Jules Trading System.*
