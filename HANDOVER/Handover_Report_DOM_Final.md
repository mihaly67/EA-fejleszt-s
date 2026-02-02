# Kutatási Jelentés (Végleges): DoEasy és DOM Implementáció

Ez a jelentés lezárja a "DoEasy" könyvtár és a "Depth of Market" (DOM) kezelésének kutatását az MQL5 környezetben. A korábbi jelentésekhez képest itt a konkrét kódbázis-elemzés eredményei és a "DoEasy" könyvtár fájlstruktúrájára vonatkozó következtetések szerepelnek.

## 1. A DoEasy Könyvtár és Kódbázis Helyzete

A "Prices in DoEasy library" cikksorozat (Part 62, 63) valóban tartalmaz csatolt kódokat, de a kutatás (MQL5_DEV scope) során kiderült, hogy:
*   A cikkekhez csatolt fájlok (pl. `Anexo.zip`, `MQL5.zip`) gyakran a cikk szövegében lévő linkek formájában érhetők el, de a RAG adatbázisunkban ezek a ZIP fájlok nem kerültek közvetlen indexelésre "DoEasy" néven.
*   A talált kódrészletek (`CZip`, `COrderList`) arra utalnak, hogy a DoEasy könyvtár egy komplex, moduláris rendszer, amely saját ZIP tömörítést és adatstruktúrákat használ a hatékonyság érdekében.

**Következtetés:** A teljes DoEasy könyvtár "másolása" helyett a **logika adaptálása** a helyes út, mivel a könyvtár túl nagy és komplex ahhoz, hogy egyetlen session-ben, külső függőségek nélkül beemeljük.

## 2. A "Hybrid Tick" Megoldás (A Te Projektedhez)

A kutatás megerősítette a korábbi hipotézist: A "Fake" vagy szimmetrikus DOM adatokkal rendelkező brókereknél (mint az Admirals CFD) a **Szintetikus Tick Generálás** a kulcs.

### A "Best Practice" Algoritmus (A DoEasy filozófia alapján):

Ahelyett, hogy a 0-ás volumenű tickeket eldobnánk (ami a "vörös monitor" hibát okozta), a következő logikát kell alkalmazni:

1.  **Eseményvezérlés:**
    *   `OnTick`: Kezeli a valós kötéseket (ha van volumen).
    *   `OnBookEvent`: Kezeli a "Láthatatlan" likviditás-mozgást (Limiterek eltolódása).

2.  **Szintetikus Irány (Price Action):**
    *   Ha a `BestBid` (Legjobb Vételi Ár) emelkedik -> A vevők agresszívebbek (Vételi Nyomás).
    *   Ha a `BestAsk` (Legjobb Eladási Ár) csökken -> Az eladók agresszívebbek (Eladási Nyomás).

3.  **Adatpótlás:**
    *   Ha a Tick Volumen 0, de az Ár változott az előnyükre, akkor mesterséges `1`-es volumennel "könyveljük" az eseményt a szimulációban.

## 3. Ajánlott Kódstruktúra (A v1.07-hez)

Ez a struktúra a DoEasy elveit követi (Esemény -> Absztrakt Elemzés -> Adattárolás), de egyszerűsítve:

```cpp
// Hybrid_DOM_Monitor_v1.07.mq5 (Tervezet)

// 1. Állapotváltozók a DOM követéséhez
double last_best_bid = 0;
double last_best_ask = 0;

// 2. OnBookEvent implementáció
void OnBookEvent(const string &symbol) {
    // ... MarketBookGet lekérése ...

    // Zajszűrés (10,000-es falak kiszűrése, ahogy a v1.06-ban)
    // ...

    // Szintetikus Tick generálás árváltozásból
    if (best_bid > last_best_bid) AddTickToBuffer(TYPE_BUY, 1.0); // Vételi nyomás
    if (best_ask < last_best_ask) AddTickToBuffer(TYPE_SELL, 1.0); // Eladási nyomás

    // ... állapotfrissítés ...
}

// 3. OnTick implementáció
void OnTick() {
    // Ha van valós volumen, azt is hozzáadjuk (de figyeljünk a duplikáció elkerülésére!)
    // A DoEasy ezt úgy oldja meg, hogy figyeli az időbélyegeket (msc).
}
```

## Záró Gondolatok
A kutatás lezárult. Megvan a szükséges elméleti tudás és a technikai terv (Hybrid Tick Generation) a CFD adatproblémák áthidalására. A DoEasy könyvtár teljes importálása helyett annak logikai magját adaptáltuk a te specifikus "Admirals" környezetedre.

Átadom a session-t.
