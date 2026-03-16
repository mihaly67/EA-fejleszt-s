# 🚀 Merkava Néma Színház - Teljes MLOps Futtatási Útmutató (VPS)

Ez a dokumentum lépésről lépésre végigvezet azon, hogyan futtasd le a betanítást és az anomália keresést a **MINER_TESTER_v1.01_20260309_000000.csv** adathalmazodon a 8GB RAM-os VPS-en.

## 1. Könyvtár és Fájlok Előkészítése a VPS-en

Nyiss egy SSH terminált a VPS-en, és másold be az alábbi parancsokat pontosan így:

mkdir -p Merkava_ML_Ops/data
cd Merkava_ML_Ops

Most másold fel (pl. WinSCP, FileZilla segítségével) a számítógépedről a `MINER_TESTER_v1.01_20260309_000000.csv` fájlt a VPS-en lévő `Merkava_ML_Ops/data/` mappába.
Másold be mellé az ehhez az útmutatóhoz tartozó Python scripteket is (a GitHub `ANALYSIS_TOOLS/ML_Ops/` mappájának teljes tartalmát a `Merkava_ML_Ops/` mappába).

A végső struktúrád így fog kinézni:
Merkava_ML_Ops/
├── data/
│   └── MINER_TESTER_v1.01_20260309_000000.csv
├── models/
│   ├── __init__.py
│   ├── base_model.py
│   ├── isolation_forest.py
│   └── hmm_model.py
├── pipeline/
│   ├── __init__.py
│   ├── data_loader.py
│   ├── legacy_anomaly_detector.py
│   └── legacy_data_loader_demo.py
├── tests/
│   ├── __init__.py
│   └── test_pipeline.py
└── utils/
    ├── __init__.py
    ├── monitor.py
    └── mock_data_generator.py

## 2. Függőségek Telepítése (Csak első alkalommal)

Futtasd le a terminálban:

pip install pandas numpy scikit-learn hmmlearn psutil pytest

## 3. Rendszer Egészségügyi Tesztelése (Ajánlott)

Bizonyosodj meg róla, hogy a rendszer látja a Python csomagjaidat:

export PYTHONPATH=.
pytest tests/

Ha zöld (passed) eredményt látsz, a rendszer készen áll.

## 4. A Futtató Script (A Gyújtáskapcsoló) Létrehozása: run_analysis.py

A GitHubról vagy FileZillával letöltött mappáid (models, pipeline, utils) csak a "motoralkatrészek". Hogy beinduljon a gép, létre kell hoznunk a Gyújtáskapcsolót (run_analysis.py), ami beolvassa a CSV-t, majd áttolja a modelleken.
Ahhoz, hogy a script ne "törjön el" formázási hiba miatt a másolásnál, a legbiztonságosabb Linuxos szövegszerkesztőt, a `nano`-t fogjuk használni a VPS-en.

Írd be a terminálba a VPS-eden, hogy létrehozd a fájlt:

nano run_analysis.py

A megnyíló fekete szerkesztőbe jelöld ki és másold be (Jobb klikk a terminálon) EZT a python kódot:

```python
import logging
import os
from pipeline.data_loader import RobustDataLoader
from models.isolation_forest import IsolationForestDetector
from models.hmm_model import HMMDetector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

input_file = "data/MINER_TESTER_v1.01_20260309_000000.csv"
output_file = "data/ANALYZED_RESULTS_MINER_TESTER.csv"

# 1. Adat Betöltése
loader = RobustDataLoader(chunksize=500000)
df = loader.load_tick_data(input_file)

if df.empty:
    print("Kritikus Hiba: A betöltött DataFrame üres! Ellenőrizd a fájl nevét és az oszlopokat.")
    exit()

# 2. Anomália Keresés (Isolation Forest)
print("\n--- [ ISOLATION FOREST - ZAJ ÉS TÜSKE KERESÉS ] ---")
iso_model = IsolationForestDetector(contamination=0.02)
df = iso_model.preprocess(df)
iso_model.train(df)
df = iso_model.detect(df)

# Átnevezzük az eredmény oszlopokat:
df.rename(columns={'Anomaly': 'IF_Anomaly', 'Anomaly_Score': 'IF_Score'}, inplace=True)

# 3. Brókeri Rezsimek (Hidden Markov Model)
print("\n--- [ HIDDEN MARKOV MODEL - REZSIM KERESÉS ] ---")
hmm_model = HMMDetector(n_components=2)
df = hmm_model.preprocess(df)
hmm_model.train(df)
df = hmm_model.detect(df)

# 4. EREDMÉNYEK KIMENTÉSE CSV-be
print(f"\n--- [ FIZIKAI MENTÉS FOLYAMATBAN ] ---")
print(f"Eredmény mentése ide: {output_file}")
df.to_csv(output_file, index=False)
print("✅ Mentés Sikeres! Az elemzés véget ért.")
```

**Mentés és Kilépés a Nanoból:**
Nyomd meg a billentyűzeten a **Ctrl+O** (O, mint Oszkár) gombot a mentéshez, majd **Enter**.
Utána nyomd meg a **Ctrl+X** gombot a kilépéshez. Ezzel a script biztosan, formázási hiba nélkül jött létre.

## 5. Az Elemzés Indítása

Indítsd el a feldolgozást:

export PYTHONPATH=.
python3 run_analysis.py

## 6. A Kimenet Értelmezése (Hol van és mi az?)

**A Terminálban megjelenő logok (Valós időben):**
* Látni fogod, ahogy a betöltő (RobustDataLoader) 500.000 soros blokkokban falja be a fájlt.
* Kiírja a memóriahasználatot (RAM), hogy lásd, ha a VPS 8GB-ja kifogyna.
* A futás végén kiírja a talált toxikus időszakok/anomáliák darabszámát.

**A Fizikai Kimeneti Fájl (Végeredmény):**
* A futás után keletkezik egy új fájl: `Merkava_ML_Ops/data/ANALYZED_RESULTS_MINER_TESTER.csv`
* **Mit tartalmaz?** Ugyanazt a tick adatot, amit betöltöttél, de **KIBŐVÍTVE HÁROM ÚJ OSZLOPPAL:**
    1. **`IF_Anomaly`**: Ha az értéke `-1`, az azt jelenti, hogy az Isolation Forest algoritmus szerint az adott tick egyedi "kiugró" zaj vagy spread tüskét tartalmazott. Ha `1`, akkor normál tick volt.
    2. **`IF_Score`**: Ez egy negatív szám, ha hiba van. Minél kisebb a szám (pl. -0.2), annál durvább az anomália.
    3. **`BROKER_STATE`**: Ez egy tartós "Állapot" kód (általában `0` vagy `1`). A HMM tette rá. Pl. Ha hirtelen a 0-ás állapotból tartósan átvált az 1-esbe percekig, az azt jelenti, hogy a bróker "rezsimet" váltott (pl. hírek miatti csúszás vagy lassítás kezdődött). Ebből láthatod meg a "Néma Színház" manipulációit.

Ezt a CSV-t letöltheted a VPS-ről és kényelmesen megnyithatod a saját gépeden (Excel, Python) további elemzésre.
