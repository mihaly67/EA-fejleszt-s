import pandas as pd
import numpy as np
import logging
import sys

# Configure Logging (Colombo Style)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - COLUMBO - %(message)s')
logger = logging.getLogger("ColomboForensics")

class ColomboForensicEngine:
    def __init__(self, csv_file):
        self.csv_file = csv_file
        self.df = None
        self.currency = "EUR" # Default
        self.huf_rate = 1.0

    def load_evidence(self):
        """Loads the CSV and performs initial inspection."""
        logger.info(f"🔎 Loading evidence from {self.csv_file}...")
        try:
            self.df = pd.read_csv(self.csv_file)
            self.df['Time'] = pd.to_datetime(self.df['Time'])

            # 1. Currency Detection
            # If Balance > 500,000, it's likely HUF.
            initial_balance = self.df['Balance'].iloc[0]
            if initial_balance > 500000:
                self.currency = "HUF"
                logger.info(f"💰 Currency Detected: {self.currency} (Balance: {initial_balance:,.2f})")

                # Conversion Rate assumption (approximate for display if needed, but we stick to native)
                # But user might want EUR equivalents for the report?
                # Let's keep native for precision, but mention EUR roughly.
            else:
                self.currency = "EUR"
                logger.info(f"💰 Currency Detected: {self.currency}")

            logger.info(f"📄 Evidence Size: {len(self.df)} ticks")

        except Exception as e:
            logger.error(f"❌ Failed to load evidence: {e}")
            sys.exit(1)

    def analyze_causality_bait(self):
        """
        DoWhy-inspired Causal Analysis:
        Model: T (Bait/SL Move) -> Y (Spread/Volatility) | Confounder (Market Impact)
        """
        logger.info("\n🕵️ STARTING CAUSAL INFERENCE: The 'Bait' Hypothesis")
        logger.info("   Hypothesis: Moving SL (Bait) causes the Broker to relax (Spread Drop).")

        # 1. Define Treatment (T)
        # Change in SLTP_Levels column implies a "Move"
        # We need to detect when SLTP_Levels changes from previous tick
        self.df['SLTP_Changed'] = self.df['SLTP_Levels'] != self.df['SLTP_Levels'].shift(1)

        # Treatment Group: Ticks where SL Changed (and positions existed)
        treatment_indices = self.df[self.df['SLTP_Changed'] & (self.df['PosCount'] > 0)].index

        if len(treatment_indices) == 0:
            logger.warning("   ⚠️ No 'Bait' events found (SL Moves). Hypothesis cannot be tested.")
            return

        logger.info(f"   🧪 Identified {len(treatment_indices)} 'Bait' events (Interventions).")

        # 2. Define Outcome (Y)
        # Change in Spread over next N ticks (e.g., 10 ticks ~ 5-10 seconds)
        LOOKAHEAD = 10
        self.df['Spread_Future'] = self.df['Spread'].shift(-LOOKAHEAD)
        self.df['Spread_Delta'] = self.df['Spread_Future'] - self.df['Spread']

        # 3. Estimate Effect (Naive)
        # Compare Delta in Treatment vs Control (No SL Change)
        # Control: Random sample of ticks with active positions but NO SL change
        control_pool = self.df[(~self.df['SLTP_Changed']) & (self.df['PosCount'] > 0)]

        # Simple Matching (Propensity approx): Match by similar Volatility (BidVol)
        # Ideally we'd use a KDTree or Propensity Score, but for this "Tool Creation" we use mean comparison

        avg_effect_treatment = self.df.loc[treatment_indices, 'Spread_Delta'].mean()
        avg_effect_control = control_pool['Spread_Delta'].mean()

        causal_impact = avg_effect_treatment - avg_effect_control

        logger.info(f"   📊 Results:")
        logger.info(f"      - Average Spread Change after BAIT: {avg_effect_treatment:+.4f} pts")
        logger.info(f"      - Average Spread Change (Baseline): {avg_effect_control:+.4f} pts")
        logger.info(f"      - Causal Impact (ATT): {causal_impact:+.4f} pts")

        if causal_impact < 0:
            logger.info("   ✅ CONFIRMED: Baiting causes Spread to DROP (Broker relaxes).")
        else:
            logger.info("   ❌ REJECTED: Baiting does not reduce Spread (or Broker ignores it).")

    def analyze_game_theory_phases(self):
        """
        OpenSpiel-inspired Game Analysis.
        Segments the session into phases based on Floating PL and Exposure.
        """
        logger.info("\n♟️ GAME THEORY ANALYSIS: Session Phases")

        # Normalize Metrics
        max_dd = self.df['Floating_PL'].min()
        max_profit = self.df['Floating_PL'].max()

        # Heuristic Phase Detection
        # Opening: First 10%
        # Middle: High Exposure (PosCount > 3) or Deep DD
        # Endgame: Recovery or Liquidation

        self.df['Phase_Class'] = 'Opening'
        mid_idx = int(len(self.df) * 0.1)
        self.df.loc[mid_idx:, 'Phase_Class'] = 'Middle'

        # Endgame starts when positions drop to 0 after being high
        # Find last block of non-zero positions
        last_pos_idx = self.df[self.df['PosCount'] > 0].last_valid_index()
        if last_pos_idx:
            self.df.loc[last_pos_idx:, 'Phase_Class'] = 'Endgame'

        # Analyze each phase
        for phase in ['Opening', 'Middle', 'Endgame']:
            subset = self.df[self.df['Phase_Class'] == phase]
            if subset.empty: continue

            avg_spread = subset['Spread'].mean()
            volatility = subset['Velocity'].mean()
            profit = subset['Session_PL'].iloc[-1] - subset['Session_PL'].iloc[0]

            logger.info(f"   📍 {phase} Phase:")
            logger.info(f"      - Duration: {len(subset)} ticks")
            logger.info(f"      - Broker Aggression (Spread): {avg_spread:.2f}")
            logger.info(f"      - Market Energy (Velocity): {volatility:.2f}")
            logger.info(f"      - Net Profit: {profit:,.2f} {self.currency}")

    def run(self):
        self.load_evidence()
        self.analyze_causality_bait()
        self.analyze_game_theory_phases()
        logger.info("\n🏁 Analysis Complete. The case is closed.")

if __name__ == "__main__":
    # Assuming extracted CSV name
    CSV_FILE = "Mimic_Research_GOLD_20260202_141322.csv"
    engine = ColomboForensicEngine(CSV_FILE)
    engine.run()
