# Last Session Handover (Environment Unified)

## 1. System Status
- **Infrastructure:** **UNIFIED & STABLE.**
    - All startup scripts (`setup_rag.sh`, `jules_env_*`) are replaced by `restore_environment.py`.
    - RAG configuration: Theory (RAM), Code/MQL5 (Disk).
    - Search: `kutato.py` updated to support this architecture.
- **Implemented Features:**
    - Environment Restoration (One-Click).
    - `ProfitMaximizer`, `RiskManager`, `TradingPanel` (from previous sessions).

## 2. Next Session Goals
**Primary Focus:** **Hybrid Indicators** (Indikátorok vizsgálata).
- **Task:** Create `Super_MACD_Showcase.mq5` using FRAMA (Fractal Adaptive Moving Average) or ZeroLag logic.
- **Workflow:** Run `python3 restore_environment.py` -> Research FRAMA -> Implement Showcase -> Verify.

## 3. Critical Instructions
- **STARTUP COMMAND:** `python3 restore_environment.py`
- Do not use old scripts.
