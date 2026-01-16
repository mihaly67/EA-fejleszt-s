# Handover Report - Trojan Horse Stress Test & DOM Analysis

## 📅 Session Summary
**Focus:** Refactoring `Trojan_Horse_EA` and `Hybrid_DOM_Logger` for unified market analysis and performing a stress test on EURUSD (CFD).
**Outcome:** Successfully created a "Two-Pronged" testing suite (Attacker + Observer). Confirmed that 100 Lot stress trading significantly impacts available liquidity (spoofing/pulling) and market velocity, even on B-Book CFDs.

## 🛠 System Status

### 1. Trojan_Horse_EA (v1.01)
*   **Status:** ✅ Stable & Tested
*   **Location:** `Factory_System/Experts/Trojan_Horse_EA_v1.01.mq5`
*   **Features:**
    *   **Trading Modes:** ALWAYS_BUY, ALWAYS_SELL, COUNTER_TICK, FOLLOW_TICK, RANDOM.
    *   **Stealth Mode:** Randomized intervals/lots to evade algo detection (needs further tuning).
    *   **Logging:** Unified CSV schema matching the DOM Logger (includes Physics/Depth columns).
    *   **Reliability:** Uses `FileFlush` after every write to guarantee data survival during crashes/stops.
    *   **Cleanup:** Aggressive `ObjectsDeleteAll` on exit.

### 2. Hybrid_DOM_Logger (v1.02)
*   **Status:** ✅ Stable
*   **Location:** `Factory_System/Diagnostics/Hybrid_DOM_Logger.mq5`
*   **Features:**
    *   **Unified Schema:** Outputs logs compatible with EA logs for merging.
    *   **Data:** Records L1-L5 Depth, Velocity, Acceleration, Spread.
    *   **Filename:** `Symbol_YYYYMMDD_HHMMSS.csv` format.

### 3. Analysis Tools
*   **Script:** `analyze_trojan_dom.py` (Pure Python)
*   **Capabilities:**
    *   Merges EA and Logger logs.
    *   Segments analysis by Test Phase (e.g., "0.01 Lot" vs "100 Lot").
    *   Calculates Avg Velocity, Spread Stability, and Liquidity (Depth) changes.

## 📊 Research Findings (Stress Test 2026.01.16)
*   **Scenario:** 100 Lot Buy/Sell spamming on EURUSD.
*   **Velocity:** Jumped from **0.39** (Base) to **1.22** (Stress) -> 3x increase.
*   **Liquidity (DOM):** Total Liquidity dropped **~4.3%**. Specifically, **Bid Liquidity dropped ~30%**, suggesting algos pulled buy orders to avoid being hit by the user's selling/churning.
*   **Execution:** Spread remained artificially stable (6.6-6.7 pts), indicating B-Book/Internalization behavior rather than ECN slippage.
*   **Issue:** The EA's "Close Profit" logic was too slow to handle the high-velocity "tsunami", requiring manual intervention.

## 📝 Next Steps / TODO
1.  **Optimization:** Improve `Trojan_Horse_EA` closing speed (implement Async Order Sending or Bulk Closing?) to handle "Exit Tsunamis".
2.  **Extended Testing:**
    *   Test on **Crypto pairs** (high spread environment).
    *   Systematically test **all 6 Trading Modes** (incl. Stealth) to map Algo responses.
    *   Analyze "Stealth" efficacy: Does `Velocity` spike less in Stealth Mode?
3.  **Visualization:** Create a Matplotlib script to *visualize* the Velocity/Liquidity correlation over time (scatter plots).

## 📂 File Manifest
*   `Factory_System/Experts/Trojan_Horse_EA_v1.01.mq5`
*   `Factory_System/Diagnostics/Hybrid_DOM_Logger.mq5`
*   `analyze_trojan_dom.py`
*   `temp_depth_check.py` (Ad-hoc analysis tool)
