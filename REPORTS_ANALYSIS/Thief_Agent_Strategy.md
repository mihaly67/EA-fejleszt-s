# Thief Agent Strategy: "Robin Hood" Protocol

**Context:** Stealing from the Broker's Zero-Tolerance NN.
**Goal:** Consistent but "noisy" profit. Avoid detection by the Broker's anomaly detector.

## 1. The Adversary (Broker NN)
*   **Behavior:** Corners the player, enforces daily positive balance for the house.
*   **Trigger:** High Win Rate (>70%), rapid equity growth, consistent scalping patterns.
*   **Response:** Slippage, latency injection, stop hunting.

## 2. The Solution: Thief Reward Function
We must train a Reinforcement Learning agent (PPO/A2C) with a modified reward function that penalizes "perfection".

### Mathematical Logic
$$ R_{total} = R_{profit} - \lambda_{suspicion} \cdot P(Suspicion) $$

Where:
*   $R_{profit}$: Net profit of the trade.
*   $\lambda_{suspicion}$: Penalty weight for suspicious behavior.
*   $P(Suspicion)$: A calculated probability of being flagged.

### Suspicion Metrics
1.  **Win Streak Penalty:** If `ConsecutiveWins > 3`, the reward for the next win is reduced or negative.
    *   *Effect:* The agent learns to take a small loss after a streak to break the pattern.
2.  **Profit Velocity Cap:** If `DailyProfit > Target`, the agent stops trading or reduces position size to minimum.
3.  **Time Entropy:** Penalize entries that occur at exact intervals (e.g., every 5 minutes).

## 3. Implementation Plan (FinRL)
We will create a custom Gym Environment: `StockTradingEnvThief`.

```python
class StockTradingEnvThief(StockTradingEnv):
    def step(self, actions):
        # ... Execute trade ...

        # Calculate standard reward
        reward = self.account_value - self.prev_account_value

        # --- THIEF LOGIC ---
        # 1. Detect Win Streak
        if self.consecutive_wins > 3 and reward > 0:
            reward -= (reward * 2.0) # Penalize winning too much!

        # 2. Daily Cap
        if self.daily_profit > self.target_profit:
            reward = -100 # Force agent to stop for the day
            done = True

        return self.state, reward, done, {}
```

## 4. Operational Flow
1.  **MQL5 (SystemMonitor):** Checks safety.
2.  **MQL5 (BehavioralMimic):** Creates noise.
3.  **Python (Thief Agent):** Analyzes market data via ArcticDB.
4.  **Decision:** Agent decides to Buy/Sell/Hold based on the "Thief Reward" policy.
5.  **Execution:** MQL5 (UX_Controller) clicks the button.

This ensures we "steal" just enough to be profitable, but look "dumb" enough to be ignored by the Broker NN.
