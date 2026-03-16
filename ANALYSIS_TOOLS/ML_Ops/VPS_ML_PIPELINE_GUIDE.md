# 🚀 Merkava Néma Színház - Deep Learning Profilozó (VPS)

Ez a dokumentum lépésről lépésre végigvezet azon, hogyan vesd be a "Nehéztüzérséget" (LSTM Autoencoder) a **MINER_TESTER_v1.01_20260309_000000.csv** adathalmazodon a 8GB RAM-os VPS-en, és szűrd ki a Színész (Bróker) manipulációs trükkjeit. A korábbi (HMM) tanulóbicikli kidobásra került.

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
│   ├── hmm_model.py
│   └── lstm_autoencoder.py  # Új Nehéztüzérség
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

pip install pandas numpy scikit-learn psutil pytest tensorflow

## 3. Rendszer Egészségügyi Tesztelése (Ajánlott)

Bizonyosodj meg róla, hogy a rendszer látja a Python csomagjaidat:

export PYTHONPATH=.
pytest tests/

Ha zöld (passed) eredményt látsz, a rendszer készen áll.

## 4. A Futtató Script (A Gyújtáskapcsoló) Létrehozása: run_deep_profiler.py

A GitHubról vagy FileZillával letöltött mappáid (models, pipeline, utils) a "motoralkatrészek". Ahhoz, hogy ezt a 49 dimenziós nehéztüzérséget a VPS RAM-ja felrobbanása nélkül beindítsuk, létre kell hoznunk az új Gyújtáskapcsolót (`run_deep_profiler.py`).

Írd be a terminálba a VPS-eden, hogy létrehozd a fájlt (a `nano` megvéd az eltörő Windows-os formázásoktól):

nano run_deep_profiler.py

A megnyíló fekete szerkesztőbe másold be EZT a Python kódot:

```python
import logging
import os
from pipeline.data_loader import RobustDataLoader
from models.isolation_forest import IsolationForestDetector
from models.lstm_autoencoder import LSTMAutoencoderDetector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

input_file = "data/MINER_TESTER_v1.01_20260309_000000.csv"
output_file = "data/DEEP_ANALYSIS_MINER_TESTER.csv"

# 1. Adat Betöltése (49 dimenzió, masszív adathalmaz)
loader = RobustDataLoader(chunksize=100000) # Kisebb chunk a Neurális Háló Memória-igénye miatt
df = loader.load_tick_data(input_file)

if df.empty:
    print("Kritikus Hiba: A betöltött DataFrame üres! Ellenőrizd a fájlt.")
    exit()

# 2. ELŐSZŰRÉS: Isolation Forest (Zaj és Egyedi Tüskék)
print("\n--- [ ISOLATION FOREST - ELŐSZŰRŐ ] ---")
iso_model = IsolationForestDetector(contamination="auto")
df = iso_model.preprocess(df)
iso_model.train(df)
df = iso_model.detect(df)
df.rename(columns={'Anomaly': 'IF_Anomaly', 'Anomaly_Score': 'IF_Score'}, inplace=True)

# 3. NEHÉZTÜZÉRSÉG: Szekvenciális Deep Learning (LSTM Autoencoder)
print("\n--- [ LSTM AUTOENCODER - SZEKVENCIA PROFILOZÁS ] ---")
# 30 tickes "ablak", 8 dimenziós látens tér, batch méret korlátozás a VPS miatt
lstm_model = LSTMAutoencoderDetector(seq_length=30, latent_dim=8, batch_size=256, epochs=5)
lstm_model.train(df)
df = lstm_model.detect(df)

# Mentsük ki a neurális háló modelljét, ha később máson is tesztelnénk:
lstm_model.save("models/saved_lstm_broker_profiler")

# 4. EREDMÉNYEK KIMENTÉSE CSV-be
print(f"\n--- [ FIZIKAI MENTÉS FOLYAMATBAN ] ---")
df.to_csv(output_file, index=False)
print(f"✅ Mentés Sikeres: {output_file}")
```

**Mentés és Kilépés a Nanoból:**
Nyomd meg a billentyűzeten a **Ctrl+O** (Oszkár) gombot a mentéshez, majd **Enter**.
Utána nyomd meg a **Ctrl+X** gombot a kilépéshez.

## 5. Az Elemzés Indítása

Indítsd el a feldolgozást:

export PYTHONPATH=.
python3 run_deep_profiler.py

## 6. A Kimenet Értelmezése (Mi ez a "Deep Learning" Fájl?)

**A Terminálban megjelenő logok (Valós időben):**
* A betöltő után látni fogod a TensorFlow progress bárját. Ez percekig vagy akár egy-két óráig is futhat az 1 millió soron (Epoch 1/5, Epoch 2/5). A Loss-nak folyamatosan csökkennie kell.

**A Fizikai Kimeneti Fájl (Végeredmény):**
* Létrejön a `data/DEEP_ANALYSIS_MINER_TESTER.csv`.
* **Mit tartalmaz?** Az összes régi adatodat, plusz az IF eredményeit, ÉS A KÉT ÚJ LSTM OSZLOPOT:
    1. **`LSTM_Reconstruction_Error`**: Ez a konkrét matematikai hiba. Ha a hálózat nem ismerte fel a bróker 30-tickes szekvenciáját (mert az mesterséges / toxikus volt), ez a szám hirtelen a normál (pl. 0.05) duplájára-triplájára fog ugrani.
    2. **`LSTM_Anomaly`**: Ez már a kész, neked szóló szignál. `-1` jelenti a tisztán manipulált időablakot/bróker trükköt (Színész!), és `1` a természetes piaci eseményt.

Ezt a CSV-t letöltheted a VPS-ről és kényelmesen megnyithatod a saját gépeden (Excel, Python) további elemzésre.
