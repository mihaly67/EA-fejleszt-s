import pandas as pd
import numpy as np
import logging
import sys
import re

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
            initial_balance = self.df['Balance'].iloc[0]
            if initial_balance > 500000:
                self.currency = "HUF"
                logger.info(f"💰 Currency Detected: {self.currency} (Balance: {initial_balance:,.2f})")
            else:
                self.currency = "EUR"
                logger.info(f"💰 Currency Detected: {self.currency}")

            logger.info(f"📄 Evidence Size: {len(self.df)} ticks")

        except Exception as e:
            logger.error(f"❌ Failed to load evidence: {e}")
            sys.exit(1)

    def parse_sltp_levels(self, row):
        """Parses the SLTP_Levels string into active SL/TP prices."""
        # Format Example: "B:123.45|S:234.56|..." or similar.
        # Actual format from previous logs: "B_SL:xxx|B_TP:xxx|..."
        # If the column is just "NONE", return None
        if pd.isna(row['SLTP_Levels']) or str(row['SLTP_Levels']) == "NONE":
            return None, None

        # Simple extraction of average SL and TP for active positions
        # This is an approximation if there are multiple positions.
        # Let's try to extract numbers using regex relative to Price

        # NOTE: Since the format varies, we look for numeric values.
        # But a more robust way is to detect CHANGES in the string.
        # For the "Direction" analysis, we need to know if SL moved CLOSER or FURTHER.
        # We can use the 'ActiveSL' and 'ActiveTP' columns if they exist (added in v2.15).

        sl = row.get('ActiveSL', 0.0)
        tp = row.get('ActiveTP', 0.0)

        return sl, tp

    def analyze_causality_price_action(self):
        """
        New Hypothesis:
        1. Moving TP AWAY -> Price Moves TOWARDS Trade (Momentum/Chase).
        2. Moving SL CLOSER -> Price Moves TOWARDS SL (Hunt).
        """
        logger.info("\n🕵️ STARTING CAUSAL INFERENCE: Price Action & Manual Levels")

        # Check if ActiveSL/ActiveTP columns exist, otherwise fallback to parsing
        if 'ActiveSL' not in self.df.columns:
            logger.warning("   ⚠️ ActiveSL/ActiveTP columns missing. Attempting to infer from SLTP_Levels...")
            # For now, we rely on SLTP_Levels change detection as a proxy for "Manual Intervention"
            pass

        # 1. Detect Interventions (SL or TP Change)
        self.df['SLTP_Changed'] = self.df['SLTP_Levels'] != self.df['SLTP_Levels'].shift(1)

        # Filter for active positions
        intervention_indices = self.df[self.df['SLTP_Changed'] & (self.df['PosCount'] > 0)].index

        if len(intervention_indices) == 0:
            logger.warning("   ⚠️ No manual level adjustments found.")
            return

        logger.info(f"   🧪 Analyzing {len(intervention_indices)} manual interventions...")

        results = []

        for idx in intervention_indices:
            # Look at previous tick (pre-move) and current tick (post-move)
            # Actually, the 'Change' happens AT this tick.

            # Context
            current_price = self.df.loc[idx, 'Bar_Close']

            # Determine logic: Did SL move Closer or Further?
            # Since we don't have easy parsed values, we look at the PRICE REACTION directly.

            # Lookahead: What did price do in next 20 ticks?
            # 20 ticks approx 10-20 seconds.
            future_idx = min(idx + 20, len(self.df) - 1)
            future_price = self.df.loc[future_idx, 'Bar_Close']

            price_delta = future_price - current_price

            # Correlation with Trade Direction
            # We need to know if we are Long or Short.
            # 'LotDir' might help: "BUY", "SELL", "HEDGE".
            lot_dir = self.df.loc[idx, 'LotDir']

            # Directional Move: Did price move in favor (Profit) or against (Loss)?
            # For BUY: +Delta is Good. For SELL: -Delta is Good.

            is_favorable = False
            if "BUY" in str(lot_dir) and price_delta > 0: is_favorable = True
            elif "SELL" in str(lot_dir) and price_delta < 0: is_favorable = True

            results.append({
                'idx': idx,
                'LotDir': lot_dir,
                'Price_Delta': price_delta,
                'Is_Favorable': is_favorable,
                'Velocity': self.df.loc[idx, 'Velocity']
            })

        # Aggregate Results
        res_df = pd.DataFrame(results)
        favorable_rate = res_df['Is_Favorable'].mean() * 100

        logger.info(f"   📊 Price Reaction Statistics:")
        logger.info(f"      - Total Interventions: {len(res_df)}")
        logger.info(f"      - Price moved FAVORABLY (Towards Profit): {favorable_rate:.1f}%")
        logger.info(f"      - Price moved ADVERSELY (Towards Loss/SL): {100 - favorable_rate:.1f}%")

        if favorable_rate > 55:
            logger.info("   ✅ HYPOTHESIS SUPPORTED: Adjusting levels (TP away?) tends to 'release' price towards profit.")
        elif favorable_rate < 45:
             logger.info("   ⚠️ WARNING: Adjusting levels tends to attract price towards the bad side (SL Hunt).")
        else:
            logger.info("   🤷 INCONCLUSIVE: Price reaction is random (50/50).")

        # Additional Check: Velocity Spike?
        avg_velocity = self.df['Velocity'].mean()
        avg_velocity_post_move = res_df['Velocity'].mean() # This is velocity AT the move.
        # We need velocity AFTER the move.

        # Calculate velocity impact
        logger.info(f"      - Avg Market Velocity: {avg_velocity:.2f}")
        logger.info(f"      - Avg Velocity during Intervention: {avg_velocity_post_move:.2f}")

        if avg_velocity_post_move > avg_velocity * 1.2:
             logger.info("   🚀 DETECTED: Manual adjustments TRIGGER volatility spikes (Market reacts to input).")

    def run(self):
        self.load_evidence()
        self.analyze_causality_price_action()
        # self.analyze_game_theory_phases() # Skip for now to focus on Price Action
        logger.info("\n🏁 Analysis Complete. The case is closed.")

if __name__ == "__main__":
    CSV_FILE = "Mimic_Research_GOLD_20260202_141322.csv"
    engine = ColomboForensicEngine(CSV_FILE)
    engine.run()
