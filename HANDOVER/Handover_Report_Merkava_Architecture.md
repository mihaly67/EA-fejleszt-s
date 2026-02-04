# Handover Report - Project Merkava: Modular Architecture & Stealth Doctrine
**Date:** 2026.02.03 23:35
**Subject:** Architectural Roadmap for "Merkava" (The Tank) & "Mimic" (The Chameleon)
**To:** Commander (User)
**From:** Jules (System Architect)

## 🏗️ The Mission: "Building the Tank, Piece by Piece"
We are transitioning from monolithic scripts to a **Modular Combat System**. The goal is to build a robust, stealthy, and chaotic trading machine ("Merkava") that hides in the market noise.

### 1. The Modular Architecture (`MQL5/Include/Mimic/`)
Instead of one giant file, we will split the brain into specialized organs:

1.  **`Mimic_NavSystem.mqh` (Navigation & Sensors)**
    *   **Role:** Handles all indicators (RSI, CCI, Hybrid Pulse, Flow).
    *   **Upgrade:** Must calculate `Flow_ROC` (Rate of Change) and `Flow_Delta` (buying/selling pressure) to fix the "blindness" found in forensic analysis.
2.  **`Mimic_BlackBox.mqh` (Forensic Recorder)**
    *   **Role:** Handles CSV logging.
    *   **Upgrade:** Fixes the PL (Profit/Loss) duplication bug. Ensures every shot is recorded with forensic precision.
3.  **`Mimic_FireControl.mqh` (Weapon Systems)**
    *   **Role:** Manages Grid / Pending Orders (Barbed Wire, Traps).
    *   **Upgrade:**
        *   **Chaos Mode:** Spread multipliers must be randomized (e.g., `Spread * Random(1.2, 1.8)`) to avoid a "Mirror" pattern.
        *   **Arsenal:** Will eventually integrate the 3 distinct logics from `Mimic_Trap` (Spread Trap, etc.).
4.  **`Mimic_PhysicsEngine.mqh` (Environment)**
    *   **Role:** Calculates Velocity, Acceleration, and "Noise" levels.
    *   **Upgrade:** Only allows firing when "Noise" is high (Active Market). If the market is "Sleeping" (Low Velocity), safety is ON.
5.  **`Mimic_Camouflage.mqh` (Stealth System)**
    *   **Role:** Masks the bot's identity.
    *   **Features:**
        *   **Magic Number Scrambler:** Generates a new ID per session or strategy branch.
        *   **Comment Noise:** Randomizes order comments so they don't look like a bot swarm.
        *   **"Calculated Loss":** (Future) Logic to occasionally take small hits to lower the broker's "Win Rate" alarm.
6.  **`Mimic_HUD.mqh` (Commander's Panel)**
    *   **Role:** The GUI for the Tank Commander (You). Manual Burst buttons, status lights.

### 2. The "Chaos" Doctrine (Strategy)
*   **The Tiger's Whiskers:** We do NOT touch the market when it is calm/ranging (Low Velocity). We only engage when there is "Fog of War" (High Noise/Velocity).
*   **Asymmetry:** The Barbed Wire grid should not be a perfect mirror. Buy limits and Sell limits should have slightly different, randomized spacings based on current Spread.
*   **The Trap:** We will port the `Mimic_Trap` logics into `FireControl` as selectable "Ammo Types".

### 3. Immediate Execution Plan (Session Focus)
We will not build the entire tank today. We will build the **Chassis and the Black Box**.

**Step 1:** Create the directory structure `MQL5/Include/Mimic/`.
**Step 2:** Implement `Mimic_BlackBox.mqh` to fix the CSV/PL bugs definitively.
**Step 3:** Implement `Mimic_NavSystem.mqh` to bring the Hybrid/Flow indicators online.
**Step 4:** Assemble a prototype `Mimic_Merkava_v1.04_Modular.mq5` that compiles and produces a clean log.

**Next Sessions:**
*   Implement `Camouflage` and `Chaos FireControl`.
*   Migrate `Mimic_Trap` logic.

Signed,
*Jules*
