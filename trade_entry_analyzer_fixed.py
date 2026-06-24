import pandas as pd
import glob
import os
import numpy as np

def analyze_trade_entries(labeled_dir):
    files = glob.glob(os.path.join(labeled_dir, "VAKU3_VALIDATED_LABELED_*.csv"))
    if not files:
        print("Nincsenek validált felcímkézett fájlok.")
        return
        
    print(f"Vizsgált fájlok száma: {len(files)}")
    print("="*80)
    
    total_trades = 0
    decisions_at_entry = {'GREEN': 0, 'YELLOW': 0, 'RED': 0}
    
    for f in files:
        filename = os.path.basename(f)
        print(f"\n📂 Elemzés: {filename}")
        df = pd.read_csv(f)
        
        # 1. Hibrid Motor gyors felépítése, hogy meglegyen a Hybrid_Decision
        if 'TimeMsc' not in df.columns and 'TickMSC' not in df.columns:
            continue
            
        time_col = 'TimeMsc' if 'TimeMsc' in df.columns else 'TickMSC'
        df['Datetime'] = pd.to_datetime(df[time_col], unit='ms')
        
        # Árfolyam
        if 'Ask' in df.columns and 'Bid' in df.columns:
            df['Price'] = (df['Ask'] + df['Bid']) / 2.0
        elif 'Last' in df.columns:
            df['Price'] = df['Last']
        else:
            df['Price'] = df.iloc[:, 1]
            
        # Makro gyertya generálása (5 perces) - egyszerűsített
        df_time = df.set_index('Datetime')
        ohlc = df_time['Price'].resample('5min').ohlc()
        
        def calc_er(series):
            if len(series) < 2: return 0.0
            net = abs(series.iloc[-1] - series.iloc[0])
            gross = np.sum(np.abs(np.diff(series)))
            return net / gross if gross > 0 else 0.0
            
        ohlc['Macro_ER'] = ohlc['close'].rolling(window=5).apply(calc_er, raw=False).fillna(0)
        
        # Visszateszük az indexet
        ohlc.reset_index(inplace=True)
        df_time.reset_index(inplace=True)
        
        # AsOf Merge
        hybrid_df = pd.merge_asof(df_time, ohlc[['Datetime', 'Macro_ER']], on='Datetime', direction='backward')
        
        # Ha a HMM (Viterbi) nem tette be a Pct-t
        if 'Theater_Risk_Pct' not in hybrid_df.columns:
            hybrid_df['Theater_Risk_Pct'] = 0.0 # Fallback
            
        # Szabályok alkalmazása
        conditions = [
            (hybrid_df['Macro_ER'] >= 0.3) & (hybrid_df['Theater_Risk_Pct'] < 20.0),
            (hybrid_df['Macro_ER'] >= 0.3) & (hybrid_df['Theater_Risk_Pct'] >= 20.0),
            (hybrid_df['Macro_ER'] < 0.3)
        ]
        choices = ['GREEN', 'YELLOW', 'RED']
        hybrid_df['Hybrid_Decision'] = np.select(conditions, choices, default='RED')
        
        # 2. TRADE KERESÉSE
        # Ahol a PosCount megváltozik (0-ról 1-re, vagy hasonló) -> Ott volt belépés
        # Ha nincs PosCount, akkor ahol Target van megadva
        if 'PosCount' in hybrid_df.columns:
            # Csak azokat nézzük, ahol a pozíciószám > 0, és az előző tickben kevesebb volt (ÚJ KÖTÉS)
            entries = hybrid_df[(hybrid_df['PosCount'] > 0) & (hybrid_df['PosCount'] > hybrid_df['PosCount'].shift(1))]
            
            if len(entries) == 0:
                print("  Nincs találat az új kötésekre (PosCount alapján). Próbálkozás Target oszloppal...")
                target_series = hybrid_df.get('Target', pd.Series([-1]*len(hybrid_df)))
            entries = hybrid_df[(target_series == 0) | (target_series == 1)]
                
        else:
            target_series = hybrid_df.get('Target', pd.Series([-1]*len(hybrid_df)))
            entries = hybrid_df[(target_series == 0) | (target_series == 1)]
            
        print(f"  Talált Kötési Események: {len(entries)} db")
        total_trades += len(entries)
        
        # 3. Kötések kiértékelése
        for idx, row in entries.iterrows():
            decision = row['Hybrid_Decision']
            macro = row['Macro_ER']
            risk = row['Theater_Risk_Pct']
            target = row.get('Target', -1)
            
            decisions_at_entry[decision] += 1
            
            reakcio_str = "Tiszta" if target == 0 else ("Manipulált!" if target == 1 else "Ismeretlen")
            
            print(f"  [Time: {row['Datetime']}] EA Javaslat: {decision:<6} | Makro ER: {macro:.2f} | Kockázat: {risk:04.1f}% -> Valós Reakció: {reakcio_str}")

    print("\n" + "="*80)
    print(f"ÖSSZESÍTÉS {total_trades} TRADE ESEMÉNY ALAPJÁN:")
    print(f" ZÖLD (Belépés Engedélyezve): {decisions_at_entry['GREEN']} alkalommal")
    print(f" SÁRGA (Várakozás javasolt):  {decisions_at_entry['YELLOW']} alkalommal")
    print(f" PIROS (Belépés Tiltva):      {decisions_at_entry['RED']} alkalommal")

if __name__ == "__main__":
    analyze_trade_entries("/home/misi/Merkava_ML_Ops/data/labeled/")
