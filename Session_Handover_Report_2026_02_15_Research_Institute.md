# Session Handover Report: Research Institute (Kutatóintézet)

**Date:** 2026.02.15
**Focus:** Knowledge Retrieval & Search Architecture
**Status:** **Operational (JSONL + MQL5_DEV RAG)**

## Executive Summary
This session established the **Kutatóintézet (Research Institute)**, a scalable, hierarchical search system designed to mine "industrial" amounts of knowledge from both local JSONL libraries (`THIEFS`, `COLUMBO`) and the vector-based `MQL5_DEV` RAG database.

We solved the critical issue of "fragmented knowledge" in RAG: the system can now **reconstruct complete articles and codebases** from scattered vector chunks, making the knowledge base truly usable for development.

## Achievements

### 1. The Research Institute Architecture (`KUTATO_FEJLESZTES/KutatoIntezet`)
A tiered, batch-processing system designed to avoid recursion limits and memory overflows.
*   **Director (Level 0):** Initiates broad searches.
*   **Manager (Level 1):** Processes Director's findings, spawning specific research jobs.
*   **Worker (Level 2+):** Deep drills into specific technical topics.
*   **Smart Filtering:** Filters out noise keywords ("test", "file") to keep research focused on technical concepts.

### 2. RAG Context Reconstruction ("The Holy Grail")
*   **Problem:** RAG databases return fragmented "chunks" of text, often missing context or code.
*   **Solution:** `rag_adapter.py` detects metadata headers (e.g., `// CONTEXT: Series: ... Title: ...`) embedded in the chunks. It then queries the database to retrieve **all other chunks** sharing that same context.
*   **Result:** A single search hit for "indicator handle" now retrieves the **entire article** and its **full associated codebase** (zip content), reconstructed perfectly.

### 3. Unified Tooling
*   `kutato_intezet.py`: Orchestrates the hierarchy. Handles both JSONL (via subprocess `kutato.py`) and RAG (via `rag_adapter.py`).
*   `harvest_knowledge.py`: The "Refinery". Extracts code blocks and technical notes from raw search results into a clean Markdown report (`HARVESTED_KNOWLEDGE.md`).
*   `restore_envTC2.py`: Cleaned and optimized to fetch only necessary resources (`RAG_*`, `THIEFS`, `COLUMBO`).

## Validated Capabilities
*   **JSONL (THIEFS):** Successfully mapped stealth techniques (Jitter, Latency) from Hummingbot/NautilusTrader source codes.
*   **RAG (MQL5_DEV):** Successfully reconstructed full MQL4/MQL5 articles and libraries from the vector DB.

## Critical Next Steps (The Gap)
While `MQL5_DEV` (Articles + Code) works, the other two RAG databases are **untested** with the new reconstruction logic:
1.  **RAG_THEORY (MQL5 Book):** Likely PDF-based. Does it have `// CONTEXT:` headers?
2.  **RAG_CODE (Source Code):** Pure code repository. How are files linked?

**Next Session Task:**
*   **Analyze:** Inspect the structure of `RAG_THEORY` and `RAG_CODE` (vectorization logic).
*   **Adapt:** Modify `rag_adapter.py` to support the specific metadata/chunking format of these two databases.
*   **Integrate:** Add them as fully supported scopes to the Research Institute.

## Files
*   `KUTATO_FEJLESZTES/` - The new home for all research tools.
*   `KUTATO_FEJLESZTES/KutatoIntezet/` - The core engine (`kutato_intezet.py`, `rag_adapter.py`, `harvest_knowledge.py`).
