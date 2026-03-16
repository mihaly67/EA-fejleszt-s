# 🚀 Merkava Néma Színház - MLOps Pipeline Útmutató (VPS)

Ez a dokumentum a `Merkava_Data_Miner_v1.0` által gyűjtött (pl. XAUUSD 5 napos tick) adathalmazok CPU-only, 8GB RAM limitált Ubuntu VPS környezetben történő feldolgozásához készült.

## 1. Könyvtárszerkezet a VPS-en
A rendszert a GitHub repó `ANALYSIS_TOOLS/ML_Ops/` mappáján belül találod, de ha külön mozgatod a VPS-re, ez a struktúra a mérvadó:

```text
ML_Ops/
├── data/                    # IDE MÁSOLD a DataMiner CSV fájlokat (pl. XAUUSD_tick.csv)
├── models/
│   ├── base_model.py        # Közös interfész (ne nyúlj hozzá)
│   ├── isolation_forest.py  # Anomália detektor (Scikit-Learn)
│   └── hmm_model.py         # Hidden Markov Model (bróker rezsimek azonosítása)
├── pipeline/
│   └── data_loader.py       # RAM kímélő (chunkolt) adatbetöltő
├── tests/
│   └── test_pipeline.py     # Keretrendszer egészségügyi ellenőrzése
└── utils/
    ├── monitor.py           # CPU/RAM védelmi modul
    └── mock_data_generator.py # Csak szimulációhoz
```

## 2. Rendszerkövetelmények (Függőségek telepítése)
Mielőtt bármit futtatnál a VPS-en, frissítsd a Python környezeted a szükséges csomagokkal:

```bash
# Lépj be a projekt mappájába
cd ANALYSIS_TOOLS/ML_Ops/

# Telepítsd a csomagokat
pip install pandas numpy scikit-learn hmmlearn psutil pytest
```

## 3. Rendszer Tesztelése (Opcionális, de ajánlott)
Mielőtt ráengeded az 1GB+ XAUUSD fájlt a gépre, futtasd le a beépített Pytest szimulációt, amely megnézi, hogy a 8GB RAM-os `DataLoader` és a modellek megfelelően lettek-e importálva:

```bash
PYTHONPATH="." pytest tests/
```
Ha 100%-os zöld "passed" eredményt kapsz, a keretrendszer működik.

## 4. Futtatás a Nyers Adattal
Létrehozhatsz a projekt gyökerében egy egyszerű Python fájlt (pl. `run_analysis.py`), amivel betöltöd az adatot és elindítod a profilozást. Íme egy példa sablon a futtatáshoz:

```python
# run_analysis.py tartalma:
import logging
from pipeline.data_loader import RobustDataLoader
from models.isolation_forest import IsolationForestDetector
from models.hmm_model import HMMDetector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

# 1. Adat Betöltése (csak a releváns, BlackBox által exportált oszlopokat tartja meg a RAM-ban)
loader = RobustDataLoader(chunksize=500000) # Félmilliós darabokban olvas (8GB RAM barát)
df = loader.load_tick_data("data/XAUUSD_tick_5_days.csv")

if df.empty:
    print("Hiba: Üres a fájl, vagy nem egyeznek az oszlopnevek.")
    exit()

# 2. Anomália Keresés (Isolation Forest)
print("\n--- [ ISOLATION FOREST ] ---")
iso_model = IsolationForestDetector(contamination=0.02) # Feltételezett 2% manipulált adat
df_iso = iso_model.preprocess(df.copy())
iso_model.train(df_iso)
df_iso = iso_model.detect(df_iso)

# 3. Brókeri Rezsimek / Állapotok (Hidden Markov Model)
print("\n--- [ HIDDEN MARKOV MODEL ] ---")
hmm_model = HMMDetector(n_components=2) # 2 állapot: Normál vs. Manipulált
df_hmm = hmm_model.preprocess(df.copy())
hmm_model.train(df_hmm)
df_hmm = hmm_model.detect(df_hmm)

print("\nKÉSZ! A vizsgálat lefutott. A toxikus periódusok megtalálhatók a df_hmm['BROKER_STATE'] oszlopban.")
```

**Futtatás a parancssorból a VPS-en:**
```bash
python3 run_analysis.py
```

## 5. Mire kell figyelni? (Fontos)
* **Memória Limits (OOM):** A `utils/monitor.py` modul bele van építve a `data_loader.py`-ba. Ha aVPS eléri a 90% RAM terhelést, a folyamat figyelmeztetést dob (`KRITIKUS MEMÓRIA SZINT`) és leállítja a további beolvasást, hogy megvédje a VPS-t az összeomlástól (Out-Of-Memory).
* **Zaj és Nyers Adat:** A HMM és az Isolation Forest modellek _nyers_ adatra vágynak, ahogy kérted. Semmilyen elsimítás nincs beállítva. A mikrosekundum (TickMSC) szintű különbségek, a Spread hirtelen kitágulása és a Ping laggolása a legfőbb indikátorok, melyek alapján az ML eldönti, tiszta-e a brókeri kapcsolat.
