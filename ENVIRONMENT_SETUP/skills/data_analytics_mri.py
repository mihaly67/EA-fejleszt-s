# Autonomous Agent Skill: MLOps Data Analytics (OOM-Safe Agent-to-Bot)
# Gyors statisztikai elemzés nagy adathalmazokon (pl. EA teszt eredmények, tickek)
import argparse
import pandas as pd
import numpy as np
import os
import time

def run_analytics(filepath: str, column: str, chunksize: int = 10000):
    if not os.path.exists(filepath):
        print(f"❌ Hiba: A fájl nem található: {filepath}")
        return

    print(f"🔬 [Data Analytics] Fájl: {filepath}")
    print(f"🔬 [Data Analytics] Cél oszlop: {column}")

    total_rows = 0
    running_sum = 0.0
    running_min = float('inf')
    running_max = float('-inf')

    try:
        for chunk in pd.read_csv(filepath, chunksize=chunksize):
            if column not in chunk.columns:
                print(f"❌ [Data Analytics] Az oszlop '{column}' nem létezik az adatban!")
                return

            # Numerikus konverzió hibatűréssel
            col_data = pd.to_numeric(chunk[column], errors='coerce').dropna()

            if not col_data.empty:
                total_rows += len(col_data)
                running_sum += col_data.sum()
                running_min = min(running_min, col_data.min())
                running_max = max(running_max, col_data.max())

            print(f"⏳ [Data Analytics] Feldolgozva: {total_rows} rekord...", flush=True)
            time.sleep(0.01) # CPU tehermentesítés

        if total_rows > 0:
            mean_val = running_sum / total_rows
            print(f"\n✅ [Data Analytics Válasz] Statisztikai Gyorselemzés:")
            print(f"   - Vizsgált rekordok (Valid): {total_rows}")
            print(f"   - Minimum: {running_min}")
            print(f"   - Maximum: {running_max}")
            print(f"   - Átlag (Mean): {mean_val:.4f}")
            print("🧠 [Agent Prompt] Az adatok eloszlása felmérve, jöhet a ML stratégia.")
        else:
            print("⚠️ [Data Analytics] Nem találtam érvényes numerikus adatot ebben az oszlopban.")

    except MemoryError:
        print("❌ [Data Analytics] MEMORY ERROR! Chunk méret csökkentése javasolt!")
    except Exception as e:
        print(f"❌ [Data Analytics] Hiba történt: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OOM-Safe Data Analytics Tool")
    parser.add_argument("--file", required=True, help="A CSV fájl elérési útja")
    parser.add_argument("--col", required=True, help="A vizsgálandó oszlop neve")
    parser.add_argument("--chunk", type=int, default=10000, help="Chunk méret")
    args = parser.parse_args()

    run_analytics(args.file, args.col, args.chunk)
