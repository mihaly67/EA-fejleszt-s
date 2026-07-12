import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

def visualize_hybrid(csv_file):
    if not os.path.exists(csv_file):
        logger.error(f"Fájl nem található: {csv_file}")
        return
        
    logger.info(f"Vizuális elemzés indítása: {csv_file}")
    df = pd.read_csv(csv_file)
    
    # 1. Alapvető beállítások
    plt.figure(figsize=(18, 12))
    
    # Csak az utolsó 50,000 ticket ábrázoljuk, ha nagyon nagy a fájl, hogy látszódjon a chart
    if len(df) > 50000:
        df = df.iloc[50000:60000]
        
    df['Datetime'] = pd.to_datetime(df['Datetime'])
    
    # Két részre osztjuk a chartot
    ax1 = plt.subplot(2, 1, 1)
    
    # Árfolyam rajzolása
    ax1.plot(df['Datetime'], df['Price'], label='Árfolyam', color='black', alpha=0.6)
    
    # Színek a Döntési Mátrix alapján
    green_idx = df[df['Hybrid_Decision'] == 'GREEN']
    yellow_idx = df[df['Hybrid_Decision'] == 'YELLOW']
    red_idx = df[df['Hybrid_Decision'] == 'RED']
    
    ax1.scatter(green_idx['Datetime'], green_idx['Price'], color='green', label='ENGEDÉLYEZETT (Tiszta Piac)', s=10, alpha=0.5)
    ax1.scatter(yellow_idx['Datetime'], yellow_idx['Price'], color='orange', label='VÁRAKOZÁS (Mikro Manipuláció)', s=15, alpha=0.7)
    ax1.scatter(red_idx['Datetime'], red_idx['Price'], color='red', label='TILTVA (Makro Káosz)', s=10, alpha=0.5)
    
    ax1.set_title('VAKU 3.0 HIBRID DÖNTÉSI MÁTRIX - EA TANÁCSADÓ NÉZET')
    ax1.set_ylabel('Árfolyam')
    ax1.legend(loc='best')
    ax1.grid(True, alpha=0.3)
    
    # Második rész: Makro ER vs Mikro Kockázat
    ax2 = plt.subplot(2, 1, 2, sharex=ax1)
    
    ax2.plot(df['Datetime'], df['Macro_ER'], color='blue', label='Makro Trend (ER)', alpha=0.8)
    
    # Hozzáadunk egy második y tengelyt a kockázatnak
    ax3 = ax2.twinx()
    
    # Támogatás, ha nincs Theater_Risk_Pct az adathalmazban (régebbi fájlok)
    if 'Theater_Risk_Pct' in df.columns:
        ax3.fill_between(df['Datetime'], 0, df['Theater_Risk_Pct'], color='red', alpha=0.3, label='Viterbi Jövőkutatás (Kockázat %)')
        ax3.axhline(y=20, color='r', linestyle='--', alpha=0.5, label='Kockázati Küszöb (20%)')
        ax3.set_ylabel('Rizikó %', color='red')
        ax3.set_ylim(0, 100)
    
    ax2.set_xlabel('Idő')
    ax2.set_ylabel('Makro ER (Kaufman)', color='blue')
    
    # Közös legend
    lines, labels = ax2.get_legend_handles_labels()
    lines2, labels2 = ax3.get_legend_handles_labels()
    ax2.legend(lines + lines2, labels + labels2, loc='upper left')
    
    plt.tight_layout()
    out_file = "reports_tmp/HYBRID_VISUAL_PLOT.png"
    plt.savefig(out_file, dpi=150)
    logger.info(f"Vizualizáció kimentve: {out_file}")

if __name__ == "__main__":
    visualize_hybrid("reports_tmp/HYBRID_EVAL_EURUSD.csv")
