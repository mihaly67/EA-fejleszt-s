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

    def parse_sltp_levels_v3(self, levels_str, current_price):
        """
        Parses active format: "B:SL/TP|S:SL/TP|..."
        Example: "B:4712.92/4808.14|S:4807.74/4712.54"
        Logic:
           - Split by '|'
           - Identify Type (B/S)
           - Split by ':' then '/'
           - SL is first number for Buy? Or format is Price/SL/TP?
           - From log: "B:4712.92/4808.14" -> likely SL / TP (standard MT5 ordering usually SL then TP or vice versa, but values suggest SL < Price < TP for Buy)

        Let's assume "SL/TP" based on the values.
        Price ~ 4750.
        B: 4712 (Lower) / 4808 (Higher). -> SL / TP. Correct.
        S: 4807 (Higher) / 4712 (Lower). -> SL / TP. Correct.

        So format is "Type:SL/TP".
        """
        if pd.isna(levels_str) or levels_str == "NONE":
            return None

        distances = []

        # Split by pipe
        parts = str(levels_str).split('|')
        for part in parts:
            if ':' not in part or '/' not in part: continue

            type_char = part.split(':')[0] # B or S
            values = part.split(':')[1]

            try:
                sl_str, tp_str = values.split('/')
                sl = float(sl_str)
                # tp = float(tp_str) # Not needed for distance

                # Check for "0.0" which means no SL
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
        Hypothesis: There is a 'Safe Distance' where the broker doesn't care.
        """
        logger.info("\n📏 STARTING SENSITIVITY ANALYSIS: Distance vs Reaction")

        self.df['SLTP_Changed'] = self.df['SLTP_Levels'] != self.df['SLTP_Levels'].shift(1)

        intervention_indices = self.df[self.df['SLTP_Changed'] & (self.df['PosCount'] > 0)].index

        data_points = []

        for idx in intervention_indices:
            current_price = self.df.loc[idx, 'Bar_Close']
            levels_str = self.df.loc[idx, 'SLTP_Levels']

            # Calculate Distance
            distance = self.parse_sltp_levels_v3(levels_str, current_price)
            if distance is None: continue

            # Check Reaction (Stall? Hunt?)
            immediate_slice = self.df.iloc[idx:min(idx+10, len(self.df))]
            avg_vel_immediate = immediate_slice['Velocity'].mean()
            avg_vel_global = self.df['Velocity'].mean()

            reaction_ratio = avg_vel_immediate / avg_vel_global if avg_vel_global > 0 else 1.0

            # Check Outcome (Was it killed shortly?)
            lookahead_window = 120
            end_idx = min(idx + lookahead_window, len(self.df) - 1)
            future_slice = self.df.iloc[idx:end_idx]
            pos_drop = (future_slice['PosCount'] < future_slice['PosCount'].shift(1)).any()

            data_points.append({
                'Distance': distance,
                'Reaction_Ratio': reaction_ratio,
                'Is_Killed': pos_drop
            })

        if not data_points:
            logger.warning("   ⚠️ No valid distance data points found (Parser V3 failed?).")
            return

        # --- Aggregation & Heatmap ---
        res_df = pd.DataFrame(data_points)

        # Binning Distances
        bins = [0, 40, 50, 60, 100, 500] # Adjusted based on Gold price ~4750. 50pts is approx 1%.
        labels = ['0-40', '40-50', '50-60', '60-100', '100+']
        res_df['Dist_Bin'] = pd.cut(res_df['Distance'], bins=bins, labels=labels)

        logger.info(f"   📊 Analysis of {len(res_df)} Manual Adjustments:")

        summary = res_df.groupby('Dist_Bin', observed=False).agg(
            Count=('Distance', 'count'),
            Avg_Reaction=('Reaction_Ratio', 'mean'),
            Kill_Rate=('Is_Killed', 'mean')
        )

        print("\n   --- SENSITIVITY TABLE (Distance in Points) ---")
        print(summary.to_string())
        print("   ----------------------------------------------")

        # Interpretation
        logger.info("\n   🧠 INTERPRETATION:")
        for bin_label in labels:
            if bin_label not in summary.index: continue
            row = summary.loc[bin_label]
            if row['Count'] < 2: continue

            if row['Kill_Rate'] > 0.4:
                logger.info(f"      🔴 DANGER ZONE ({bin_label} pts): Kill Rate {row['Kill_Rate']*100:.1f}%.")
            elif row['Kill_Rate'] < 0.2:
                logger.info(f"      🟢 SAFE ZONE ({bin_label} pts): Kill Rate {row['Kill_Rate']*100:.1f}%.")
            else:
                 logger.info(f"      🟡 CONTESTED ZONE ({bin_label} pts): Kill Rate {row['Kill_Rate']*100:.1f}%.")

    def run(self):
        self.load_evidence()
        # self.analyze_micro_structure_hunt()
        self.analyze_distance_sensitivity()
        logger.info("\n🏁 Analysis Complete. The case is closed.")

if __name__ == "__main__":
    CSV_FILE = "Mimic_Research_GOLD_20260202_141322.csv"
    engine = ColomboForensicEngine(CSV_FILE)
    engine.run()
