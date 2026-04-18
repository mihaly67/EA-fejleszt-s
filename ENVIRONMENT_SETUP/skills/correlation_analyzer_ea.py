# Autonomous Agent Skill: MT5 Correlation Analyzer
import argparse
import pandas as pd
import numpy as np
import os
import time

def run_correlation(filepath: str, col1: str, col2: str, chunksize: int = 10000):
    if not os.path.exists(filepath):
        print(f"❌ Hiba: A fájl nem található: {filepath}")
        return

    print(f"🔗 [Correlation Analyzer] Fájl: {filepath}")
    print(f"🔗 [Correlation Analyzer] Változók: {col1} vs {col2}")

    # O(1) memóriás korrelációhoz sumx, sumy, sumxy, sumx2, sumy2 kell
    sum_x = 0.0; sum_y = 0.0; sum_xy = 0.0; sum_x2 = 0.0; sum_y2 = 0.0
    n = 0

    try:
        for chunk in pd.read_csv(filepath, chunksize=chunksize):
            if col1 not in chunk.columns or col2 not in chunk.columns:
                print(f"❌ Oszlophiba: {col1} vagy {col2} hiányzik!")
                return

            df_clean = chunk[[col1, col2]].apply(pd.to_numeric, errors='coerce').dropna()

            if not df_clean.empty:
                x = df_clean[col1].values
                y = df_clean[col2].values

                n += len(x)
                sum_x += np.sum(x)
                sum_y += np.sum(y)
                sum_xy += np.sum(x * y)
                sum_x2 += np.sum(x**2)
                sum_y2 += np.sum(y**2)

            print(f"⏳ [Correlation Analyzer] Feldolgozva: {n} pár...", flush=True)
            time.sleep(0.01)

        if n > 1:
            # Pearson korrelációs együttható képlete chunkolt adatokra
            numerator = n * sum_xy - sum_x * sum_y
            denominator = np.sqrt((n * sum_x2 - sum_x**2) * (n * sum_y2 - sum_y**2))

            if denominator == 0:
                corr = 0.0
            else:
                corr = numerator / denominator

            print(f"\n✅ [Correlation Válasz] Pearson Korreláció ({col1} - {col2}):")
            print(f"   - Együttható (R): {corr:.4f}")
            if abs(corr) > 0.7:
                print("   - Értékelés: ERŐS kapcsolat.")
            elif abs(corr) > 0.3:
                print("   - Értékelés: KÖZEPES kapcsolat.")
            else:
                print("   - Értékelés: GYENGE / NINCS kapcsolat.")
        else:
            print("⚠️ [Correlation] Nincs elég adat a számításhoz.")

    except Exception as e:
        print(f"❌ [Correlation] Hiba történt: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OOM-Safe Correlation Analyzer")
    parser.add_argument("--file", required=True)
    parser.add_argument("--col1", required=True)
    parser.add_argument("--col2", required=True)
    parser.add_argument("--chunk", type=int, default=10000)
    args = parser.parse_args()

    run_correlation(args.file, args.col1, args.col2, args.chunk)
