import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os
import argparse

def analyze_dom(file_path):
    print(f"Elemzés: {file_path}")
    df = pd.read_csv(file_path)

    # Alapvető metrikák
    print(f"Sorok száma: {len(df)}")

    # Imbalance Számítás (Order Book Imbalance)
    # Képlet: (BidVol - AskVol) / (BidVol + AskVol)
    # Külön V1 és összesített szintekre

    # EURUSD DOM miner esetében van V1, V2, V3, V4, V5 (a legacy BlackBox miatt)
    # Merkava_DOM_Miner_MQL5 script esetében csak V1, V2 van. Ezt dinaminuksan lekezeljük.

    bid_cols = [c for c in df.columns if c.startswith('Bid') and ('Vol' in c or 'V' in c) and df[c].sum() > 0]
    ask_cols = [c for c in df.columns if c.startswith('Ask') and ('Vol' in c or 'V' in c) and df[c].sum() > 0]

    if len(bid_cols) > 0 and len(ask_cols) > 0:
        df['Total_Bid_Vol'] = df[bid_cols].sum(axis=1)
        df['Total_Ask_Vol'] = df[ask_cols].sum(axis=1)
        df['Imbalance'] = (df['Total_Bid_Vol'] - df['Total_Ask_Vol']) / (df['Total_Bid_Vol'] + df['Total_Ask_Vol'])

        # Spoofing detektálás (Hirtelen volumencsökkenés anélkül hogy trade történt volna a levelen)
        # Egyelőre egyszerűen a top level volatilitásának ugrásai
        df['Ask_V1_Delta'] = df.get('Ask_Vol_1', df.get('AskV1', pd.Series())).diff()
        df['Bid_V1_Delta'] = df.get('Bid_Vol_1', df.get('BidV1', pd.Series())).diff()

        print(f"Átlagos Imbalance: {df['Imbalance'].mean():.4f}")

        # XGBoost Prediction Power korreláció (Shiftelt jövőbeli árváltozással)
        df['Future_Return_10s'] = df.get('Ask', df.get('BestAsk', pd.Series())).shift(-1000) / df.get('Ask', df.get('BestAsk', pd.Series())) - 1

        corr = df['Imbalance'].corr(df['Future_Return_10s'])
        print(f"Imbalance -> Jövőbeli (10s) Hozam korreláció: {corr:.4f}")

        # Vizualizáció lementése
        plt.figure(figsize=(15, 10))

        plt.subplot(3, 1, 1)
        plt.plot(df.index, df.get('Ask', df.get('BestAsk', pd.Series())), label='Best Ask', color='red')
        plt.plot(df.index, df.get('Bid', df.get('BestBid', pd.Series())), label='Best Bid', color='green')
        plt.title('Árfolyam (Best Bid/Ask)')
        plt.legend()

        plt.subplot(3, 1, 2)
        plt.plot(df.index, df['Imbalance'], label='Order Book Imbalance (OBI)', color='blue')
        plt.axhline(0, color='black', linestyle='--')
        plt.title('DOM Imbalance (-1: Tiszta Sell, +1: Tiszta Buy)')
        plt.legend()

        plt.subplot(3, 1, 3)
        plt.plot(df.index, df.get('Ask_Vol_1', df.get('AskV1', pd.Series())), label='Top Ask Volumen', color='red', alpha=0.5)
        plt.plot(df.index, df.get('Bid_Vol_1', df.get('BidV1', pd.Series())), label='Top Bid Volumen', color='green', alpha=0.5)
        plt.title('Top Level 1 Volumen (Spoofing vizsgálathoz)')
        plt.legend()

        plt.tight_layout()
        out_name = os.path.basename(file_path).replace('.csv', '_DOM.png')
        plt.savefig(out_name)
        print(f"Grafikon mentve: {out_name}")
    else:
        print("Nincsenek érvényes DOM volumen adatok a fájlban.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', type=str, default='DOM_Data.csv')
    args = parser.parse_args()
    analyze_dom(args.file)
