import pandas as pd
import numpy as np

file = "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/DOM_Data.csv"
print(f"Reading {file}...")
# Kezeljük az esetleges hibás/üres sorokat a fájl végén, amik miatt az end_msc 'nan' lett
df = pd.read_csv(file)
df = df.dropna(subset=['TimeMsc'])

start_msc = df['TimeMsc'].iloc[0]
end_msc = df['TimeMsc'].iloc[-1]

diff_msc = end_msc - start_msc
seconds = diff_msc / 1000.0
minutes = seconds / 60.0
hours = minutes / 60.0

print(f"Érvényes sorok száma: {len(df)}")
print(f"Első tick: {start_msc}")
print(f"Utolsó tick: {end_msc}")
print(f"Teljes rögzített idő: {seconds:.2f} másodperc")
print(f"Teljes rögzített idő: {minutes:.2f} perc")
print(f"Teljes rögzített idő: {hours:.2f} óra")
