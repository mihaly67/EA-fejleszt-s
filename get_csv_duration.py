import pandas as pd

df = pd.read_csv('/home/misi/Merkava_ML_Ops/data/raw/DOM_Data.csv')
start_msc = df['TimeMsc'].iloc[0]
end_msc = df['TimeMsc'].iloc[-1]

diff_msc = end_msc - start_msc
seconds = diff_msc / 1000.0
minutes = seconds / 60.0
hours = minutes / 60.0

print(f"Első tick: {start_msc}")
print(f"Utolsó tick: {end_msc}")
print(f"Teljes rögzített idő: {seconds:.2f} másodperc")
print(f"Teljes rögzített idő: {minutes:.2f} perc")
print(f"Teljes rögzített idő: {hours:.2f} óra")
