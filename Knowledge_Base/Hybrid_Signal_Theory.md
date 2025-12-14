# Hybrid Scalper Rendszer - Elméleti Alapok és Logika (v3.0)

## 1. Működési Filozófia: "Zajmentes Gyorsaság"

A Scalper stratégia célja, hogy a 2 perces (M2) időablakban azonnal reagáljon az árváltozásokra ("OnTick"), de ne csapja be a piaci zaj (mikro-kilengések).

### A Hármas Szabály:
1.  **Zajszűrés:** Nem minden tick számít. A 10 másodperces mintavételezés (Sampling) vagy a Tick-átlagolás jobb, mint a nyers adatfolyam.
2.  **Késésmentesség (ZeroLag):** A hagyományos MA-k (SMA, EMA) késnek. A DEMA (Double EMA) vagy ALMA (Arnaud Legoux MA) sokkal gyorsabb.
3.  **Dinamikus Normalizálás:** A "fix 50 pont" nem működik, mert a volatilitás változik. A jel erősségét a szótáshoz (Volatility / StdDev) kell mérni.

---

## 2. Jelgenerálás Lépései (Signal Pipeline)

### A. Bemenet és Mintavételezés (Input & Decimation)
Ahelyett, hogy minden tickre számolnánk (ami CPU igényes és zajos), egy "Time-Based Sampler"-t alkalmazunk.
*   **Logika:** Csak akkor frissítünk, ha eltelt `N` másodperc (pl. 10 sec) az utolsó számítás óta.
*   **Előny:** Természetes aluláteresztő szűrőként viselkedik, kiszedi a "jitter"-t.

### B. Szűrés és Detrending (The Filter)
A nyers árból (Close) kivonjuk a zajt és a fő trendet, hogy megkapjuk a tiszta mozgást (Oszcillátor).
*   **Eszköz:** DEMA (Gyors) vagy ALMA (Sima).
*   **Oszcillátor Képzés:** `Signal_Raw = Price - Filter(Price)`
    *   Ez egy "Detrended" jel, ami a 0 vonal körül ingadozik.

### C. Dinamikus Normalizálás (Z-Score)
A `Signal_Raw` értéke pontokban van (pl. 0.00050 vagy 50 pont). Ezt nem lehet fixen IFT-zni.
*   **Megoldás:** Bollinger-elv (Szórás alapú skálázás).
*   **Kiszámítjuk:** `Sigma = StdDev(Signal_Raw, Period)`
*   **Normalizált Jel:** `Z_Score = Signal_Raw / (Sigma * Factor)`
    *   Így a jel mindig kb. -1 és +1 között lesz, függetlenül attól, hogy a piac épp őrjöng vagy alszik.

### D. Inverse Fisher Transform (IFT) - A "Meggyőződés"
A Z-Score még mindig lineáris. Az IFT egy "S" alakú görbét (Sigmoid) húz rá.
*   **Cél:** A kis zajokat elnyomni (0 közelében tartani), a valódi elmozdulásokat pedig gyorsan "kifeszíteni" a szélsőértékekre (+1 / -1).
*   **Képlet:** `IFT(x) = (e^(2x) - 1) / (e^(2x) + 1)`
*   **Hatás:** "Digitálisabbá" teszi a jelet. Vagy Veszünk, vagy Eladunk, vagy Semmi. Nincs "langyos" zóna.

---

## 3. MTF vs. Single Timeframe
A v3.0 verzióban a **Single Timeframe** megközelítést javasoljuk, mivel a dinamikus normalizálás (C pont) önmagában is képes adaptálódni a trendhez. Az MTF gyakran csak késleltetést visz a rendszerbe ("Lag"), ami scalpingnál végzetes.

## 4. Összegzés (A Kódolás Iránya)
A `Hybrid_Scalper_v3.mq5` a következő láncot valósítja meg:
`Tick -> Sampler (10s) -> DEMA Filter -> Z-Score Normalizálás -> IFT -> Trade Signal`
