# Hybrid Scalper System - Architectural Roadmap

## 🎯 Overview
This document outlines the modular development path for the "Hybrid Scalper" system. The goal is to separate **Computation (Signal Engine)**, **Decision (Decision Core)**, and **Visualization (Dashboard)** to ensure maximum performance and maintainability.

## 🏗 Module 1: The Signal Engine ("The Sensors")
**Purpose:** Pure computational units. They calculate values and fill buffers. They have *zero* trade logic.
**Key Characteristic:** Optimized for speed (`prev_calculated`).

### 1. Hybrid Momentum (v1.9+) - "The Trigger"
*   **Logic:** DEMA-smoothed Momentum with Gain Control + Tanh Normalization.
*   **Responsibility:** Providing the primary "Conviction" signal [-1 to +1] for exact entry timing.
*   **Optimization:** Incremental calculation (CPU efficient).

### 2. Hybrid Context (v1.0+) - "The Map"
*   **Logic:** Multi-Layer Environment Analysis.
*   **Features:**
    *   **Auto Pivot Points:** Daily/Weekly levels.
    *   **Auto Fibonacci:** ZigZag-based retracements.
    *   **Trend Filter:** EMA 50/150 Cloud.
*   **Responsibility:** Defining the "Playing Field" (Support/Resistance, Trend Bias).

### 3. Volatility & Flow (Future) - "The Fuel"
*   **Logic:** WVF, Spread Delta, VROC.
*   **Responsibility:** Detecting "Squeeze" states and Volume flow.

## 🧠 Module 2: The Decision Core ("The Brain")
**Purpose:** The Expert Advisor (EA). It consumes data from the Signal Engine and makes trading decisions.
**Key Characteristic:** State-Machine based execution.

### Components:
1.  **Signal Aggregator:**
    *   Reads `iCustom` buffers from Momentum & Context.
    *   Combines Momentum (Trigger) + Context (Filter) + Volatility (Gate).
    *   *Example:* "Momentum BUY" is only valid if "Price > EMA 150" AND "Price > Daily Pivot".
2.  **Risk Manager:**
    *   Calculates Position Size based on Account Equity & Stop Loss distance.
    *   Enforces Max Drawdown limits.
3.  **Execution Engine:**
    *   Manages Orders (`OrderSendAsync`).
    *   Handles Retries and Slippage protection.

## 🖥 Module 3: The Visual Assistant ("The Eyes")
**Purpose:** User feedback and monitoring.
**Key Characteristic:** Low-priority update frequency.

### Components:
1.  **Info Dashboard (GUI):**
    *   **Technology:** `CAppDialog` (Standard Library).
    *   **Content:**
        *   Signal Conviction %.
        *   Distance to next Pivot/Fibo level.
        *   Active Spread & Volatility.
2.  **On-Chart Visuals:**
    *   Entry/Exit arrows (drawn by the EA).
    *   Trade History lines.

## 📅 Development Phases

### Phase 1: Engine Building (Current)
*   **Goal:** Perfect the Indicators.
*   **Status:**
    *   `HybridMomentum` (v1.9): **READY** (Optimized).
    *   `HybridContext` (v1.0): **READY** (Basic Levels).

### Phase 2: The Prototype EA
*   **Goal:** A "Headless" EA that trades the signals.
*   **Tasks:**
    *   Build `Hybrid_Scalper_EA_v1.mq5`.
    *   Implement `iCustom` connection to both indicators.
    *   Basic Entry/Exit logic testing.

### Phase 3: The Cockpit (Dashboard)
*   **Goal:** User Interface for the trader.
*   **Tasks:**
    *   Implement `CAppDialog` panel.
    *   Connect panel to EA state.
