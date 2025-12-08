# Last Session Handover (Clean Repo & Simple Setup)

## Critical Repository Policy (READ FIRST)
- **Status:** Repository size reduced from 14GB to ~371MB.
- **Action Taken:** Deleted `rag_mql5`, `rag_mql5_big`, `rag_theory`, `rag_code` folders from git tracking.
- **Rule:** **NEVER commit the `rag_*` folders.** They must remain in `.gitignore`. The environment setup script handles their download.
- **Reason:** Large files caused background task failures during cloning.

## Environment Setup
- **Script:** `jules_env251207_simple` (Bash).
- **Features:**
  - Removed `set -e` (tolerant mode) to prevent false failures.
  - Robust extraction logic for nested/flat zips.
  - Downloads RAGs only if missing.

## Research Status (Hybrid System)
- Location: `Showcase_Indicators/Hybrid_System_Research/`
- Contents:
    - JMA/HMA/ZeroLag source codes and research notes.
    - `Hybrid_System_Showcase.mq5` template.
- **Next Step:** Implement the JMA math into the showcase indicator.

## Architecture Plan (Next Session)
- **Goal:** Optimize RAG access further.
- **Idea:** Split the 6GB MQL5 DB or use a Remote Access method (download only index + fetch content on demand) to avoid the heavy download at startup.

## Factory Status
- Background research was initiated on "Hybrid Scalping". Check `Factory_System/tasks_inbox/` status on startup.
