# SESSION HANDOVER: OPERATION "NÉMA SZÍNHÁZ" (BEHAVIORAL PROFILING & MLOps)

**Date:** 2026.03.07 (Estimated)
**Status:** Irányváltás sikeres (Network Sniffing -> AI Profiling). Az infrastruktúra áll, de a Flow indikátor adatokat tisztítani kell.
**Baseline Version:** `Merkava_Behavioral_Profiler.mq5` (v2.40 alapokon, Stealth nélkül)

## 1. Műveleti Összefoglaló (A Stratégiai Pivot)
A hálózati rétegen történő beavatkozást (eBPF TCP tűzfal, Frida Secur32.dll plaintext olvasás) hivatalosan felfüggesztettük. A MetaTrader egyedi, zárt titkosítást használ, így vakon dobálni telemetria csomagokat életveszélyes lenne az éles kereskedésre (Watchdog/Heartbeat trigger).
Ehelyett áttértünk a **Behavioral Profiling** (Viselkedés alapú profilozás) stratégiára. A bróker nem szakadhat el a világpiaci áraktól (mert arbitrázs alakulna ki), így egy mesterséges "csatornában" kénytelen trükközni (Lag/Ping növelés, Spread tágítás, tüske-generálás).

Ezt egy külső AI (FinRL / Scikit-learn) fogja kielemezni és megtanulni.

## 2. Elért Eredmények (Mit hagyok hátra)
*   **Merkava Behavioral Profiler (MQL5):** A `v2.40`-ből kiindulva eltávolítottunk *minden* álcázást (StealthEngine, Registry, dummy tickek). Ez a verzió őszintén, védtelenül fut, hogy a bróker kényelmesen vesse be a trükkjeit.
*   **BlackBox_v2_09 Kiterjesztés:** A CSV logolás immár tartalmazza a nyers `Ping_MS`-t és kijavítottuk a valós `BidVol`/`AskVol` mentését (egy korábbi ulong-long típus hiba is javítva lett). A momentum indikátort eltávolítottuk, helyette `EMA_25`, `EMA_50`, és `EMA_150` került be.
*   **Python AI Pipeline:** A `ANALYSIS_TOOLS/ML_Ops/anomaly_detector.py` elkészült. Egy `IsolationForest` (Unsupervised ML) modellel figyeli a CSV-t, és dinamikusan párosítja az oszlopneveket (TimeMsc/TickMSC), hogy kiszűrje az "anomáliákat" (Lag tüskék, hirtelen spread tágulások).

## 3. NYITOTT PROBLÉMA A KÖVETKEZŐ ÜGYNÖKNEK (Kritikus!)
A felhasználó jelentette, hogy a `Flow_MFI` érték a CSV-ben továbbra is nulla. Az előző körben megpróbáltam a `NavSystem_v2_20.mqh` osztályt ráerőltetni a natív `iMFI`-re, de a felhasználó szerint **ez nem jó út**, mert a charton látható Hibrid Flow indikátor pontos értékeit akarja látni a CSV-ben.

**A Feladatod:**
1.  **Indikátor Tisztítása:** Keresd meg a `HybridFlowIndicator` forráskódját (valószínűleg `HybridFlowIndicator_v1.125.mq5`). Jelenleg zavaros, mert 4 puffert használ (2 pozitív, 2 negatív a színezések miatt).
2.  **Puffer Redukció:** Alakítsd át úgy, hogy szigorúan **CSAK 3 PUFFERT** használjon, amiket könnyű leolvasni a `CopyBuffer`-rel az EA oldaláról:
    *   **Puffer 0 (MFI Görbe):** Pozitív és Negatív értékeket is tartalmazzon.
    *   **Puffer 1 (Delta Hisztogram):** Pozitív és Negatív értékek egy helyen.
    *   **Puffer 2 (ROC):** Rate of Change.
3.  **NavSystem Javítása:** Miután az indikátor letisztult, kösd be az EA-ba (`NavSystem_v2_20.mqh`), hogy a `GetFlowMFI()`, `GetFlowDelta()` és `GetFlowROC()` funkciók a `CopyBuffer`-rel ezt a 3 tiszta puffert olvassák ki, és adják át a `BlackBox` loggernek.

*Ha az AI "zavaros", 4-pufferes vizuális adatokat kap a CSV-ben (amiből az egyik mindig nulla), akkor félre fogja tanulni a piacot. A tisztaság most mindennél fontosabb!*

**Jules (Távozó Terepügynök)**
