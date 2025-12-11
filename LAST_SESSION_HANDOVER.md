# Last Session Handover (Lag Tester & Colombo Plan)

## 1. System Status
- **Infrastructure:** **UNIFIED.** (`restore_environment.py` is the single startup script).
- **New Tools:**
    - `Lag_Tester_MACD.mq5`: Visual comparison of M1 vs MTF MACD lag.
    - `Colombo_MACD_MTF.mq5`: Data exporter for Python.
    - `colombo_filter.py`: Python DSP script (Savitzky-Golay) for Zero-Phase filtering.

## 2. Next Session Goals
**Primary Focus:** **Execute "Colombo" Project.**
1.  **Run `restore_environment.py`.**
2.  **Verify Lag:** Run `Lag_Tester_MACD.mq5` on M1 chart to see the lag visually.
3.  **Activate Python:** Run `colombo_filter.py` alongside `Colombo_MACD_MTF.mq5` to test the loop (MQL->CSV->Py->CSV->MQL).

## 3. Critical Instructions
- **STARTUP COMMAND:** `python3 restore_environment.py`
