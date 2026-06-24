# Python Hybrid Strategy (Co-Pilot Architecture)

## 1. Concept: The "Co-Pilot"
Python is NOT the engine (Trade Execution). It is the Navigator.
- **MQL5 (The Pilot):** Handles Ticks, Trade Execution, Safety Checks (Stop Loss), and Immediate Decisions.
- **Python (The Co-Pilot):** Performs heavy math, statistical analysis, and "Second Opinion" checks.

## 2. Communication Protocol
We use a **Shared File Exchange** (Low Latency File I/O) for simplicity and robustness in the Sandbox/VPS environment.
- **Path:** `MQL5/Files/HybridExchange/`
- **Files:**
    - `market_state.json`: Written by Python (Analysis).
    - `tick_stream.csv`: Written by MQL5 (Raw Data).

## 3. Python Responsibilities (Non-ML)
### 3.1 Zero-Lag Filtering
- Use `scipy.signal.filtfilt` (Zero-phase filtering) on price buffers.
- **Output:** "Filtered Price" and "Trend Slope" to MQL5.
- *Advantage:* Removes noise better than standard MA without phase shift.

### 3.2 Statistical Risk (VaR)
- Use `numpy` to calculate "Value at Risk" on the last 1000 ticks.
- **Output:** "Volatility Multiplier" (e.g., 1.2x or 0.8x) for `RiskManager`.

## 4. MQL5 Integration
### 4.1 `CPythonBridge` Class
- **Methods:**
    - `WriteTickData(tick)`: Appends to CSV (buffered).
    - `ReadAnalysis()`: JSON parser to get "Co-Pilot" advice.
- **Fail-Safe:** If Python stops updating (Timestamp check > 5 sec), MQL5 falls back to internal logic (Standard ADX/ATR).

## 5. Workflow
1.  **MQL5:** Collects Ticks -> Flushes to CSV every 1 sec.
2.  **Python:** Watches CSV -> Calculates Filtered Trend & VaR -> Writes JSON.
3.  **MQL5:** Reads JSON on New Bar (or Timer) -> Updates `Environment` -> Adjusts Risk/Signals.
