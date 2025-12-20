# Python Chart Generator & Analysis

This directory contains the Python-based analysis charts comparing different scalping indicator algorithms.

## Overview

The `generate_charts.py` script reads M1 data from `Showcase_Indicators/` and generates visual comparisons of:
1.  **Legacy Logic:** The current MQL5 implementation (DEMA + Phase Advance + Tanh). Known to be noisy.
2.  **Candidate 1 (ZLEMA):** Zero-Lag EMA based MACD. Attempts to reduce lag without noise.
3.  **Candidate 2 (VWMA):** Volume Weighted Moving Average based MACD. Attempts to filter low-volume noise.

## How to Run

1.  Ensure you have Python 3 installed.
2.  Install dependencies:
    ```bash
    pip install pandas matplotlib
    ```
3.  Run the script:
    ```bash
    python3 generate_charts.py
    ```
4.  The charts are saved in this directory (`py_chart_csart/`) as `.png` files.

## Adding New Indicators

To test a new algorithm:
1.  Open `generate_charts.py`.
2.  Navigate to the `INDICATOR LOGIC SECTION`.
3.  Create a new function (e.g., `def candidate_my_logic(df, ...):`).
4.  Add a new subplot in the `generate_chart` function to visualize your new logic.

## Purpose

These charts serve as the empirical basis for the "Clean Slate" rebuild of the main MQL5 Momentum Indicator. The goal is to visually verify "noise reduction" before writing MQL5 code.
