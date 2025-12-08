# MQL5 Cookbook Patterns & Best Practices

## 1. Object-Oriented Dashboard (The "Controls" Way)
Based on Articles 16084 ("Interactive MQL5 Dashboard") and 19059 ("Enhanced Informational Dashboard").

### Pattern: `CAppDialog` Inheritance
Instead of raw `ObjectCreate` calls, use the Standard Library's `CAppDialog`.
```mql5
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>

class CTradingPanel : public CAppDialog {
private:
    CLabel m_lbl_regime;
    // ...
public:
    virtual bool Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);
    // ...
};
```

### Pattern: Layout Constants
Define layout geometry in macros to avoid magic numbers.
```mql5
#define PANEL_WIDTH 300
#define PANEL_HEIGHT 200
#define ROW_HEIGHT 25
```

## 2. Tick Data Management ("DoEasy" Style)
Based on Article 11260 and 8912.

### Pattern: Tick Collection Class
Don't just store an array of MqlTick. Create a class that manages the buffer and calculations.
```mql5
class CTickSeries {
private:
    MqlTick m_buffer[];
    int m_size;
    // Welford's variables
    double m_mean;
    double m_sq_diff_sum;
public:
    void AddTick(const MqlTick &tick);
    double GetStandardDeviation();
};
```
*Note: This perfectly aligns with our `Tick_Risk_Model.md`.*

## 3. Custom Indicator Classes
Standard "Cookbook" approach for encapsulating indicator logic.
- **Initialize:** In constructor or `Init` method.
- **Calculate:** `OnCalculate` style method (accepting `rates_total`, `prev_calculated`).
- **Access:** `GetData(index)` method.

## 4. Conclusion for Hybrid System
We will adopt the **CAppDialog** pattern for the `TradingPanel` and the **Collection Class** pattern for `TickVolatility`. This ensures the code is professional, maintainable, and "MQL5-native".
