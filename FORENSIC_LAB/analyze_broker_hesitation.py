import pandas as pd
import numpy as np
import sys

def analyze_hesitation(file_path):
    print(f"Loading data from {file_path}...")
    try:
        df = pd.read_csv(file_path)
    except Exception as e:
        print(f"Error loading CSV: {e}")
        return

    df['Time'] = pd.to_datetime(df['Time'], errors='coerce')
    df = df.sort_values(by='Time').reset_index(drop=True)

    # Fill specific missing values
    df['Velocity'] = pd.to_numeric(df['Velocity'], errors='coerce').fillna(0).abs()
    df['Floating_PL'] = pd.to_numeric(df['Floating_PL'], errors='coerce').fillna(0)
    df['Bid'] = pd.to_numeric(df['Bid'], errors='coerce')

    avg_spread = df['Spread'].mean() if 'Spread' in df.columns else 40
    avg_vel = df['Velocity'].mean()

    print(f"Stats: Avg Spread={avg_spread:.1f}, Avg Vel={avg_vel:.1f}")

    # --- FILTER DEBUGGING ---

    # 1. Profit Filter (Relaxed: > -1000 HUF, effectively near BE/Profit)
    profit_mask = df['Floating_PL'] > -5000
    print(f"Rows near Profit (PL > -5000): {profit_mask.sum()}")

    # 2. Velocity Filter (Relaxed: < 50% of avg)
    vel_threshold = avg_vel * 0.5
    vel_mask = df['Velocity'] < vel_threshold
    print(f"Rows with Low Velocity (< {vel_threshold:.1f}): {vel_mask.sum()}")

    # 3. Rolling Range (Micro-Oscillation)
    window_size = 10
    rolling_range = (df['Bid'].rolling(window_size).max() - df['Bid'].rolling(window_size).min())
    # Range should be "small" (tight consolidation) but "alive"
    range_mask = (rolling_range < (avg_spread * 0.3)) & (rolling_range > 0.05)
    print(f"Rows with Tight Range (< {avg_spread*0.3:.1f}): {range_mask.sum()}")

    # COMBINED
    candidates = df[profit_mask & vel_mask & range_mask].copy()
    print(f"COMBINED CANDIDATES: {len(candidates)}")

    if len(candidates) == 0:
        print("No matches found with relaxed filters.")
        return

    # Episode Grouping
    candidates['Time_Diff'] = candidates['Time'].diff().dt.total_seconds()
    candidates['New_Episode'] = candidates['Time_Diff'] > 5.0 # Split if > 5s gap
    candidates['Ep_ID'] = candidates['New_Episode'].cumsum()

    episodes = []
    for eid, group in candidates.groupby('Ep_ID'):
        start = group['Time'].iloc[0]
        end = group['Time'].iloc[-1]
        dur = (end - start).total_seconds()

        if dur > 2.0: # Filter super short blips
            episodes.append({
                'Start': start,
                'End': end,
                'Duration': dur,
                'Avg_PL': group['Floating_PL'].mean(),
                'Avg_Vel': group['Velocity'].mean(),
                'Range': rolling_range.loc[group.index].mean()
            })

    episodes.sort(key=lambda x: x['Duration'], reverse=True)

    print("\n=== IDENTIFIED HESITATION EPISODES (Top 5) ===")
    for i, ep in enumerate(episodes[:5]):
        print(f"#{i+1} [ {ep['Start'].time()} - {ep['End'].time()} ] Duration: {ep['Duration']:.1f}s")
        print(f"   Avg PL: {ep['Avg_PL']:.0f} HUF | Avg Vel: {ep['Avg_Vel']:.1f}")
        print("-" * 40)

    if episodes:
        pd.DataFrame(episodes).to_csv("FORENSIC_LAB/Hesitation_Episodes.csv", index=False)
        print(f"Saved {len(episodes)} episodes to FORENSIC_LAB/Hesitation_Episodes.csv")

if __name__ == "__main__":
    analyze_hesitation("FORENSIC_LAB/data/Mimic_Research_GOLD_20260202_141322.csv")
