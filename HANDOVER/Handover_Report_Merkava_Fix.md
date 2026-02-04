# Handover Report - Project Merkava: CSV Repair & Constraint Update
**Date:** 2026.02.03 23:50
**Subject:** CSV Fix Implementation (No Directory Restructuring)
**To:** Commander (User)

## ⚠️ Critical Constraint Update
**Directive:** Do **NOT** restructure the directory system yet.
**Reason:** To maintain stability on the deployment machine and avoid "Elephant Swallowing" (doing too much at once).
**Action:** All new modules (`BlackBox`, `NavSystem`, `Camouflage`) will be placed in `MQL5/Indicators/`, alongside existing `FireControl.mqh` and `PhysicsEngine.mqh`.

## 🛠️ The Fix (v1.04)
The primary goal of this session remains **repairing the CSV logs** to enable forensic analysis.

1.  **File Locations:**
    *   `MQL5/Experts/Mimic_Merkava_v1.04_Fixed.mq5` (The EA)
    *   `MQL5/Indicators/Mimic_BlackBox.mqh` (PL Fix)
    *   `MQL5/Indicators/Mimic_NavSystem.mqh` (Flow Fix)
    *   `MQL5/Indicators/Mimic_Camouflage.mqh` (Stealth)

2.  **Repairs Implemented:**
    *   **Profit/Loss Bug:** `Mimic_BlackBox.mqh` now correctly calculates Floating PL by iterating active positions, eliminating the duplication/volatility bug.
    *   **Flow Blindness:** `Mimic_NavSystem.mqh` now calculates `Flow_ROC` and `Flow_Delta` internally from price/volume ticks, ensuring valid data is logged even if external indicators fail.

## 🔜 Future Roadmap (The F-35 Path)
1.  **Phase 1 (Current):** Perfect the CSV logging (Merkava v1.04).
2.  **Phase 2:** Analyze the clean logs in the Forensic Lab.
3.  **Phase 3:** Build the **C++ Bridge** (DLL) for real-time Python communication.
4.  **Phase 4 (F-35):** Python takes over Risk Management and Strategy injection.

## 📂 File Manifest (Updated)
*   `MQL5/Experts/Mimic_Merkava_v1.04_Fixed.mq5`
*   `MQL5/Indicators/Mimic_BlackBox.mqh`
*   `MQL5/Indicators/Mimic_NavSystem.mqh`
*   `MQL5/Indicators/Mimic_Camouflage.mqh`
