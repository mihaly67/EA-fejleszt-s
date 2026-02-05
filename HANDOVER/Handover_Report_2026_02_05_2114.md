# Handover Report - Project Merkava: Barbed Wire Migration & Logging
**Dátum:** 2026.02.05 21:14
**Tárgy:** CSV Naplózási Késleltetés Javítása (Handover)
**Címzett:** Commander (User) / Next Agent

## 🛑 Státusz
A **Mimic_Merkava_v1.05_BarbedWire** EA funkcionálisan kész (Panel, Logika, Indikátorok, Chart tisztítás), de a **naplózás pontossága** még nem éri el a megkövetelt "tick-by-tick" szintet a Custom Indikátorok (Hybrid Flow, Hybrid Pulse) esetében.

### 🔍 A Probléma
*   **Tünet:** A charton az indikátorok pörögnek (vizuálisan tickről tickre frissülnek), de a CSV fájlban az értékek akár 1 másodpercig is "beragadnak" (ismétlődnek), miközben az időbélyeg (ms) és az Ár/RSI változik.
*   **Diagnózis:** Hiába kényszerítettük az indikátorokat újraszámolásra (`limit=1`), az EA oldalon a `CopyBuffer` hívás valószínűleg a Metatrader belső optimalizált cache-éből olvas, ami nem frissül olyan agresszíven, mint a vizuális buffer. Az `iCustom` kommunikáció lassú/fojtott a nagysebességű (scalper) adatrögzítéshez.

## 🛠️ Következő Lépések (Utasítás)
A következő session feladata a **közvetlen számítási logika** implementálása, hogy megkerüljük a `CopyBuffer` késleltetését.

**Feladat:**
1.  **NavSystem.mqh Átírása:**
    *   Ne a `CopyBuffer`-re támaszkodjon az adatok kinyeréséhez (kivéve vizuális ellenőrzés).
    *   **Implementáld a logikát közvetlenül:** A `Hybrid Flow` (MFI, VROC, Delta) és `Hybrid Pulse` (MACD, DFCurve) matematikáját ültesd át a `NavSystem` osztályba.
    *   Használd a `SymbolInfoTick` és `iClose`/`iVolume` adatokat közvetlenül a számításhoz.
    *   Ez garantálja, hogy az EA minden egyes ticknél a legfrissebb bemeneti adatokból számol, késleltetés nélkül.

2.  **Architektúra:**
    *   Az `iCustom` indikátorok maradjanak meg a charton **kizárólag vizualizáció** céljából.
    *   Az adatokat a `BlackBox` számára a belső `NavSystem` kalkuláció szolgáltassa.

**Fájlok:**
*   `MQL5/Indicators/NavSystem.mqh` (Itt kell a matekot megírni).
*   `MQL5/Experts/Mimic_Merkava_v1.05_BarbedWire.mq5` (Tesztelés).

**Cél:**
A CSV minden sora egyedi, valós idejű számított értéket tartalmazzon a Hybrid indikátorokról is, szinkronban a tick ármozgással. Közben: user megfigyelése , 60 másodpercig ugyanaz az érték még CCI, RSI esetén is. Valószinú az 1 perces záró vagy nyitó értéke az. A Flow indikátornál 6 db számjegy csportot figyelt meg, gyanitása szerint 1 db ROC , a többi 4 az MFI és Delta. Ez utóbbi kettő olyan felbontásban hogy kölön van az 50 alatti és feletti érték mindkettő esetén. Ez lehet megváltoztatja részben a kutatás irányát. Flownál feleslegesnek tartja a 4 értéket Flow és delta mérésére. Tickenkénti értékirás kell nem nyitási vagy zárási érték másolásra , még iRSI és iCCI esetén is.
