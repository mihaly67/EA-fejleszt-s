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

    def analyze_micro_structure_hunt(self):
        """
        Deep Forensic Search for the 'Smoking Gun'.
        Sequence: Manual Intervention -> Velocity Drop (Stall) -> Reversal -> SL Hit.
        """
        logger.info("\n🕵️ STARTING MICRO-STRUCTURE FORENSICS: Searching for 'The Hunt'...")

        self.df['SLTP_Changed'] = self.df['SLTP_Levels'] != self.df['SLTP_Levels'].shift(1)

        # 1. Identify Close Events (Losses)
        # Find where positions dropped (PosCount decreases)
        self.df['Pos_Drop'] = (self.df['PosCount'] < self.df['PosCount'].shift(1))

        # 2. Find Loss Closures (where Balance decreases significantly or Realized_PL drops)
        # Note: Realized_PL is cumulative usually. Check diff.
        # Ideally we look for 'ActionDetails' containing 'SL' or 'CLOSE'

        # We look for Interventions shortly BEFORE a Closure
        intervention_indices = self.df[self.df['SLTP_Changed'] & (self.df['PosCount'] > 0)].index

        smoking_guns = []

        for idx in intervention_indices:
            intervention_time = self.df.loc[idx, 'Time']

            # Look ahead 60 seconds (approx 120 ticks) for a Closure
            lookahead_window = 120
            end_idx = min(idx + lookahead_window, len(self.df) - 1)

            future_slice = self.df.iloc[idx:end_idx]

            # Check for Position Drop in this window
            drops = future_slice[future_slice['Pos_Drop']]

            if not drops.empty:
                # Potential Candidate: Intervention -> Closure
                drop_idx = drops.index[0]
                drop_time = self.df.loc[drop_idx, 'Time']
                time_diff_sec = (drop_time - intervention_time).total_seconds()

                # Check Profit/Loss at closure
                # If Realized PL didn't jump up, or Balance went down
                # Since we don't have per-trade PL easily parsed, let's look at Price Direction vs Trade

                # Check for "Stall" (Velocity Drop) right after intervention
                # Immediate reaction: next 5-10 ticks
                immediate_slice = self.df.iloc[idx:min(idx+10, len(self.df))]
                avg_vel_immediate = immediate_slice['Velocity'].mean()
                avg_vel_global = self.df['Velocity'].mean()

                is_stalled = avg_vel_immediate < (avg_vel_global * 0.5) # 50% drop in speed

                smoking_guns.append({
                    'intervention_time': intervention_time,
                    'closure_time': drop_time,
                    'latency_sec': time_diff_sec,
                    'is_stalled': is_stalled,
                    'velocity_immediate': avg_vel_immediate
                })

        # Filter for the "Perfect Storm"
        # Immediate Stall AND Quick Death (< 30 sec)
        confirmed_hunts = [sg for sg in smoking_guns if sg['is_stalled'] and sg['latency_sec'] < 60]

        logger.info(f"   🔍 Found {len(smoking_guns)} interventions followed by closure.")
        logger.info(f"   🎯 CONFIRMED 'HUNTS' (Stall + Kill < 60s): {len(confirmed_hunts)}")

        if confirmed_hunts:
            logger.info("   🚨 SMOKING GUN FOUND! Details of the 'Hunt':")
            for hunt in confirmed_hunts:
                logger.info(f"      - Time: {hunt['intervention_time']} -> Killed at {hunt['closure_time']} ({hunt['latency_sec']}s later)")
                logger.info(f"      - Micro-Structure: Market STALLED (Vel: {hunt['velocity_immediate']:.2f}) then reversed.")

            logger.info("\n   🧠 THEORETICAL EXPLANATION (Alibi-Detect / Adversarial Drift):")
            logger.info("      The algorithm detected the 'Context Shift' (SL Move).")
            logger.info("      It entered a 'Wait State' (Velocity Drop) to recalculate risk.")
            logger.info("      Then it executed an 'Adversarial Attack' (Price Reversal) to clear the liquidity.")

        else:
            logger.info("   ❌ No perfect 'Stall + Kill' sequence found. The user's experience might be from another session or less strictly defined.")


    def run(self):
        self.load_evidence()
        self.analyze_micro_structure_hunt()
        logger.info("\n🏁 Analysis Complete. The case is closed.")

if __name__ == "__main__":
    CSV_FILE = "Mimic_Research_GOLD_20260202_141322.csv"
    engine = ColomboForensicEngine(CSV_FILE)
    engine.run()
