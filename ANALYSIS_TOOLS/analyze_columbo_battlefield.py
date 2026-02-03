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
            # Handle duplicates or missing Balance
            if 'Balance' in self.df.columns and not self.df['Balance'].dropna().empty:
                 initial_balance = self.df['Balance'].iloc[0]
                 if initial_balance > 500000:
                    self.currency = "HUF"
                    logger.info(f"💰 Currency Detected: {self.currency} (Balance: {initial_balance:,.2f})")
                 else:
                    self.currency = "EUR"
                    logger.info(f"💰 Currency Detected: {self.currency}")
            else:
                 logger.warning("⚠️ Balance column missing or empty.")

            logger.info(f"📄 Evidence Size: {len(self.df)} ticks")

        except Exception as e:
            logger.error(f"❌ Failed to load evidence: {e}")
            sys.exit(1)

    def parse_sltp_levels_v3(self, levels_str, current_price):
        """
        Parses active format: "B:SL/TP|S:SL/TP|..."
        """
        if pd.isna(levels_str) or levels_str == "NONE":
            return None

        distances = []
        parts = str(levels_str).split('|')
        for part in parts:
            if ':' not in part or '/' not in part: continue

            values = part.split(':')[1]
            try:
                sl_str, tp_str = values.split('/')
                sl = float(sl_str)
                if sl < 0.1: continue
                dist = abs(current_price - sl)
                distances.append(dist)
            except:
                continue

        if not distances:
            return None

        return min(distances)

    def analyze_distance_sensitivity(self):
        """
        Analyzes "Reaction vs Distance".
        """
        logger.info("\n📏 STARTING SENSITIVITY ANALYSIS: Distance vs Reaction")

        if 'SLTP_Levels' not in self.df.columns:
             logger.error("❌ 'SLTP_Levels' column missing.")
             return

        self.df['SLTP_Changed'] = self.df['SLTP_Levels'] != self.df['SLTP_Levels'].shift(1)

        intervention_indices = self.df[self.df['SLTP_Changed'] & (self.df['PosCount'] > 0)].index

        data_points = []

        for idx in intervention_indices:
            current_price = self.df.loc[idx, 'Bar_Close']
            levels_str = self.df.loc[idx, 'SLTP_Levels']

            distance = self.parse_sltp_levels_v3(levels_str, current_price)
            if distance is None: continue

            # Check Reaction (Stall)
            immediate_slice = self.df.iloc[idx:min(idx+10, len(self.df))]
            avg_vel_immediate = immediate_slice['Velocity'].mean()
            avg_vel_global = self.df['Velocity'].mean()
            reaction_ratio = avg_vel_immediate / avg_vel_global if avg_vel_global > 0 else 1.0

            # Check Outcome (Kill)
            lookahead_window = 120
            future_slice = self.df.iloc[idx:min(idx+lookahead_window, len(self.df))]
            pos_drop = (future_slice['PosCount'] < future_slice['PosCount'].shift(1)).any()

            data_points.append({
                'Distance': distance,
                'Reaction_Ratio': reaction_ratio,
                'Is_Killed': pos_drop
            })

        if not data_points:
            logger.warning("   ⚠️ No valid distance data points found (No manual SL moves while in position).")
            return

        res_df = pd.DataFrame(data_points)

        # Extended Bins for Deep Analysis
        bins = [0, 40, 50, 60, 100, 200, 500, 2000]
        labels = ['0-40', '40-50', '50-60', '60-100', '100-200', '200-500', '500+']
        res_df['Dist_Bin'] = pd.cut(res_df['Distance'], bins=bins, labels=labels)

        logger.info(f"   📊 Analysis of {len(res_df)} Manual Adjustments:")

        summary = res_df.groupby('Dist_Bin', observed=False).agg(
            Count=('Distance', 'count'),
            Avg_Reaction=('Reaction_Ratio', 'mean'),
            Kill_Rate=('Is_Killed', 'mean')
        )

        print("\n   --- SENSITIVITY TABLE (Extended) ---")
        print(summary.to_string())
        print("   ------------------------------------")

        # Calculate Average User Placement
        avg_placement = res_df['Distance'].mean()
        logger.info(f"   📍 Your Average Placement Distance: {avg_placement:.2f} points")

    def analyze_spread_zone(self):
        """
        Investigate the '50' zone relative to actual spread.
        """
        logger.info("\n🌊 ANALYZING THE SPREAD ZONE")

        # Calculate Average Spread
        avg_spread = self.df['Spread'].mean()
        logger.info(f"   ℹ️ Average Market Spread: {avg_spread:.2f} points")


    def run(self):
        self.load_evidence()
        self.analyze_distance_sensitivity()
        self.analyze_spread_zone()
        logger.info("\n🏁 Analysis Complete.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_columbo_battlefield.py <csv_file>")
    else:
        CSV_FILE = sys.argv[1]
        engine = ColomboForensicEngine(CSV_FILE)
        engine.run()
