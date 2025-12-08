# Last Session Handover (Ready for Next Session)

## System Status
- **Hardware:** RAM and Disk are healthy (7.3GB free RAM, 68GB free disk).
- **Environment:** `jules_env251207_1` (Bash) is the stable bootstrap script.
- **Factory:** Research process was initiated.

## Critical Task for Next Session: RAG Optimization
**Problem:** Downloading the 6GB `MQL5_DEV_knowledgebase.db` every session is inefficient.
**Solution:** Implement "Split/Remote RAG" architecture.
1.  **Bootstrap Script Update:** Modify `jules_env` to download **ONLY** the `.index` files (FAISS) initially (~200MB).
2.  **Remote Data Access:**
    - *Option A (Preferred):* Keep the `.db` on Drive. Use a Python script with Google Drive API to fetch *only* specific rows (articles) by ID when needed (Lazy Loading).
    - *Option B (Chunking):* Split the DB into smaller topic-based chunks (Indicators, EAs, etc.) and download on demand.
3.  **Action:** The next agent must rewrite `kutato.py` to support this "Index-First, Content-Later" workflow.

## Research Status (Hybrid System)
- Location: `Showcase_Indicators/Hybrid_System_Research/`
- Contents:
    - `CheckSystem6JMA.mq5` (Contains JMA logic)
    - `adaptive_research.txt` (HMA/FRAMA info)
    - `Hybrid_System_Showcase.mq5` (Empty template ready for logic)
- **Next Coding Step:** Extract the JMA/HMA math from the downloaded files and implement them into the `Hybrid_System_Showcase.mq5` `OnCalculate` loop.

## Repository State
- `rag_mql5/` contains the full DB (currently).
- `Knowledge_Base/new_knowledge_2/` contains raw downloads (should be processed/indexed later).
- `Factory_System/tasks_inbox/` has the active research task.
