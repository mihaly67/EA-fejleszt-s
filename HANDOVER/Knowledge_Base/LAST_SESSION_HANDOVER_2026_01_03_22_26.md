# Last Session Handover (2026.01.03.22:26)

## Overview
This session focused on standardizing the RAG (Retrieval-Augmented Generation) system and JSONL Knowledge Base naming conventions.

## ⚠️ CRITICAL: PENDING ACTIONS (FAILED SUBMISSION)
**The following scripts were NOT successfully submitted to the repository and require immediate attention at the start of the next session:**
1.  **`kutato.py`**: Fixes for MQL5_DEV/THEORY/CODE scopes and SQL table names are pending.
2.  **`kutato_ugynok_v3.py`**: Fixes for explicit scope iteration are pending.

**Action Required:**
- Verify the local state of these files.
- Force a commit/push to ensure they are synchronized with the repo.

## Completed Changes (To be verified)

### 1. RAG System Standardization
- **Scopes Unified:** The intent is to strict enforce:
  - `MQL5_DEV`: Points to `rag_mql5_dev`.
  - `THEORY`: Points to `rag_theory`.
  - `CODE`: Points to `rag_code`.
- **SQL Fix:** The `THEORY` RAG query needs to target the `articles` table.

### 2. JSONL Knowledge Base Renaming
Filenames standardized (verify existence):
- `knowledge_base_github.jsonl`
- `knowledge_base_mt_libs.jsonl`
- `knowledge_base_indicator_layering.jsonl`

## Next Steps
1.  **IMMEDIATE:** Fix and Commit `kutato.py` and `kutato_ugynok_v3.py`.
2.  Continue development using the standardized tools.
