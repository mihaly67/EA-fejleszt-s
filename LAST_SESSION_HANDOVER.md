# Handover Report - Trojan Horse v3.1 Mimic Trap

## 📅 Session Summary
**Focus:**
1.  **Trojan Horse v3.1 Development:** Implemented the "Mimic Trap" strategy (Liquidity Piggybacking) as a semi-automated execution mode.
2.  **Chart Hygiene:** Finalized the cleanup of persistent "ghost" trade history objects.

**Outcome:**
*   **Trojan Mimic Trap:** A new "TRAP" toggle on the UI arms the strategy. Instead of entering immediately, the EA waits for consecutive counter-ticks (default 2) to detect algorithmic "push" or "stops hunting". It then executes 3x Decoy trades (with the push) followed by 1x Trojan trade (against the push, with the real trend).
*   **Chart Cleanup:** Native history is disabled (`CHART_SHOW_TRADE_HISTORY=false`), replaced by a custom, ephemeral visualization engine that cleans itself up on exit.

## 🛠 System Changes

### 1. Trojan Horse EA v3.1
*   **File:** `Factory_System/Experts/Trojan_Horse_EA_v3.1.mq5`
*   **New Inputs:**
    *   `InpMimicTriggerTicks` (Default: 2): Sensitivity (Consecutive counter-ticks needed).
    *   `InpMimicDecoyCount` (Default: 3): Number of fake trades to send.
    *   `InpTrapTimeout` (Default: 30): Safety timeout in seconds.
*   **New UI:** "TRAP: OFF/ON" toggle button.

## 📝 User Instructions (Next Session)

### 1. Test "Mimic Trap"
1.  **Analyze Trend:** Assume you see a **BULL** trend but want to wait for the "dip".
2.  **Arm Trap:** Click **"TRAP: OFF"** -> Becomes **"TRAP: ON"**.
3.  **Signal Direction:** Click **"S-BUY"** (Small Buy).
    *   *Note:* No trade happens yet. Status shows "[TRAP ARMED]".
4.  **Wait:** Watch the ticks.
    *   The EA waits for **2 consecutive Bearish ticks** (price drops).
5.  **Trigger:**
    *   Once the drop happens, you should see:
        *   3x **SELL** (Decoy) arrows appear instantly.
        *   1x **BUY** (Trojan) arrow appears immediately after.
    *   The TRAP toggles back to OFF automatically.

## 📂 File Manifest
*   `Factory_System/Experts/Trojan_Horse_EA_v3.1.mq5`
