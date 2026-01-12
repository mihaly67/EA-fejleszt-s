# Kutatási Jelentés: DOM és Orderbook Implementáció

## Összefoglaló
Ez a jelentés a MQL5 "Depth of Market" (DOM) és "Orderbook" technológiák átfogó kutatását tartalmazza, különös tekintettel a brókeroldali adatkorlátok (pl. Admirals CFD) áthidalására. A kutatás során a "DoEasy" könyvtár és a "Cookbook" cikkek módszertanát elemeztük.

## Kulcsfontosságú Felfedezések

### 1. Adatstruktúra és Aszinkronitás
*   **Probléma:** A `Tick` események (`OnTick`) és a DOM események (`OnBookEvent`) aszinkron módon érkeznek. CFD-knél gyakori, hogy a Tick adatokban a `volume` vagy `volume_real` mező 0, vagy a flagek hiányoznak, miközben a DOM frissül.
*   **Megoldás (DoEasy Library):** A professzionális könyvtárak (pl. DoEasy) szétválasztják az adatgyűjtést (`CBook` osztály) és a jelfeldolgozást. Nem támaszkodnak kizárólag a Tick eseményre, hanem a DOM változásait (Best Bid/Ask mozgása) is "szintetikus tick"-ként kezelik.

### 2. Saját DOM Építése (Implementing Your Own Depth of Market)
*   **Módszertan:** A "Cookbook" cikkek azt javasolják, hogy ha a bróker nem ad megbízható DOM-ot (vagy az túl zajos/szimmetrikus), építsünk saját "virtuális" könyvet.
*   **Limiterek Becslése:** A tick adatokból (ha vannak flagek) visszafejthető, hogy hol voltak a limit megbízások.
*   **CFD Adaptáció:** Mivel a CFD DOM (Admirals) szimmetrikus és statikus volumenű (100, 200, 10000), a **volumen alapú elemzés helyett az Ár-alapú (Price Action) elemzésre kell áttérni**.

### 3. A "DoEasy" Megközelítés Lényege
*   **Abstract Request Class:** A DoEasy könyvtár absztrakt osztályokat használ a kérések és válaszok kezelésére, ami lehetővé teszi a különböző adatforrások (DOM, Tick, History) egységes kezelését.
*   **Tick Széria Frissítése:** A legfontosabb tanulság, hogy a hiányzó tickeket (pl. 0 volumen) a rendszernek "pótolnia" kell a DOM állapotváltozásai alapján. Ha a DOM Best Ask ára csökken, azt agresszív eladásként (Sell Tick) kell regisztrálni, még akkor is, ha az MT5 szerver nem küldött explicit `OnTick` eseményt kötésről.

## Alkalmazási Javaslat a Te Projektedhez

A kutatás alapján a jelenlegi "Admirals CFD" környezethez a következő stratégia a legmegfelelőbb (amit a v1.07-ben el is kezdtünk tervezni):

1.  **Hibrid Eseménykezelés:**
    *   Ne csak `OnTick`-re figyeljünk!
    *   Az `OnBookEvent`-et is használjuk "Tick Generátorként".
2.  **Szintetikus Tick Logika:**
    *   Ha `BestBid` > `Előző BestBid` -> **Vételi Nyomás (Buy Pressure)**.
    *   Ha `BestAsk` < `Előző BestAsk` -> **Eladói Nyomás (Sell Pressure)**.
3.  **Zajszűrés:**
    *   A 10,000-es "falak" kiszűrése (ahogy a v1.06-ban tettük) helyes lépés volt.
    *   A szimulációs pufferbe a DOM-ból származó jeleket is be kell vezetni.

## Következő Lépések (Kódolás előtt)
Mielőtt újra kódolnánk, érdemes tisztázni:
*   Szeretnéd-e a teljes "DoEasy" stílusú OOP struktúrát (ami bonyolultabb, de robusztusabb), vagy maradjunk a jelenlegi "könnyűsúlyú" indikátor megközelítésnél, de a fenti logikai javításokkal?
*   (Javaslatom: A könnyűsúlyú megközelítés a v1.07-ben elegendő és gyorsabb eredményt hoz.)

Ez a jelentés összefoglalja a kutatás eredményeit és a javasolt irányt.
