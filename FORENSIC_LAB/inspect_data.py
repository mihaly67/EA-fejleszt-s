import pandas as pd
import numpy as np

file = "FORENSIC_LAB/data/Mimic_Research_GOLD_20260202_141322.csv"
df = pd.read_csv(file)

print("--- DATA INSPECTION ---")
print(f"Total Rows: {len(df)}")
print("\nVelocity Stats:")
print(df['Velocity'].describe())

print("\nFloating_PL Stats:")
print(df['Floating_PL'].describe())

print("\nRows with Floating_PL > 0:")
print(len(df[df['Floating_PL'] > 0]))

# Calculate rolling range to check typical oscillation
df['Bid'] = pd.to_numeric(df['Bid'], errors='coerce')
rolling_range = (df['Bid'].rolling(10).max() - df['Bid'].rolling(10).min())
print("\nRolling Range (10 ticks) Stats:")
print(rolling_range.describe())
