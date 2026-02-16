# Handover Report: Merkava v2.20 Production Candidate (Fixes)

**Date:** 2026-02-13
**Version:** v2.20
**Author:** Jules (AI Assistant)

## Summary of Changes

This release finalizes the **Merkava v2.20 Production Candidate**. It addresses critical compilation errors and functional defects found in the previous iteration, ensuring a stable platform for validating the Control Panel logic and the `HybridMomentum` integration.

### 1. Compilation Fixes (Merkava v2.20)
*   **Syntax Errors:** Resolved `undeclared identifier` and `expression expected` errors in `Merkava_v2_20.mq5` caused by missing variable declarations (`total_lots`) and incorrect function call syntax (`FireGrid`, `RecordTick`).
*   **Variable Scope:** Corrected access to `PhysicsState` members (e.g., using `p.velocity` instead of `velocity`).

### 2. Control Panel Logic
*   **Restored Event Handling:** The `OnChartEvent` function now fully processes `EVENT_FIRE_BUY`, `EVENT_FIRE_SELL`, and `EVENT_CEASE_FIRE`.
*   **Directional Fire:** The "Fire Buy" and "Fire Sell" buttons correctly trigger directional grids via the updated `FireControl` logic.
*   **Cease Fire:** The "Cease Fire" button correctly executes the `DeleteAllOrders` and `CloseAllPositions` sweep.
*   **Version Label:** The panel now correctly displays "MERKAVA v2.20".

### 3. Indicator Configuration
*   **Hybrid Momentum:** The EA remains configured to use `HybridMomentumIndicator_v2.82` (via `NavSystem_v2_11`) for the ongoing stability test protocol.
*   **Context Indicator:** The visually fixed `HybridContextIndicator_v3.18.mq5` is preserved in the codebase for future re-integration.

## Files
*   `MQL5/Indicators/Jules/Merkava_v2_20.mq5` (Fixed EA)
*   `MQL5/Indicators/Indicators/PanelControl_v2_20.mqh` (Panel Logic)
*   `MQL5/Indicators/Indicators/FireControl_v2_20.mqh` (Fire Logic)
*   `MQL5/Indicators/Indicators/NavSystem_v2_11.mqh` (Momentum Support)
*   `MQL5/Indicators/Indicators/BlackBox_v2_08.mqh` (Momentum Logging)

## Usage Instructions
1.  **Compile:** Compile `Merkava_v2_20.mq5`. It should now compile without errors.
2.  **Verify:**
    *   Load the EA.
    *   Confirm panel shows "MERKAVA v2.20".
    *   Test the buttons.
    *   Verify Momentum values in the "Experts" log.
