# Hybrid Scalper System - Architectural Roadmap

## 🎯 Overview
This document outlines the modular development path for the "Hybrid Scalper" system. The goal is to separate **Computation (Signal Engine)**, **Decision (Decision Core)**, and **Visualization (Dashboard)** to ensure maximum performance and maintainability.

## 🏗 Module 1: The Signal Engine ("The Sensors")
**Purpose:** Pure computational units. They calculate values and fill buffers. They have *zero* trade logic.
**Key Characteristic:** Optimized for speed (`prev_calculated`).

### 1. Hybrid Momentum (v1.9+) - "The Trigger"
*   **Logic:** DEMA-smoothed Momentum with Gain Control + Tanh Normalization.
*   **Responsibility:** Providing the primary "Conviction" signal [-1 to +1] for exact entry timing.

### 2. Hybrid Context (v1.1+) - "The Map"
*   **Logic:** Multi-Layer Environment Analysis.
*   **Features:**
    *   **Auto Pivot Points:** Daily/Weekly levels.
    *   **Auto Fibonacci:** ZigZag-based retracements.
    *   **Trend Filter:** EMA 50/150 Cloud.
*   **Responsibility:** Defining the "Playing Field" (Support/Resistance, Trend Bias).

### 3. Hybrid Institutional (v1.0+) - "The Big Players"
*   **Logic:** VWAP + KAMA.
*   **Features:**
    *   **VWAP:** Intraday Volume Weighted Average Price (The "Fair Value").
    *   **KAMA:** Adaptive Moving Average (The "Smart Trend").
*   **Responsibility:** Aligning trades with institutional flow.

### 4. Hybrid Volatility (v1.0+) - "The Fuel"
*   **Logic:** Bollinger Bands + Keltner Channels (TTM Squeeze).
*   **Features:**
    *   **Squeeze Detection:** BB inside Keltner = Potential Breakout.
*   **Responsibility:** Filtering out low-volatility noise and catching explosions.

## 🧠 Module 2: The Decision Core ("The Brain")
**Purpose:** The Expert Advisor (EA). It consumes data from the Signal Engine and makes trading decisions.
**Key Characteristic:** State-Machine based execution.

### Components:
1.  **Signal Aggregator:**
    *   Reads `iCustom` buffers from all 4 indicators.
    *   **Logic:**
        *   **LONG Condition:** Momentum > Threshold AND Price > VWAP AND Volatility != Squeeze AND Price > EMA 150.
2.  **Risk Manager:**
    *   Calculates Position Size based on Account Equity & Stop Loss distance.
3.  **Execution Engine:**
    *   Manages Orders (`OrderSendAsync`).

## 🖥 Module 3: The Visual Assistant ("The Eyes")
**Purpose:** User feedback and monitoring.
**Key Characteristic:** Low-priority update frequency.

### Components:
1.  **Info Dashboard (GUI):**
    *   **Technology:** `CAppDialog` (Standard Library).
    *   **Content:**
        *   Signal Conviction %.
        *   Current Squeeze Status.
        *   Distance to VWAP/Pivots.
