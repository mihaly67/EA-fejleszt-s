# 🕯️ VAKU 3.0 ML PIPELINE ÚTMUTATÓ (A "KÁLYHA")

Ez a dokumentáció tartalmazza a **Vaku 3.0 Állapotfelmérő (State Estimation)** rendszer offline Python csővezetékének (Pipeline) beállításait és futtatási logikáját.

A rendszer célja nem az idősoros árak jövőbeli jóslása (arra a klasszikus LSTM való), hanem az **"Állapotfelmérés" (Situational Awareness) a jelenben**. A cél kideríteni: a belépés pillanatában (illetve azt követően) egy tiszta trendben ("Betonfal") haladunk-e, vagy a bróker algoritmusa mesterségesen generált zajjal, SL vadászattal és kivéreztetéssel ("Színház/Manipuláció") reagált ránk.

---

## 1. ⚙️ FÜGGŐSÉGEK (DEPENDENCIES)

A VPS-en (vagy helyi gépeden) a legfrissebb kutatások alapján telepíteni kell a *Hidden Markov Model*-hez (HMM) szükséges csomagokat. Mivel a neurális hálóktól (TensorFlow/Keras) eltávolodtunk a Statisztikai Fizika (HMM, Welford) irányába, a gépigény töredékére csökkent.

Futtasd a terminálban:
`pip install pandas numpy scikit-learn hmmlearn`

---

## 2. 📂 A FÁJLOK ÉS A MUNKAFOLYAMAT (WORKFLOW)

Az adatokat két, egymásra épülő lépésben dolgozzuk fel. Szigorúan ebben a sorrendben kell futtatni őket!

### LÉPÉS 1: A Célváltozók Generálása (A "Kályha" Címkézője)
**Fájl:** `label_broker_reaction.py`

**Mit csinál?**
Ez a szkript utólag végigfut a historikus (MT5-ből kimentett) CSV tick adataidon. Megkeresi az összes belépési pontot (`PosCount` ugrás). Amint talál egy trade-et, megnézi a jövőbeli 1-10 ticket, és **kikeresi a "Brókeri Trükköket"**:
1. **Fake Breakout / Reversal:** 1-3 tickig kedvező irány, utána azonnal beszakad.
2. **SL Hunting / Whipsaw:** Extrém magas Max-Min volatilitás a 10 ticken belül az előző nyugalomhoz képest.
3. **Slow Bleed (Kivéreztetés):** Nincs rángatás, de az ár monoton elindul ellenünk (Adverse Excursion).
4. **Spread / Ping Tágítás:** Megugró spread vagy 1000+ ms lefagyás (Latency).

Ha ezek közül bármelyik jelen van, a trade-et (és az azt megelőző 10 ticket) **`TARGET = 1`** címkével (Bróker Reakció) látja el. Ha a piac békés, a címke **`0`**.

**Futtatás a VPS-en:**
```bash
PYTHONPATH=ANALYSIS_TOOLS/ML_Ops python3 ANALYSIS_TOOLS/ML_Ops/label_broker_reaction.py
```
**Kimenet:**
A `data/labeled/` mappában létrejönnek a `LABELED_*.csv` fájlok. Ezekben a fájlokban már ott van az "igazság" a brókeri gáncsolásokról.

---

### LÉPÉS 2: Az Unsupervised HMM és a "Smoking Gun" Bizonyíték
**Fájl:** `vaku3_offline_validator.py`

**Mit csinál?**
Ez a "Vaku 3.0" Szíve. Bemenetként a fenti (1. Lépésben) felcímkézett fájlokat várja. A HMM (Hidden Markov Model) teljesen vakon, a felcímkézett adatok (`TARGET`) ismerete nélkül dolgozik!

1. **Orthogonal Feature Space:** Kiszámolja a 3D vektorokat a nyers árak helyett: `Log-ER` (Kaufman Trend-tisztaság), `Relative Spread Elasticity`, és `Tick Density Residual`.
2. **Online Scaling:** A Welford-algoritmussal normalizálja a Tick Sűrűséget O(1) komplexitással, memóriatúlcsordulás (és Look-ahead bias) nélkül.
3. **Unsupervised Keresés (HMM):** Ráengedi a `GaussianHMM`-et a 3D adatokra. A gép magától osztja 3 "Rejtett Állapotra" a piacot.
4. **Semantic Mapping (Auto-Labeler):** A betanulás után a Python szkript megnézi a 3 klaszter (állapot) matematikai középértékeit. Amelyiknek a legkisebb az ER-je (hatékonyság) és a legnagyobb a Spreadje, azt automatikusan kinevezi a **"Színház" (Theater / Manipuláció)** állapotnak. Ami a leghatékonyabb (Magas ER), az a **"Betonfal" (Tiszta Trend)**. A maradék a **"Quiet" (Döglött)** piac.

**A "Smoking Gun" (Döntő Bizonyíték):**
A szkript legvégül összeveti az 1. lépésben tegnap készített (Emberi/Szabályalapú) `TARGET=1` címkéket a HMM által "vakon" megtalált `Színház` állapotokkal. Ha a HMM "Színházat" jelez azokon a területeken, ahol a bróker ténylegesen Rád Ugrott vagy Whipsaw-t csinált a trade-ben, akkor **bebonyosítottuk, hogy a Vaku 3.0 élőben is előre látja a manipulációt** a nyers árak nélkül, pusztán a zaj-fraktálokból!

**Futtatás a VPS-en:**
```bash
PYTHONPATH=ANALYSIS_TOOLS/ML_Ops python3 ANALYSIS_TOOLS/ML_Ops/vaku3_offline_validator.py
```
**Kimenet:**
A konzolon látni fogod a "Hit Rate"-et (Találati Arányt), ami megmondja, hányszor jelezte a gép helyesen a vihart a bróker beavatkozása előtt. A fájlok pedig `VAKU3_VALIDATED_` prefixszel mentődnek el, amiben már benne lesz a gép által tippelt Állapot (State) minden sorhoz.

---

## 3. 🎯 A JÖVŐ (MIKOR MEGYÜNK ÉLESBE?)

Ha az offline tesztelés (a Labeled CSV-ken futtatott Offline Validator) stabil és magas Hit Rate-et hoz a "Színház" állapotokra, a harmadik lépés a **Shared Memory (mmap) Bridge** megírása lesz az MT5 és a Python között.

Ott a fenti O(1)-es memóriakímélő Numpy RingBuffer-ek és a HMM egy végtelen `while` ciklusban fognak pörögni egy elszeparált CPU magon a VPS-en, és egy integer formájában (`0, 1, 2`) fogják másodpercenként 100-szor vissszaküldeni az MT5-ös Expert Advisor-nak a zöld/piros lámpát a belépések engedélyezésére vagy a Rejtett SL (Sakkjátszma) aktiválására.

*Üdvözlettel a Gépteremből: Jules & Gemini*