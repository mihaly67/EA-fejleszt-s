# Market Radar Specification (Intermarket Analysis)

## 1. Concept: The "Observer Network"
The EA is not isolated. It sends "Observers" to correlated markets to determine the global "Market Pulse" (Risk On/Off).

## 2. Core Components

### 2.1 The Observer (`CMarketObserver`)
A lightweight agent monitoring a single remote symbol.
- **Inputs:** Symbol Name (e.g., "US500", "XAUUSD").
- **Methods:**
    - `Update()`: Fetches latest Price and Daily Change %.
    - `GetTrend()`: Returns `TREND_UP` / `TREND_DOWN` (based on MA or Close > Open).
    - `GetVolatility()`: Returns ATR of the remote symbol.

### 2.2 Global Sentiment Aggregator (`CGlobalSentiment`)
Collects data from all Observers to output a "Global State".
- **Logic:**
    - **Risk On:** US500 Up AND DE40 Up AND Gold Down/Flat.
    - **Risk Off:** Gold Up AND Bonds (TLT) Up AND Stocks Down.
    - **Dollar Strength:** Aggregated from EURUSD, GBPUSD, USDJPY (Inverse DXY).

### 2.3 Asset Correlation Map
| Asset | Category | Correlation |
| :--- | :--- | :--- |
| **US500** | Risk | Positive with Risk On |
| **DE40** | Risk | Positive with US500 |
| **XAUUSD** | Haven | Inverse to Risk (usually) |
| **Brent** | Commodity | Correlated with CAD, Inflation |
| **US10Y** | Bond Yield | Inverse to Tech Stocks (often) |

## 3. Implementation Plan
### 3.1 Data Fetching
- Use `iClose(symbol, PERIOD_D1, 0)` for daily direction.
- Use `iATR` handle on remote symbol for volatility.
- *Critical:* Check `SymbolSelect(symbol, true)` in `OnInit` to ensure data availability.

### 3.2 Integration with Trading Assistant
- The `CTradingAssistant` queries `CGlobalSentiment`.
- **Rule:** If `GlobalState == RISK_OFF`, block "Aggressive Buy" on Risk Assets (Indices/Forex). Force "Conservative" or "Short Only".

## 4. Class Interface
```mql5
class CGlobalSentiment {
    CMarketObserver *m_us500;
    CMarketObserver *m_gold;
    CMarketObserver *m_oil;
public:
    double GetRiskScore(); // -100 (Risk Off) to +100 (Risk On)
    bool   IsDollarStrong();
};
```
