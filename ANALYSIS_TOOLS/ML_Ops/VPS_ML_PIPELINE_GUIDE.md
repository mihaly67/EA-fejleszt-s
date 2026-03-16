# 🚀 Merkava Néma Színház - MLOps Pipeline Útmutató (VPS)

Ez a dokumentum a Merkava_Data_Miner_v1.0 által gyűjtött (pl. XAUUSD 5 napos tick) adathalmazok CPU-only, 8GB RAM limitált Ubuntu VPS környezetben történő feldolgozásához készült.

## 1. Könyvtárszerkezet a VPS-en
A VPS-en a munkakönyvtár neve Merkava_ML_Ops legyen. Hozd létre ezt a mappát, és másold be a repóban található ANALYSIS_TOOLS/ML_Ops mappa teljes tartalmát. A szerkezetnek pontosan így kell kinéznie:

Merkava_ML_Ops/
├── data/                    # IDE MÁSOLD a DataMiner CSV fájlokat (pl. XAUUSD_tick.csv)
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

## 2. Rendszerkövetelmények (Függőségek telepítése)
Mielőtt bármit futtatnál a VPS-en, frissítsd a Python környezeted a szükséges csomagokkal. Lépj be a munkakönyvtárba:

cd Merkava_ML_Ops/

Telepítsd a csomagokat:

pip install pandas numpy scikit-learn hmmlearn psutil pytest

## 3. Rendszer Tesztelése (Opcionális, de ajánlott)
Mielőtt ráengeded az 1GB+ XAUUSD fájlt a gépre, futtasd le a beépített Pytest szimulációt, amely megnézi, hogy a 8GB RAM-os DataLoader és a modellek megfelelően lettek-e importálva. (Az alábbi parancsban az export/PYTHONPATH elengedhetetlen, hogy a Python megtalálja a modulokat).

export PYTHONPATH=.
pytest tests/

Ha 100%-os zöld passed eredményt kapsz, a keretrendszer működik.

## 4. Futtatás a Nyers Adattal
Létrehozhatsz a Merkava_ML_Ops mappában egy egyszerű Python fájlt (pl. run_analysis.py néven), amivel betöltöd az adatot és elindítod a profilozást. Íme egy példa sablon a futtatáshoz (a "fájl_neve.csv" részt cseréld ki a saját adathalmazod nevére):

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

Futtatás a parancssorból a VPS-en:

python3 run_analysis.py

## 5. Mire kell figyelni? (Fontos)
* Memória Limits (OOM): A monitor.py modul bele van építve a data_loader.py-ba. Ha aVPS eléri a 90% RAM terhelést, a folyamat figyelmeztetést dob (KRITIKUS MEMÓRIA SZINT) és leállítja a további beolvasást, hogy megvédje a VPS-t az összeomlástól.
* Zaj és Nyers Adat: A HMM és az Isolation Forest modellek nyers adatra vágynak, ahogy kérted. Semmilyen elsimítás nincs beállítva. A mikrosekundum (TickMSC) szintű különbségek, a Spread hirtelen kitágulása és a Ping laggolása a legfőbb indikátorok, melyek alapján az ML eldönti, tiszta-e a brókeri kapcsolat.
