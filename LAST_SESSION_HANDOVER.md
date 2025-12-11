# Last Session Handover (Ready for Colombo)

## 1. System Status
- **Infrastructure:** **UNIFIED.** (`restore_environment.py` is the single startup script).
- **New Tools (Committed):**
    - `Lag_Tester_MACD.mq5`: Visualizer for comparing M1 vs MTF MACD lag.
    - `Colombo_MACD_MTF.mq5`: Data exporter for Python.
    - `colombo_filter.py`: Python script for Zero-Phase filtering (Savitzky-Golay).
    - `Super_MACD_Showcase.mq5` (v1.20): Fixed FRAMA logic + DEMA Signal.
    - `kutato_ugynok_v3.py`: Deep Recursive Researcher.

## 2. Research Findings (Article 18033)
- Investigated "MQL5 Wizard + White-Noise Kernel".
- **Verdict:** Uses DeMarker + Envelopes with Machine Learning. Powerful but complex.
- **Decision:** Stick to **Colombo (Python DSP)** first. If MACD fails, we swap the input to **DeMarker** using the same Python pipeline.

## 3. Next Session Goals
**Primary Focus:** **Execute "Colombo" Project.**
1.  **Run `restore_environment.py`.**
2.  **Verify Lag:** Run `Lag_Tester_MACD.mq5` on M1 chart.
3.  **Activate Python:** Run `colombo_filter.py` alongside `Colombo_MACD_MTF.mq5` to test the loop.

## 4. Critical Instructions
- **STARTUP COMMAND:** `python3 restore_environment.py`
