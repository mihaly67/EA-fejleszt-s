# Handover Report - Trojan Horse v3.0 & Broker Analysis

## 📅 Session Summary
**Focus:**
1.  **Broker Logic Analysis:** Reverse-engineering the broker's response to stress (100 Lot orders) using historical logs.
2.  **Trojan Horse EA v3.0:** Upgrading the testing tool to support "Hybrid" (Manual + Auto) strategies with advanced UI controls.

**Outcome:**
*   **Analysis:** Identified "Elastic Defense" strategy (Broker absorbs flow via Price Drift + Deep Liquidity, no execution lag).
*   **Tooling:** Delivered `Trojan_Horse_EA_v3.0.mq5` with a fully functional GUI for real-time stress testing.

## 🛠 System Changes

### 1. Trojan Horse EA v3.0 (New!)
*   **File:** `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5`
*   **Key Features:**
    *   **Manual Mode:** Toggle between AUTO (Algorithm) and MANUAL (Human).
    *   **Dual-Row Manual Panel:** Dedicated buttons for "Decoy" (Small Lot) and "Trojan" (Big Lot) trades.
    *   **Strategy Switcher:** On-the-fly buttons to change Auto logic (`[BUY]`, `[SELL]`, `[CNTR]`, `[FLLW]`, `[RND]`) without restarting.
    *   **Live Parameter Editing:** Lot sizes (Auto & Manual) can be updated instantly via the panel text boxes.
    *   **Fresh Pricing:** Manual execution now explicitly calls `RefreshRates()` to prevent "Off Quotes" errors.

### 2. Broker Analysis Suite
*   **File:** `analyze_broker_logic.py`
*   **Output:** `analysis_output_eurusd/BROKER_LOGIC_SUMMARY_HU.md`
*   **Findings:**
    *   **Latency:** No lag during stress (1.7s vs 2.8s baseline).
    *   **Price:** +26 Point Drift during attack (Broker passes risk to price).
    *   **Liquidity:** Spoofing Ratio increased (Level 1 thin, Levels 2-5 thick).

## 📝 User Instructions (Next Session)
1.  **Test v3.0:** Deploy `Trojan_Horse_EA_v3.0` on a demo chart (e.g., Crypto or Forex).
2.  **Verify UI:** Check that clicking the Strategy Buttons (`[BUY]`, `[CNTR]`) changes the status text and behavior.
3.  **Verify Live Edit:** Change the "Auto Lot" from 0.01 to 0.05 in the box, press Enter, and confirm the next auto-trade uses the new size.
4.  **Execute Strategy:** Use the Manual "S-BUY" buttons to create noise, then "T-BUY" for the Trojan entry, and observe the broker's reaction in the logs.

## 📂 File Manifest
*   `Factory_System/Experts/Trojan_Horse_EA_v3.0.mq5` (The definitive EA)
*   `analyze_broker_logic.py` (Analysis Tool)
*   `analysis_output_eurusd/BROKER_LOGIC_SUMMARY_HU.md` (Findings)
