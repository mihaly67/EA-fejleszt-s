# Forensic Report: Merkava v1.02/v1.03 - "The Pulse & The Blind Eye"
**Date:** 2026.02.03 23:15
**Subject:** Analysis of "Wire" Deployment (Bad Data v1.02 & Better Data v1.03)
**Investigator:** Columbo (Jules)

## 🕵️‍♂️ Summary of the Case
"Sir, I've looked at the tapes. It's a bit of a mess, if you don't mind me saying. We have a 'Bad' tape (v1.02) and a 'Better' tape (v1.03). But here's the thing... both of them show one of our key witnesses - the Flow Indicator - was asleep at the wheel. Flatlined. 50.0. Didn't see a thing."

However, the **Pulse (Hybrid DFCurve)**... that one was wide awake. And what it saw during the high-stress moments matches your suspicion: the Broker is reacting, but maybe not how we thought.

## 1. The Evidence (Data Integrity)
*   **v1.02 (The Bad Tape):**
    *   **Chaos:** Massive PL swings (-187 to +960 in seconds). This confirms the PL column bug you reported. It's unreadable for financial auditing.
    *   **Blind Spot:** `Flow_MFI` is stuck at 50.0. `Flow_DDown` is stuck.
*   **v1.03 (The Better Tape):**
    *   **Clean-ish:** PL is smoother but still suspect in calculation logic.
    *   **Still Blind:** `Flow_MFI` is *still* stuck at 50.0. `Flow_DDown` is largely inactive.
    *   **Good News:** `Hybrid_DFCurve` (Pulse) and `Hybrid_MACD` are logging correctly.

**Verdict:** We cannot trust the Flow indicators in these logs. We *can* trust the Pulse and Velocity.

## 2. The Suspect's Pulse (Hybrid Analysis)
We asked: *"Does the Pulse see the Broker's hesitation?"*

*   **The Stress Test:** In v1.02, during high-velocity spikes (broker hunting?), the **Pulse (DFCurve)** shifted dramatically from a baseline of `-0.54` to `-2.92`.
*   **Interpretation:** The Pulse *felt* the velocity. It didn't just follow price (Correlation 0.10, very low). It reacted to the *structure* of the move.
*   **The Missing Witness:** Because Flow was flatlined, we couldn't confirm if liquidity was withdrawn before the spike. That's a missing piece of the puzzle.

## 3. The Crime Scene (Micro-Stalls)
In v1.03, we found **67 "Micro-Stall" events**.
*   **The MO:** High Velocity -> Sudden Drop in Velocity (Brakes slammed) -> Price Reversal.
*   **Example (22:33:53):**
    *   Velocity drops by **-10.47** (The Stall).
    *   Pulse reads **-1.77** (Confirming bearish pressure/structure).
    *   Price immediately drops **-1.30 points** in the next 10 ticks.
*   **Conclusion:** The "Micro-Stall" signature is real. The broker (or the market) slams the brakes before reversing. The Pulse sees this.

## 4. Broker Tactics
*   **Spread:** Stable at ~39 points. No massive widening detected in these short clips.
*   **The Hunting:** We didn't see explicit "Stop Hunting" via spread widening here, but the PL volatility in v1.02 suggests the broker might be slipping execution prices (slippage) rather than just widening the spread.

## 📝 Recommendations (The "Just One More Thing")
1.  **Fix the Flow:** The `Flow_MFI` logging is broken. It's critical for the "Hybrid" validation. We need to check `Mimic_Merkava_WIRE_GOLD` code to see why it's writing 50.0.
2.  **Fix the PL:** The PL duplication and calculation errors make PnL analysis impossible.
3.  **Trust the Pulse:** The Pulse (DFCurve) is a valid forensic tool. It reacts to stress. Keep it.

"Sir, we're getting close. If we can get that Flow indicator talking, we'll catch them red-handed."
