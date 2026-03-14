# ML PIPELINE SPECIFICATION (HMM & AUTOENCODER)

**Author:** Jules (Data Engineer)
**Target:** ML Ops Agent (Next Session)
**Environment:** Ubuntu VPS (3 Cores, 8GB RAM, NO CUDA)
**Dataset:** MT5 Extracted Tick Data (CSV, ~1GB+ size)

## 1. A Feladat Célja (The Objective)
A `Merkava_Data_Miner` többmillió soros CSV fájlokat állít elő az élő MetaTrader piacról (nyers tickek, spread változások és folyamatosan rögzített indikátor értékek formájában).
A következő ágens feladata egy **Felügyelet Nélküli (Unsupervised) Gépi Tanulási Pipeline** megépítése Pythonban (Pandas, Scikit-learn, hmmlearn), amely azonosítja a brókeri "rezsimeket" (market states) és a mesterséges anomáliákat (pl. pillanatnyi spread tágítások, price feed megakadások).

## 2. Hardveres és Memória Korlátok (Hardware Constraints)
A célgép egy 8GB RAM-mal rendelkező VPS, GPU gyorsítás nélkül.
*   **Tiltott megoldások:** Kiterjedt, mély neurális hálózatok (Deep LSTM) egyben történő memóriába töltése (Out of Memory Error-hoz vezet).
*   **Kötelező megoldások:** A CSV-t kötelező a már megírt `ANALYSIS_TOOLS/ML_Ops/data_loader_demo.py` alapján, **Chunking** módszerrel (pl. 100,000 soronként) és a `usecols` paraméterrel beolvasni.
*   A számlaadatokat és Pivotokat a betöltéskor el kell dobni, csak az árat (`Bid`, `Ask`), a likviditást (`Spread`, `Volume`), a fizikát (`Velocity`) és az indikátorokat (`EMA`, `MFI`, `MACD`) szabad megtartani az *Observation Space*-ben.

## 3. Modellezési Irányelvek (Modeling Guidelines)

A következő ágensnek az alábbi két modellt kell megírnia (vagy tesztelnie):

### A) Rejtett Markov-Modell (HMM) - Rezsim Detektálás
A piac sosem homogén. A HMM célja, hogy megtalálja a piac rejtett állapotait (Hidden States).
1.  **Szűrés / Preprocessing:** Alakítsd át a nyers árakat "Log Returns"-re (százalékos elmozdulás). A spreadet normalizáld (Z-Score).
2.  **HMM Építés:** Használd a `hmmlearn.GaussianHMM` osztályt.
3.  **Állapotok (States):** Próbálj meg beállítani $N=2$ vagy $N=3$ állapotot. (Pl. 0 = Normál alacsony volatilitású piac, 1 = Magas volatilitás, 2 = "Toxikus" / Manipulált spread rezsim).
4.  **Bemenet:** A HMM csak a *Log Returns*, a *Spread* és a *Velocity* (esetleg MFI delta) vektorokat kapja meg (mert a HMM érzékeny a túl sok dimenzióra).

### B) LSTM-Autoencoder / Isolation Forest - Anomália Detektálás
Ez a modell a "színészkedő" (manipulált) árfolyam-vibrációk megtalálására szolgál a zajos adatokból. (Lásd: `Gemini_ML_Research_Summary.md`)
1.  **Dimenziócsökkentés:** Mivel CUDA nincs, a mély LSTM Autoencoder helyett egy Scikit-Learn **Isolation Forest** vagy egy sekély, CPU-ra optimalizált Autoencoder javasolt.
2.  **Detektálás módja:** A modell tanulja meg a normális tick-ingadozásokat és indikátor-követést. Amikor a rekonstrukciós hiba (Reconstruction Error / MSE) hirtelen megnő, a script jelezzen be egy anomáliát (pl. `IS_ANOMALY = True`).

## 4. Elvárt Kimenet (Expected Output)
Az ML Ágensnek egy olyan Python scriptet (`anomaly_profiler.py` vagy egy `.ipynb` notebookot) kell a repóba tennie, amely:
1. Betölti az adatokat chunk-okban.
2. Lefuttatja a HMM / Autoencoder illesztést (fit).
3. Egy új oszlopként rácsatolja a CSV adatokra a felfedezett **Rejtett Állapotot (State)** és az **Anomália pontszámot (Anomaly Score)**.
4. (Opcionális) Matplotlib / Seaborn segítségével kigenerál egy grafikont, ami a "Toxikus" szakaszokat pirossal kiszínezi az árfolyamon.