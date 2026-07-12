# HMM Scalping Assistant Architecture (CT-HMM & Rolling Window)

Based on the research provided, the classical daily HMM is inadequate for M1/Tick scalping CFD markets. The following hybrid architecture will be implemented:

## 1. Core Models
*   **CT-HMM (Continuous-Time HMM):** To be applied on RAW tick data. This model will not rely on fixed time intervals but rather the immediate flow of ticks (liquidity shocks, order flow changes).
*   **Rolling Window 2-State HMM:** To be applied on M1 data. It recalculates the state probabilities continuously over a rolling window (e.g., last 200-500 candles or 5s candles) to capture rapid timeframe shifts.

## 2. Model Inputs (Observations)
We will **NOT** use raw price data. The HMM models will ingest:
1.  **Log Returns:** Captures velocity and direction.
2.  **Imbalance / Volume Delta:** Captures structural buying/selling pressure.
3.  **Spread Expansion / ATR:** High sensitivity trigger for blocking trades during volatile or illiquid periods.

## 3. The 3 Hidden States (Scalping Regime)
The Analyzer will categorize the market into strictly 3 actionable states:
1.  **Calm / Sideways (No Trade):** Low volatility, erratic movement. Spread consumes the profit margin. (Action: BLOCKED)
2.  **Impulsive Uptrend (Breakout Long):** High velocity, strong volume momentum upwards. (Action: LONG ONLY)
3.  **Impulsive Downtrend (Breakout Short):** High velocity, strong volume momentum downwards. (Action: SHORT ONLY)

## 4. Signal Filtering & Logic
*   **Confidence Threshold:** The EA will only issue an actionable signal if the Viterbi state probability (Posterior) is > **80-85%**. If lower, it outputs `NO TRADE`.
*   **Transition Matrix Forewarning:** If the transition probability from an *Impulsive* state to the *Calm* state spikes, the system will flash a warning: `Momentum fading, take early profits!`.

## 5. Technical Implementation (Hybrid MQL5 + Python)
*   **EA (Data Collector):** The MT5 EA will rapidly collect Tick/M1 data and transmit it via a local API/ZMQ.
*   **Python Engine (Math Core):** A background Python daemon using `hmmlearn` or `pystan` will receive the data, run the sliding window HMM over the last 300 ticks, and return the state probabilities.
*   **EA Dashboard:** The EA visualizes the results on a HUD (Green=Long Regime, Red=Short Regime, Grey=Blocked) and calculates dynamic Volatility-adjusted Stop-Loss and Take-Profit targets.
