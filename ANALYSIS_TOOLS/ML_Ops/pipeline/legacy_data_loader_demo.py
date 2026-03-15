import pandas as pd
import gc
import os

def load_and_filter_miner_data(csv_path: str) -> pd.DataFrame:
    """
    Betölti a Merkava Data Miner által generált gigantikus CSV fájlt (pl. 1GB+),
    de KIZÁRÓLAG a HMM / Autoencoder számára releváns oszlopokat tartja meg a memóriában.

    A 8GB RAM korlát miatt eldobja a Pivotokat, account statisztikákat és stringeket.
    """

    # KIZÁRÓLAG EZEK AZ OSZLOPOK TÖLTŐDNEK BE A RAM-BA:
    relevant_columns = [
        "Time", "TickMSC", "Bid", "Ask", "Spread",
        "BidVol", "AskVol",
        "Velocity", "Acceleration",
        "Hybrid_MACD", "Hybrid_DFCurve",
        "Flow_MFI", "Flow_ROC", "Flow_Delta",
        "Ctx_EMA_25", "Ctx_EMA_50", "Ctx_EMA_150", "Ctx_EMA_300",
        "WPR", "Stoch_K"
        # Kihagyva: Pivotok (Mic_P, Sec_P stb.), LotDir, Balance, Margin, Verdict, stb...
    ]

    print(f"⌛ Adatbázis betöltése megkezdve: {csv_path}")
    print(f"📊 Kiválasztott oszlopok száma: {len(relevant_columns)}")

    if not os.path.exists(csv_path):
        print(f"❌ A fájl nem található: {csv_path}")
        return pd.DataFrame()

    # CHUNKING (Darabolt beolvasás) a memória túlcsordulás megelőzésére
    # A chunksize=100000 azt jelenti, hogy egyszerre csak 100 ezer sort olvas be
    chunk_list = []
    chunk_count = 0

    try:
        # A usecols paraméter az igazi varázslat: a Pandas fizikailag figyelmen kívül hagyja a többi oszlopot!
        for chunk in pd.read_csv(csv_path, usecols=relevant_columns, chunksize=100000, engine='c'):
            chunk_count += 1

            # --- Itt lehetne normalizálni is (MinMaxScaler) Chunk-onként, mielőtt a listába tesszük ---

            chunk_list.append(chunk)
            print(f"   ✔️ Chunk {chunk_count} betöltve (100,000 sor)")

        # Végül egyesítjük a darabokat egyetlen Dataframe-be
        df_final = pd.concat(chunk_list, ignore_index=True)

        # Töröljük a memóriából az ideiglenes listát és meghívjuk a Garbage Collectort
        del chunk_list
        gc.collect()

        print(f"✅ Sikeres betöltés! Összes sor: {len(df_final)}")
        print(f"💾 Memóriahasználat: {df_final.memory_usage(deep=True).sum() / (1024*1024):.2f} MB")

        return df_final

    except ValueError as e:
         print(f"❌ Hiba az oszlopok beolvasásánál. Valószínűleg rossz a fejléc neve. Hiba: {e}")
         return pd.DataFrame()

if __name__ == "__main__":
    # Példa a meghívásra (írd át a valós fájlnevedre)
    # df = load_and_filter_miner_data("../../MQL5/Files/MINER_DATA.csv")
    pass
