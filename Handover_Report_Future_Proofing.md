# Knowledge Base Strategy: "The Thief's Library"

## 1. Objective
To empower Jules (the Agent) with industrial-grade algorithmic trading patterns, focusing on **Scalping**, **Market Making**, and **Reinforcement Learning** (RL), specifically to support the "Mimic Trap" strategy against broker algorithms.

## 2. Selected Repositories & Focus Areas

### A. Hummingbot (The Executioner)
*   **Relevance:** High. Defines how to manage order books and handle async events in a high-frequency context.
*   **Focus Paths:**
    *   `hummingbot/strategy/pure_market_making/`: The core logic for placing bid/ask ladders (Trap logic).
    *   `hummingbot/connector/`: Error handling and latency management.
*   **Action:** Study `pure_market_making` for logic on "hanging" orders and "inventory skew" (balancing risk).

### B. FinRL (The Brain)
*   **Relevance:** High (Future). Provides the standard Gym environments for training an RL agent to "learn" the broker's behavior.
*   **Focus Paths:**
    *   `finrl/meta/env_stock_trading/env_stocktrading.py`: The standard environment.
    *   `finrl/agents/`: Implementations of PPO/SAC algorithms.
*   **Action:** Map our `Mimic_Research.csv` to the `df` expected by `StockTradingEnv`.
    *   *Gap Identified:* FinRL expects standard OHLCV (Open-High-Low-Close-Volume) bars. Our CSV is Tick-based. We need a **Preprocessor** to aggregate ticks into "Micro-Bars" (e.g., 1-second bars) for the RL agent.

### C. Nautilus Trader (The Engine)
*   **Relevance:** Medium-High. Best-in-class event-driven architecture.
*   **Focus Paths:**
    *   `nautilus_trader/execution/`: handling execution reports.
*   **Action:** Use as a reference for robust "Event Loop" design if we move the "Brain" to a standalone Python engine.

### D. VectorBT (The Simulator)
*   **Relevance:** High (Optimization). Allows testing millions of "Trap Gap" parameters in seconds.
*   **Focus Paths:**
    *   `vectorbt/portfolio/`: Simulating PnL from array-based signals.
*   **Action:** Use to optimize the `InpTrapSpreadMult` parameter.

## 3. Immediate Action Plan (Next Session)
1.  **Create Preprocessor:** Write a Python script (`convert_mimic_to_finrl.py`) that takes the `Mimic_Trap_Research_EA` CSV and resamples it into the format FinRL expects (Date, Open, High, Low, Close, Volume, ActionDetails_As_Feature).
2.  **Define Reward Function:** Based on FinRL's `env_stocktrading.py`, draft a custom reward function that penalizes "high duration" trades (scalping focus) and rewards "quick sniper" profits.

## 4. Storage
*   The source code has been indexed into `Knowledge_Base/*.jsonl` files.
*   These files are now part of the permanent environment and can be queried by Jules in future tasks.
