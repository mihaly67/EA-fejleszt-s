# Viselkedési Profilozó (Behavioral Profiler) - Használati Útmutató

Ez az útmutató bemutatja, hogyan kell használni a `Merkava_Behavioral_Profiler_v1.1.mq5` által kimentett kereskedési adatokat a Python alapú LSTM hálózattal, hogy vakteszteléssel (Blind Test) derítsük ki a bróker manipulációit.

## 1. Miért itt van a futtató script?
A `run_behavioral_profiler.py` szándékosan az `ANALYSIS_TOOLS/ML_Ops/` főkönyvtárba került, és **nem** a `models/` mappába.
Ennek az az oka, hogy a `models/` mappa csak a "nyers" AI definíciókat (az "agyakat", pl. maga az LSTM osztály) tartalmazza. A főkönyvtárban lévő scriptek viszont a **csővezetékek (Pipelines)**, amik összekötik az adatbetöltőt (`data_loader`), az AI modelleket (`models/`), és a fájlkezelést.

## 2. Hova másold az MQL5 CSV fájlokat?
Amikor a MetaTrader 5-ben lefuttatod a `Merkava_Behavioral_Profiler_v1.1.mq5` EA-t (akár több különböző instrumentumon, pl. EURUSD, GBPUSD), a generált `.csv` fájlokat (amiket a `BlackBox_v2_10` készít) ebbe a mappába kell bemásolnod a VPS-en:

📂 **Ide másold a nyers fájlokat:**
`ANALYSIS_TOOLS/ML_Ops/data/`

*Példa:*
`ANALYSIS_TOOLS/ML_Ops/data/BlackBox_EURUSD_20260317.csv`
`ANALYSIS_TOOLS/ML_Ops/data/BlackBox_GBPUSD_20260317.csv`

## 3. Hogyan indítsd el a Profilozást?
Lépj be az ML_Ops mappába, és futtasd a scriptet. A script **automatikusan** megtalálja az összes CSV-t a `data/` mappában, és mindegyiken egyenként lefuttatja a betanítást és az elemzést.

```bash
cd ANALYSIS_TOOLS/ML_Ops/
python3 run_behavioral_profiler.py
```

## 4. Hol találod az eredményeket (Összevetés)?
Amint a script lefutott egy fájlon, az eredményt **nem** írja felül, hanem létrehoz egy új mappát és abba menti az elemzett, kiegészített CSV-t.

📂 **Itt találod a kész eredményeket:**
`ANALYSIS_TOOLS/ML_Ops/data/analyzed/`

*Példa:*
`ANALYSIS_TOOLS/ML_Ops/data/analyzed/ANALYZED_BlackBox_EURUSD_20260317.csv`

## 5. Hogyan értelmezd az "Összevetést"?
Nyisd meg az `ANALYZED_...` kezdetű fájlt (Excelben vagy Pandas-szal).
1. A táblázat **elején** és **közepén** ott lesznek a te eredeti adataid (pl. `Balance`, `PosCount`, `LotDir`, `Session_PL`). Ezeket az AI **sosem látta**.
2. A táblázat **legvégén** ott lesz két új oszlop:
   - `LSTM_Reconstruction_Error`: A hiba mértéke (minél nagyobb, annál furcsább a piac).
   - `LSTM_Anomaly`: **1** = Normál piac, **-1** = Bróker Manipuláció ("Színész").

**A Döntő Kérdés:** Keresd meg azokat a sorokat, ahol te pozíciót nyitottál (pl. `PosCount` megváltozik, `Trade_Action` stb.), és nézd meg, hogy közvetlenül előtte vagy utána az `LSTM_Anomaly` átvált-e **-1**-re. Ha igen, akkor a bróker a te viselkedésedre reagálva tágítja a spreadet vagy manipulálja az árat!
