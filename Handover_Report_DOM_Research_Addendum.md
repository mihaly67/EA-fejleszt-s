# Kutatási Jelentés Bővítése: DOM Kódbázis és Implementációs Minták

Ez a kiegészítés a korábbi `Handover_Report_DOM_Research.md` jelentéshez tartozik, és a `CODE` adatbázisban végzett kutatás eredményeit összegzi.

## Eredmények a Kódbázisból (CODE Scope)

Sajnos a `DoEasy` könyvtár teljes forráskódja vagy a `CBook` osztály komplex implementációja **nem található meg** közvetlenül a jelenlegi `CODE` adatbázisban (Knowledge Base). A keresések (`DoEasy MarketBook`, `CBook`) főleg általános kereskedési scripteket (`FetchNews`, `SampleDetectEconomicCalendar`) vagy alapvető segédosztályokat (`BinFlags`, `BasicList`) adtak vissza, amelyek nem tartalmazzák a keresett DOM logikát.

### Következtetés a Hiányzó Kódról
A "DoEasy" könyvtár valószínűleg egy külső, nagy terjedelmű projekt (a cikkek szerzője által publikálva), amely nem része a standard MQL5 példatárnak, amit a rendszer indexelt.

## Javasolt "Hybrid" Implementáció (A kutatás alapján rekonstruálva)

Bár a kész kód nincs meg, a cikkek elméleti leírása és a MQL5 dokumentáció alapján rekonstruáltam a **Szintetikus Tick Generálás** logikáját, amit a projektedben alkalmazhatunk.

### A "Hybrid Tick" Algoritmus (Best Practice)

Ezt a logikát érdemes beépíteni a `UpdateSimulation` függvénybe (ahogy a v1.07 tervében szerepel):

```cpp
// Állapotváltozók (statikus vagy globális)
static double last_best_bid = 0;
static double last_best_ask = 0;

void OnBookEvent(const string &symbol)
{
   MqlBookInfo book[];
   if(!MarketBookGet(symbol, book)) return;

   // 1. Best Bid/Ask meghatározása
   // (Feltételezve, hogy a tömb rendezett, és a spread a közepén vagy a szélein van - ezt a Scannerrel már láttuk:
   // Admiralsnál: Index 2 = Sell (Low), Index 3 = Buy (High) -> Ez a Best Ask és Best Bid!)

   // Indexek a korábbi log alapján (6 soros könyv):
   // Sell: [0]=High ... [2]=Low (Best Ask)
   // Buy:  [3]=High (Best Bid) ... [5]=Low

   double best_ask = book[2].price;
   double best_bid = book[3].price;

   // 2. Változás Detektálása (Szintetikus Tick)
   int synth_direction = 0;

   // Ha a Vevők feljebb léptek (Best Bid Nőtt) -> Agresszív Vétel (Buy Pressure)
   if(best_bid > last_best_bid && last_best_bid > 0)
   {
      synth_direction = 1; // BUY
   }

   // Ha az Eladók lejjebb léptek (Best Ask Csökkent) -> Agresszív Eladás (Sell Pressure)
   if(best_ask < last_best_ask && last_best_ask > 0)
   {
      synth_direction = -1; // SELL
   }

   // Frissítés
   last_best_bid = best_bid;
   last_best_ask = best_ask;

   // 3. Betáplálás a Szimulációba
   if(synth_direction != 0)
   {
      // Mesterséges Tick létrehozása
      MqlTick synth_tick;
      synth_tick.time = TimeCurrent();
      synth_tick.volume_real = 1.0; // Súlyozás
      synth_tick.flags = (synth_direction == 1) ? TICK_FLAG_BUY : TICK_FLAG_SELL;

      UpdateSimulation(synth_tick); // Ugyanaz a fv, amit az OnTick is hív!
   }
}
```

### Miért ez a megoldás a nyerő?
1.  **Független a Tick Eseménytől:** Akkor is generál jelet, ha az MT5 szerver "elfelejt" `OnTick`-et küldeni a spread változásról (ami CFD-nél gyakori).
2.  **Price Action Alapú:** Nem a volumeneket nézi (amik 300 vs 300 egyensúlyban vannak), hanem a **szándékot** (hova mozdult a limit).
3.  **Zajszűrt:** Csak a legjobb árakat figyeli (Index 2 és 3), így a 10,000-es külső falak nem zavarnak be.

## Összegzés
A kutatás megerősítette, hogy a "gyári" kódok helyett egy **egyedi, bróker-specifikus (Admirals) logikát** kell implementálnunk, amely a DOM ármozgását fordítja le kereskedési nyomássá. A fenti kódrészlet ennek a technikai alapja.
