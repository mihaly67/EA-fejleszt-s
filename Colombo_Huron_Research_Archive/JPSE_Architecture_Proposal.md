# JULES PYTHON STRATEGY ENGINE (JPSE) - ARCHITECTURAL PROPOSAL
# "The Brain for the Brawn"

## 1. Core Philosophy
*   **MQL5 is the Body:** It handles execution, speed, spread checks, and basic safety (Stop Loss). It is "dumb" but fast.
*   **Python is the Brain:** It handles memory, pattern recognition, "Heartbeat" analysis (Hybrid Indicators), and strategic decisions (Trap vs Burst vs Hold).
*   **Communication:** ZeroMQ (ZMQ) or Named Pipes for sub-millisecond latency. (File IO is too slow for "Flash Crash" defense).

## 2. Input Data (The "Senses")
The Python Engine will receive a stream of "Tick Packets" from MQL5 (every tick or 100ms):
```json
{
  "symbol": "SP500",
  "bid": 6938.50,
  "ask": 6939.16,
  "micro_state": {
     "channel_high": 6940.00, // 1-min High
     "channel_low":  6935.00, // 1-min Low
     "channel_mid":  6937.50
  },
  "heartbeat": {
     "hybrid_color": 1, // 0=Gray, 1=Green, 2=Red
     "flow_mfi": 65.0,  // Volume Pressure
     "momentum": 12.5
  },
  "physics": {
     "velocity": 5.2,
     "acceleration": -1.2
  }
}
```

## 3. Decision Logic (The "Cortex")
The engine processes the stream to detect specific contexts:

### A. The "Channel Sniper" (Side-ways Market)
*   **Condition:** `Hybrid_Color` is flickering/neutral AND Price is at `channel_high` or `channel_low`.
*   **Action:** Signal "Counter-Trend Entry" (Sell at High, Buy at Low).
*   **Trap:** Use `Mimic_Trap` logic (Decoy first).

### B. The "Momentum Surfer" (Trend Market)
*   **Condition:** `Hybrid_Color` is strong Green/Red AND `Flow_MFI` > 80 (High Pressure).
*   **Action:** Signal "Trend Entry" (Ride the wave).
*   **Burst:** Use `Burst_Trap` to feed the momentum.

### C. The "Flash Crash Defender" (Safety)
*   **Condition:** `Velocity` > 25.0 (Abnormal Spike) OR `Acceleration` < -10.0 (Rug Pull).
*   **Action:** Signal "EMERGENCY CLOSE ALL".

## 4. Money Management (The "Banker")
*   **Margin Awareness:** Python tracks `AccountEquity` vs `MarginUsed`.
*   **HUF Context:** Calculates risk in User's currency (HUF) real-time.
*   **Goal:** "Hit and Run". If Session PL > Target (e.g. 150 EUR), force STOP and cooldown.

## 5. Next Steps
1.  **Bridge:** Develop a simple ZMQ bridge for MQL5.
2.  **Prototype:** Create `JPSE_v01.py` that just prints recommendations (Signal Only).
3.  **Live Test:** Connect MQL5 to listen to `JPSE` commands.
