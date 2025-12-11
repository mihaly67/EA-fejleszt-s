# SYSTEM ARCHITECTURE & KNOWLEDGE BASE

**Version:** 1.0 (Consolidated)
**Date:** 2025
**Scope:** WPR Analyst EA & Infrastructure

## 1. Core Application: `WPR_Analyst_v4.3.mq5`
*   **Role:** The stable, production-grade Expert Advisor.
*   **Signal Logic:** Williams Percent Range (WPR) with Trend/Filter overlay (EMA/MACD).
*   **Execution Mode:**
    *   **Semi-Automatic:** Manual buttons on Panel (`Buy`, `Sell`, `Close`) with auto-risk calculation.
    *   **Automatic:** Signal-based entry (State Machine with Retry Logic).
*   **Critical Modules:**
    *   **Risk Manager (`RiskManager.mqh`):** Calculates Lot Size based on Margin % or Risk %. Enforces ATR-based or Point-based SL/TP.
    *   **Trading Panel (`TradingPanel.mqh` / Embedded):** GUI for manual control and status display.
    *   **Profit Maximizer (`ProfitMaximizer.mqh`):** Advanced exit logic (Trend Chasing, BreakEven, Smart Trailing).

## 2. Infrastructure & Environment
*   **Startup Script:** `restore_environment.py` (Python).
    *   **Function:** Automatically checks, downloads, and configures the RAG databases (`rag_theory`, `rag_code`, `rag_mql5_dev`) from Google Drive.
    *   **Optimization:** Loads `rag_theory` into RAM, keeps others on Disk (SQLite/MMAP) to save memory.
*   **Search Engine:** `kutato.py`.
    *   **Function:** Unified search tool used by Agents to query the RAG databases.
*   **Protocol:** `AGENTS.md`.
    *   **Mandate:** Strict, professional, verification-first behavior. No cynicism.

## 3. Future / Experimental Concepts
*   **Python Bridge (Concept):**
    *   **Goal:** Zero-Phase Filtering (DSP) using Python's `scipy` to remove lag from indicators (MACD/WPR).
    *   **Status:** Previous implementation ("Colombo") was rejected due to complexity/lag issues.
    *   **Direction:** Valid requirement for future, but requires a robust, low-latency implementation (likely Socket or optimized Shared File).
*   **Hybrid Indicators:**
    *   **Goal:** Combining multiple signals (Momentum + Trend + Volatility).
    *   **Lesson:** Avoid "chaotic" mathematical models (like unstable FRAMA). Prefer robust, standard indicators (WPR, Stoch) enhanced by DSP.

## 4. File Structure (Key Locations)
*   `/`: Root. Contains EA (`WPR_Analyst_v4.3.mq5`), Scripts (`restore_environment.py`, `kutato.py`), Protocol (`AGENTS.md`).
*   `Profit_Management/`: Design Specifications (`*.md`) and Logic Classes (`*.mqh`).
*   `Showcase_Indicators/`: Prototyping area for new indicators.
*   `rag_*/`: Knowledge Base directories (Ignored by Git).

---
*This document serves as the primary source of truth for the system architecture.*
