# Broker Algorithm Analysis Report (EurUSD Stress Test)

## 🎯 Célkitűzés
A bróker oldali algoritmus viselkedésének feltérképezése extrém terhelés (100 Lot-os sorozatos kötések) alatt. A cél annak megállapítása, hogy a "Trójai Faló" (zajkeltés közbeni valódi kötés) stratégia életképes-e.

## 📊 Eredmények (Számok Tükrében)

Az elemzés 3 fázist vizsgált:
1.  **Baseline:** 0.01 Lot (Normál üzem)
2.  **Low Load:** 0.01 Lot (Kontroll)
3.  **Stress:** 100 Lot (Támadás)

| Metrika | Baseline (Fázis 1) | Stress (Fázis 3) | Változás |
| :--- | :--- | :--- | :--- |
| **Végrehajtási Idő** | 2881 ms | 1705 ms | **Gyorsult (nem lassult!)** |
| **Likviditás (Összes)** | 67.5M | 59.3M | -12% (Stabil) |
| **Spoofing Ratio** | 74x | 85x | **+15% (Mélyebb falak)** |
| **Árfolyam Drift** | -8 pont | +26 pont | **Jelentős elmozdulás** |

## 🧠 Az Algoritmus Logikája ("A Pszichológia")

A teszt alapján a bróker algoritmusa egy **"Rugalmas Védekezés" (Elastic Defense)** modellt követ.

1.  **Nem Omlik Össze:** A rendszer nem lassult be a terheléstől, sőt, a szerverek hatékonyan kezelték a megnövekedett forgalmat. A technikai "Lag" generálása (mint elterelő hadművelet) **nem működött**.
2.  **Nem Falaz (Azonnal):** Nem próbálta meg fix áron tartani a szintet ("Jegelés"). Ehelyett hagyta, hogy a vételi nyomásunk feljebb tolja az árat (+26 pont). Ezzel a kockázatot ránk hárította (drágábban vettünk).
3.  **Mélyre Épít:** A likviditást nem vonta ki (csak -12%), de áthelyezte a mélyebb szintekre (Level 2-5). A legjobb ár (Level 1) vékony maradt, de mögötte vastag falak nőttek (Spoofing Ratio 85x). Ez a klasszikus "Csalogató" viselkedés: látszólag van ár, de nagy tételnél csak rosszabb átlagáron teljesülsz.

## ⚔️ Konklúzió: A "Trójai Faló" Stratégia

A kérdés: *"Ha közben tényleg becsempésznék egy trójait... foglalkozna vele?"*

**VÁLASZ: IGEN, de a "Zaj" miatt átcsúszhat.**

A bróker algoritmusa a **Flow (Áramlás) kezelésére** van optimalizálva, nem az egyedi kötések vadászatára. Amikor a 100 Lot-os "roham" zajlik:
*   Az algoritmus azzal van elfoglalva, hogy a likviditást átcsoportosítsa (Level 1 -> Level 5).
*   Az árfolyamot csúsztatja (Drift).

Ebben a dinamikus környezetben egy **egyetlen, irányba álló (Trendkövető)** pozíció "zajnak" minősül. Nem azért, mert a szerver túlterhelt, hanem mert a kockázatkezelő algoritmus a *nagy* kitettséget (a 100 Lotokat) próbálja fedezni/továbbítani. Egy kisebb, de valódi "trójai" pozíció ebben a fedezeti áramlásban (Hedging Flow) elrejtőzhet.

**Javaslat a folytatásra:**
A stratégiát nem a "Bróker Túlterhelésére" (DDoS jellegű lassítás), hanem a **"Fedezeti Áramlásba Rejtőzésre"** kell építeni. Amikor a "csali" elindítja az árfolyamot (Drift), a "katona" azonnal ugorjon fel a vonatra.
