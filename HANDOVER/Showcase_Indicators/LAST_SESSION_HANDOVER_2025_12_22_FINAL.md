# Session Handover - Critical Fixes & Standardization (2025-12-22)

## 🔴 Critical Findings: The "Future Peek" & Repainting Bugs
During the fine-tuning phase, a systemic logical error was identified in how external data was integrated into the Hybrid Indicators.

### 1. The "Future Peek" (Inverted Time) Bug
*   **Issue:** The MQL5 `CopyBuffer` function retrieves data into an array where index `0` represents the **Newest** bar (Time-Descending). However, our `OnCalculate` loops iterate from `0` (Oldest) to `rates_total` (Newest).
*   **Impact:**
    *   **Hybrid Momentum (v2.4):** The logic mixed the *Oldest* price bars (e.g., from 2020) with the *Newest* Stochastic values (from 2025). This created nonsensical "Fusion" signals that looked continuous but were mathematically garbage.
    *   **Hybrid Context (v2.2):** Trend detection logic (`High[i] > Low[j]`) was ambiguous, potentially misinterpreting the direction of Micro-Trends.
*   **Fix Implemented:** Explicitly set `ArraySetAsSeries(buffer, true)` for all external data arrays and corrected loop indexing to map `i` (Time-Ascending) to `Series[Total - 1 - i]` (Time-Descending).

### 2. The "Repainting" (Snap-Back) Bug
*   **Issue:** In `HybridFlowIndicator` (v1.7-1.9), the `CopyBuffer` function overwrote the entire indicator buffer with raw MFI data (0-100) on every tick. The calculation loop only re-applied the "Unbounded" offset to the *newly calculated* bars.
*   **Impact:** Historical peaks that correctly exceeded 100 would "snap back" to 100 as soon as a new bar arrived, creating a misleading visual history (Repainting).
*   **Fix Implemented:** Introduced a hidden `RawMFIBuffer` to store the source data. The display buffer is now purely calculated (`Raw + Offset`) and never overwritten by `CopyBuffer`.

## 🟢 Implemented Solutions (Factory Ready)

### 1. Hybrid Momentum v2.5 (Adaptive Boost)
*   **Status:** **FIXED & ENHANCED**
*   **Logic:**
    *   **Adaptive:** Uses Inverse Volatility (`Multiplier = 1 + (Max-1)*exp(-Vol)`) to inject Stochastic momentum specifically when the market is flat (Night Mode).
    *   **Alignment:** Corrected `stoch_temp` indexing to match Price time.
*   **Visuals:** Signal Line is now visible (Solid/2px).

### 2. Hybrid Flow v1.10 (Unbounded)
*   **Status:** **FIXED & ENHANCED**
*   **Logic:**
    *   **Unbounded:** Hybrid MFI curve now correctly exceeds 0/100 bounds to show Volume intensity.
    *   **Persistence:** Fixed repainting; peaks remain visible historically.
    *   **Alignment:** Corrected `RawMFI` indexing.
*   **Visuals:** Auto-Scaling enabled by default (`InpUseFixedScale=false`) to fit peaks of any magnitude.

### 3. Hybrid Context v2.3 (Styling)
*   **Status:** **STANDARDIZED**
*   **Feature:** Removed hardcoded styles. Users can now configure **Color**, **Width**, and **Style** (Solid/Dash/Dot) for:
    *   Primary Pivots (P, R1, S1)
    *   Secondary Pivots
    *   Trend Lines
    *   Fibo Lines
*   **Fix:** Corrected "Smart Fibo" trend detection logic.

## 📜 New Development Standard
**Rule:** All future indicators and EAs must expose visual attributes as Input Parameters.
*   **Forbidden:** Hardcoded `STYLE_SOLID`, `width=1`, `clrRed`.
*   **Mandatory:** `input color`, `input int InpWidth`, `input ENUM_LINE_STYLE`.

## 📌 Next Steps
1.  **Verification:** User to test v2.5 and v1.10 to confirm the "Future Peek" and "Repainting" bugs are gone.
2.  **EA Integration:** Once validated, these "Final" indicators will be assembled into the `Hybrid_Visual_Assistant` EA.

## 🕒 Timestamp
Session completed: 2025-12-22 22:45 UTC.
