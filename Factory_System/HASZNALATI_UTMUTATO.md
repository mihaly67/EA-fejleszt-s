# HASZNÁLATI ÚTMUTATÓ - Hybrid Rendszer (Factory System)

Ez a dokumentum lépésről lépésre leírja, hogyan kell telepíteni, lefordítani és elindítani a Hybrid Kereskedelmi Rendszert a MetaTrader 5 környezetben.

## 1. Telepítés (Fájlok Másolása)

A `Factory_System` mappa tartalmát a MetaTrader 5 Adatkönyvtárába (`File -> Open Data Folder`) kell másolni a következő szerkezet szerint:

### A) Indikátorok
Másold a `Factory_System/Indicators/*.mq5` fájlokat ide:
`MQL5/Indicators/Showcase_Indicators/`
*(Fontos: Hozd létre a `Showcase_Indicators` almappát, ha nem létezik! Az EA kódja ezt az útvonalat keresi.)*

Fájlok:
*   `HybridMomentumIndicator_v2.3.mq5`
*   `HybridFlowIndicator_v1.7.mq5`
*   `HybridContextIndicator_v2.2.mq5`
*   `HybridWVFIndicator_v1.3.mq5`
*   `HybridInstitutionalIndicator_v1.0.mq5`

### B) Expert Advisor (Az EA)
Másold a `Factory_System/Experts/Hybrid_System_EA.mq5` fájlt ide:
`MQL5/Experts/Hybrid/`
*(Hozd létre a `Hybrid` almappát a rend kedvéért.)*

### C) Include Könyvtárak (A logika)
Másold a `Factory_System/Include` tartalmát (`Hybrid` és `Profit_Management` mappák) ide:
`MQL5/Include/`

Végeredmény:
*   `MQL5/Include/Hybrid/Hybrid_Signal_Aggregator.mqh`
*   `MQL5/Include/Hybrid/Hybrid_Panel.mqh`
*   `MQL5/Include/Hybrid/Hybrid_TradingAgent.mqh`
*   `MQL5/Include/Profit_Management/RiskManager.mqh` (és a többi...)

## 2. Fordítás (Compile)

Nyisd meg a MetaEditor-t (F4), és fordítsd le a fájlokat az alábbi sorrendben (F7 gomb):

1.  **Indikátorok:** Fordítsd le mind az 5 indikátort a `Showcase_Indicators` mappában. (Fontos, hogy létrejöjjenek az `.ex5` fájlok, mert az EA ezeket tölti be).
2.  **Expert Advisor:** Nyisd meg a `Hybrid_System_EA.mq5`-t és fordítsd le. A "0 errors" az elvárt eredmény.

## 3. Futtatás és Tesztelés

1.  Húzd rá a `Hybrid_System_EA`-t egy chartra (pl. EURUSD M1).
2.  A bal felső sarokban meg kell jelennie a **Hybrid Panelnek**.
3.  **Dashboard Fül:** Látsz számokat (Score) és színes jelzéseket? Ez jelenti, hogy az "Agy" működik.
4.  **Trade Fül:**
    *   Próbáld ki a **Lots (0=Auto)** funkciót: Írj be `0.0`-t, és nyomj **BUY**-t. A rendszer a beállított Kockázat (1% Margin Risk) alapján számol pozícióméretet.
    *   Az SL/TP szintek a `RiskManager` és a piaci volatilitás alapján ellenőrzésre kerülnek.

## 4. Hibaelhárítás

*   **"Failed to initialize Hybrid Brain!":** Ellenőrizd, hogy az indikátorok (`.ex5`) valóban az `MQL5/Indicators/Showcase_Indicators/` mappában vannak-e.
*   **"RiskManager rejected trade":** Lehet, hogy túl nagy a kockázat (Margin > 70%), vagy nincs elég tőke. Nézd meg a "Journal" (Napló) fület a részletekért.

---
_Készítette: Jules Agent, 2024-12-20_
