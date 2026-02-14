# Session Handover Report: Merkava Project (2026-02-14)

**Date:** 2026.02.14 17:38
**Status:** Stable / Ready for Next Phase
**Last Version:** Merkava v2.20 (Fixed)

## Executive Summary
This session focused on stabilizing the development environment and fixing critical compilation errors in the flagship EA (`Merkava_v2_20.mq5`). We also established a robust environment restoration script (`restore_envTC2.py`) to ensure "101% combat readiness". An attempt to implement a Linux-based MQL5 compilation toolchain (via WINE) was explored but ultimately **frozen** due to sandbox limitations.

## Achievements

### 1. Merkava v2.20 Repairs (COMPLETED)
*   **Compilation Fix:** Restored missing helper functions (`GetNetLotDirection`, `DetermineVerdict`, `GetSLTPSnapshot`, `CheckForNewDeals`) from v2.18.
*   **Syntax Fix:** Corrected variable declarations (`total_lots`) and function signatures in `OnTick`.
*   **Log Optimization:** Disabled excessive debug logging (`TEST TICK...`) to prevent journal spam, as requested.
*   **Status:** The EA now compiles and runs correctly.

### 2. Environment Restoration (COMPLETED)
*   **`restore_envTC2.py`:** Created a new, enhanced setup script.
    *   **Features:** Dependency auto-install, Git Hard Reset (Force Sync), Resource Integrity Checks (SQLite/JSONL), Self-Healing (Redownload on corruption).
    *   **Testing:** Integrated `kutato.py` for RAG verification (excluding Indicator Layering).
    *   **Localization:** Hungarian logging enabled.

### 3. Compiler Toolchain (FROZEN)
*   **Objective:** Enable MQL5 compilation on Linux using WINE.
*   **Result:** Sandbox environment lacks WINE and root privileges to install it. Portable WINE attempts (AppImages/Build Scripts) failed.
*   **Status:** The developed Python scripts (`setup_compiler.py`, `compile_mql5.py`) are preserved in the repo but the initiative is **frozen** until a viable WINE solution is found. We revert to the standard "code here, compile there" workflow.

## Critical Issues / Blockers
*   **WINE Environment:** No viable way to run `metaeditor64.exe` in the current sandbox. This forces reliance on external compilation.

## Roadmap (Next Session)
**Primary Objective:** Integrate **HybridContextIndicator** into Merkava.

1.  **Context Integration:** Replace the temporary test indicator (HybridMomentum) with the full `HybridContextIndicator_v3.18`.
2.  **Logic Update:** Ensure the EA logic correctly utilizes the Context buffers (Pivots, Trends) for decision making.

## Files State
*   `Merkava_v2_20.mq5`: **STABLE** (Fixes Applied).
*   `ENVIRONMENT_SETUP/restore_envTC2.py`: **STABLE** (New Standard).
*   `setup_compiler.py` / `compile_mql5.py`: **ARCHIVED/FROZEN**.
