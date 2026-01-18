# Handover Report - Mimic Trap EA v1.0 (Clean Slate)

## 📅 Session Summary
**Focus:**
1.  **Strategic Pivot:** Responding to user feedback about code complexity ("700+ lines", "foltozgatás"), we pivoted from patching the legacy `Trojan_Horse_EA` to creating a new, dedicated tool.
2.  **Implementation:** Developed `Mimic_Trap_EA_v1.0.mq5`, a lightweight Expert Advisor focused exclusively on the "Mimicry Trap" strategy.

**Outcome:**
*   **Mimic Trap EA v1.0:**
    *   **Dedicated Tool:** No Auto-Trading, no Physics engine, no complex modes. Just the Trap logic.
    *   **Clean UI:** Simple "TRAP BUY" / "TRAP SELL" buttons that arm the strategy immediately.
    *   **Visualization:** Uses the confirmed `DrawDealVisuals` engine to show current trades (Blue/Red arrows) while keeping the chart history clean (`Ghost Object` protection).
*   **Trojan Horse v3.3:** The previous codebase was also updated with UX fixes (Visual Feedback) as a backup, but `Mimic_Trap_EA` is the recommended path forward.

## 🛠 System Changes

### 1. Mimic Trap EA v1.0 (New!)
*   **File:** `Factory_System/Experts/Mimic_Trap_EA_v1.0.mq5`
*   **Logic:**
    *   **Button Click:** Arms the trap immediately.
    *   **Waiting:** Waits for `InpTriggerTicks` (default 2) ticks moving *against* the target direction.
    *   **Execution:** Fires 3x Decoy trades (Fake direction) + 1x Trojan trade (Real direction).
    *   **Timeout:** Resets after 60 seconds if no trigger occurs.

### 2. Trojan Horse EA v3.3 (Legacy Update)
*   **File:** `Factory_System/Experts/Trojan_Horse_EA_v3.3.mq5`
*   **Fix:** Added visual (Orange color) and audio (Tick sound) feedback to S-BUY/S-SELL buttons when in Trap Mode.

## 📝 User Instructions (Next Session)

### 1. Use "Mimic Trap EA"
1.  **Load:** Attach `Mimic_Trap_EA_v1.0` to the chart.
    *   *Note:* The chart will clear old history immediately.
2.  **Scenario:** You see a Bull Trend but want to catch the "Dip".
3.  **Action:** Click the **GREEN "TRAP BUY (Wait Dip)"** button.
    *   The button lights up Orange ("ARMED").
4.  **Observe:**
    *   The EA waits for the price to tick DOWN 2 times.
    *   **Trigger:** It opens 3 Sells (Decoy) and 1 Buy (Trojan).
    *   **Sound:** You hear "ok.wav" on success.

## 📂 File Manifest
*   `Factory_System/Experts/Mimic_Trap_EA_v1.0.mq5` (Primary)
*   `Factory_System/Experts/Trojan_Horse_EA_v3.3.mq5` (Backup)
