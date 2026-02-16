# Merkava Stealth Strategy: Humanization & Obfuscation (v1.0)

**Date:** 2026.02.16
**Objective:** Disguise algorithmic trading behavior to appear "human-like" and confuse broker profiling systems.
**Core Principle:** "Perfect execution is suspicious. Humans are messy, slow, and inconsistent."

---

## 1. MQL5 Native Implementation (Phase 1 - Immediate)
*These features can be implemented directly within `StealthEngine.mqh` without external dependencies.*

### A. Temporal Jitter (Anti-Machine Timing)
*   **Concept:** Algorithmic orders often arrive at predictable intervals (e.g., exactly 0ms after a tick). Humans have reaction times (200ms - 1500ms).
*   **Implementation:**
    *   `Sleep()` with Gaussian distribution (Mean: 400ms, StdDev: 150ms).
    *   **Randomized Re-quotes:** Occasionally reject a valid signal (simulating "hesitation").
    *   **Session Fatigue:** Increase delays slightly as the trading session progresses (simulating tiredness).

### B. Price Fuzzing (Anti-Clustering)
*   **Concept:** Crowd behavior clusters SL/TP at round numbers (psychological levels). Algorithms target these. To be "human but smart", we must avoid perfect mathematical levels.
*   **Implementation:**
    *   **Micro-Pips Jitter:** Add/Subtract `MathRand()` (e.g., +/- 1-5 points) to calculated Entry/SL/TP prices.
    *   **"Fat Finger" Simulation (Low Probability):** 0.1% chance to enter a slightly worse price (slippage simulation) or slightly different lot size (e.g., 0.11 instead of 0.10).

### C. Metadata Obfuscation
*   **Concept:** Brokers profile strategies based on `MagicNumber` and `OrderComment`.
*   **Implementation:**
    *   **Dynamic Magic Numbers:** Use a base ID + random offset per session (requires careful tracking). *Risk: complicates trade management.*
    *   **Human Comments:** Rotate through a list of "human" comments (e.g., "", "manual", "news", "t1", "test"). **Never** use "Merkava_v2.30".

---

## 2. Python Bridge Integration (Phase 2 - Advanced)
*Required for complex ML behavior or GUI spoofing. Uses `dwx-zeromq-connector` pattern found in `EXT_THIEFS`.*

### A. Architecture: ZeroMQ Bridge
*   **Mechanism:** MQL5 acts as a "dumb" execution terminal. Python runs the brain.
*   **Libraries:**
    *   **MQL5:** `ZeroMQ_MT4.mqh` (Adapted for MT5).
    *   **Python:** `pyzmq`, `pandas`, `FinRL` (for decision logic).

### B. GUI Spoofing (Ultimate Stealth)
*   **Concept:** Bypassing the MQL5 `OrderSend` API entirely. The broker sees mouse clicks on the terminal buttons, not API calls.
*   **Tools:** `pyautogui` (found in `EXT_THIEFS`), `selenium-stealth` (less relevant for desktop app).
*   **Workflow:**
    1.  Python analyzes market data.
    2.  Python calculates trade.
    3.  Python uses `pyautogui` to move the mouse cursor to the "Buy" button on the MT5 terminal window.
    4.  Python clicks.
    *   **Pros:** Indistinguishable from manual trading.
    *   **Cons:** High latency, fragile (window position matters), blocks user from using PC.

### C. Behavioral Cloning (ML)
*   **Concept:** Train an LSTM/Transformer model (e.g., via `FinRL` or `nautilus_trader`) on *actual* manual trading history to learn "human" patterns (e.g., revenge trading, scaling in).
*   **Implementation:** Python model predicts "Human Probability" of a trade. MQL5 executes only if prob > threshold.

---

## 3. Implementation Roadmap

### Step 1: `StealthEngine.mqh` (Current Task)
*   [ ] `GetHumanDelay()`: Gaussian random sleep.
*   [ ] `GetFuzzyPrice(price)`: Add micro-pip jitter.
*   [ ] `GetHumanComment()`: Random selection from list.

### Step 2: EA Integration
*   [ ] Wrap `OrderSend` calls in `Merkava_v2.31` with `StealthEngine` methods.
*   [ ] Add Input Parameters: `bool EnableStealth`, `int MaxDelayMS`.

### Step 3: Python Bridge (Future)
*   [ ] Set up `dwx-zeromq-connector`.
*   [ ] Build Python `Strategic_Command.py` script.
