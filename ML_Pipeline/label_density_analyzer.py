import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import random

# Töltsük be az adatot
df = pd.read_parquet('../data/processed/scalp_features.parquet')

total_rows = len(df)
buys = len(df[df['target'] == 1])
sells = len(df[df['target'] == -1])
holds = len(df[df['target'] == 0])

print('=== 1. GLOBÁLIS CÍMKÉZÉSI ARÁNYOK ===')
print(f'Összes sor: {total_rows}')
print(f'BUY (1):   {buys} ({buys/total_rows*100:.2f}%)')
print(f'SELL (-1): {sells} ({sells/total_rows*100:.2f}%)')
print(f'HOLD (0):  {holds} ({holds/total_rows*100:.2f}%)')
print('-----------------------------------------')

print('\n=== 2. MINTAVÉTELEZETT ABLAKOK (2 ÓRÁS) ===')
# Vegyünk 3 véletlenszerű 2 órás (120 perces) ablakot
for i in range(3):
    start_idx = random.randint(0, total_rows - 120)
    window = df.iloc[start_idx : start_idx + 120]

    # Karakterlánccá alakítjuk a címkéket, hogy vizuálisan lásd a terminálban
    # B = Buy, S = Sell, . = Hold/Semmi
    timeline = ''
    for val in window['target'].values:
        if val == 1: timeline += 'B'
        elif val == -1: timeline += 'S'
        else: timeline += '.'

    print(f'Ablak {i+1} ({window.index[0]} -> {window.index[-1]}):')
    print(f'Sorrend: {timeline}')

    b_win = len(window[window['target'] == 1])
    s_win = len(window[window['target'] == -1])
    print(f'Statisztika: {b_win} BUY, {s_win} SELL ({(b_win+s_win)/120*100:.1f}% sűrűség)\n')

print('\n=== 3. VIZUÁLIS KÉP GENERÁLÁSA ===')
# Rajzoljunk ki egy teljes 2 órás szakaszt vizuálisan egy PNG fájlba
start_idx = len(df) // 2  # Középről veszünk egy ablakot
window = df.iloc[start_idx : start_idx + 120]

plt.figure(figsize=(15, 6))
# A return_1-et rajzoljuk ki amolyan price proxyként, illetve pöttyözzük a jeleket
plt.plot(window.index, window['return_1'].cumsum(), color='grey', alpha=0.5, label='Price Momentum (Proxy)')

buys_w = window[window['target'] == 1]
sells_w = window[window['target'] == -1]

plt.scatter(buys_w.index, buys_w['return_1'].cumsum(), color='green', marker='^', s=100, label='BUY')
plt.scatter(sells_w.index, sells_w['return_1'].cumsum(), color='red', marker='v', s=100, label='SELL')

plt.title('Triple Barrier Label Sűrűség - 2 Órás M1 Ablak')
plt.xlabel('Idő')
plt.ylabel('Kumulált Momentum')
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()

plt.savefig('label_density.png', dpi=150)
print('Kép sikeresen lementve: /home/misi/Merkava_ML_Ops/src/label_density.png')
