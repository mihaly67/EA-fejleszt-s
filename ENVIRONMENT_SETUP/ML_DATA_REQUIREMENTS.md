# ML Data Requirements Report

## 1. FinRL (Reinforcement Learning Standard)
FinRL typically expects a standardized state space containing technical indicators.

**Covariance Matrix Usage (FinRL-master/finrl/meta/env_portfolio_allocation/env_portfolio.py):** Found references to covariance type features.

**State Initialization (FinRL-master/finrl/meta/env_stock_trading/env_stocktrading.py):**
```python
if self.initial:
            # For Initial State
            if len(self.df.tic.unique()) > 1:
                # for multiple stock
                state = (
                    [self.initial_amount]
                    + self.data.close.values.tolist()
                    + self.num_stock_shares
                    + sum(
                        (
                            self.data[tech].values.tolist()
                            for tech in self.tech_indicator_list
                        ...
```

## 2. Nautilus Trader (Event Engine)
Nautilus uses strict data structures for high-performance backtesting.

No specific slots/structure found for Nautilus.
