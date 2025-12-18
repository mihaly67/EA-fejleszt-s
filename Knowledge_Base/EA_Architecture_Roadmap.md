# Hybrid Scalper System - Architectural Roadmap

## 🎯 Overview
This document outlines the modular development path for the "Hybrid Scalper" system. The goal is to separate **Computation (Signal Engine)**, **Decision (Decision Core)**, and **Visualization (Dashboard)** to ensure maximum performance and maintainability.

## 🏗 Module 1: The Signal Engine ("The Sensors")
**Purpose:** Pure computational units. They calculate values and fill buffers. They have *zero* trade logic and *zero* complex GUI elements (beyond basic curves).
**Key Characteristic:** Optimized for speed (`prev_calculated`).

### Components:
1.  **Hybrid Momentum Indicator (v1.9+)**
    *   **Logic:** DEMA-smoothed Momentum with Gain Control + Tanh Normalization.
    *   **Responsibility:** Providing the primary "Conviction" signal [-1 to +1].
    *   **Optimization:** Incremental calculation (CPU efficient).
2.  **Volatility Filter (Adaptive Bands)**
    *   **Logic:** Keltner/Bollinger or Z-Score based volatility measurement.
    *   **Responsibility:** Detecting "Squeeze" vs "Expansion" states.
3.  **Trend Bias (HTF)**
    *   **Logic:** MTF Trend detection (Sandwich Architecture).
    *   **Responsibility:** Filtering trades against the major trend.

## 🧠 Module 2: The Decision Core ("The Brain")
**Purpose:** The Expert Advisor (EA). It consumes data from the Signal Engine and makes trading decisions.
**Key Characteristic:** State-Machine based execution.

### Components:
1.  **Signal Aggregator:**
    *   Reads `iCustom` buffers from the Signal Engine.
    *   Combines Momentum, Trend, and Volatility into a single "Trade Trigger".
2.  **Risk Manager:**
    *   Calculates Position Size based on Account Equity & Stop Loss distance.
    *   Enforces Max Drawdown limits.
3.  **Execution Engine:**
    *   Manages Orders (`OrderSendAsync`).
    *   Handles Retries and Slippage protection.
4.  **Trade Management:**
    *   Trailing Stops.
    *   Breakeven Logic.

## 🖥 Module 3: The Visual Assistant ("The Eyes")
**Purpose:** User feedback and monitoring.
**Key Characteristic:** Low-priority update frequency (doesn't block ticks).

### Components:
1.  **Info Dashboard (GUI):**
    *   **Technology:** `CAppDialog` (Standard Library).
    *   **Content:**
        *   Current Signal Conviction %.
        *   Open P/L.
        *   Active Spread & Volatility.
    *   **Implementation:** Can be an embedded part of the EA *or* a separate "Dashboard Indicator" that reads the same signals.
2.  **On-Chart Visuals:**
    *   Entry/Exit arrows (drawn by the EA or helper indicator).
    *   Trade History lines.

## 📅 Development Phases

### Phase 1: Engine Tuning (Current)
*   **Goal:** Perfect the `HybridMomentumIndicator`.
*   **Tasks:**
    *   Optimize DEMA loop (`prev_calculated`).
    *   Verify "Gain Control" for artifact reduction.
    *   Finalize Buffer structure for EA reading.

### Phase 2: The Prototype EA
*   **Goal:** A "Headless" EA that trades the signal.
*   **Tasks:**
    *   Build `Hybrid_Scalper_EA_v1.mq5`.
    *   Implement `iCustom` connection to the indicator.
    *   Basic Entry/Exit logic testing.

### Phase 3: The Cockpit (Dashboard)
*   **Goal:** User Interface for the trader.
*   **Tasks:**
    *   Implement `CAppDialog` panel.
    *   Connect panel to EA state.
