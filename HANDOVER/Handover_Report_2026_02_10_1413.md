# Handover Report - 2026.02.10 14:13 (Stabil Merkava v2.11)
**Status:** ✅ **STABIL** (v2.11 - Dual Mode + Async Grid)

## 📌 Helyzetjelentés
Hosszú küzdelem árán stabilizáltuk a **Merkava v2.11**-et. A rendszer képes "Szögesdrót" (Barbed Wire) csapdát állítani Breakout (Stop) és Reversion (Limit) módban is. A geometria helyreállt (piaci széltől számol), az aszinkron mód miatt a végrehajtás azonnali, és a Kripto (nagy spread) validáció is működik.

### 🏆 Elért Eredmények (v2.11)
1.  **Dual Mode:** Kapcsolható stratégia a panelen (`Breakout` vs `Reversion`).
2.  **Geometria Fix:** A rácsot `Ask/Bid` bázisról számoljuk, nem középárról, így az 1. szint nem esik rá az árfolyamra.
3.  **Sebesség:** Aszinkron mód (`SetAsyncMode`) a `FireControl`-ban ("Carpet Bombing").
4.  **Panel:** Minden paraméter (Lot, Rétegek, Távolság, Mód) szerkeszthető futásidőben.

### 📂 Aktív Rendszerkomponensek
| Komponens | Fájl | Verzió | Leírás |
| :--- | :--- | :--- | :--- |
| **Expert Advisor** | `MQL5/Indicators/Jules/Merkava_v2_11.mq5` | **v2.11** | Stabil, Dual Mode EA. |
| **Fire Control** | `MQL5/Indicators/Indicators/FireControl_v2_11.mqh` | **v2.11** | Async Grid, Crypto Validáció. |
| **Egyéb** | `BlackBox_v2_05`, `NavSystem_v2_06` | - | Változatlan. |

## ⚠️ Következő Session Feladata (Módosított Terv)
A következő session **kizárólag** a "Burst Logika Bővítésével" (Éles Indítás) foglalkozik.

**Feladat: "Azonnali Tűz + Csapda" (Instant Entry + Grid)**
A jelenlegi logika csak várakozó (pending) megbízásokat tesz. Az új igény:
1.  **Első Lövés Éles (Market Order):** A gombnyomás pillanatában azonnal nyisson egy piaci pozíciót (Buy vagy Sell, a módtól függően).
2.  **Folytatás (Grid):** A többi szint (L2, L3...) maradjon várakozó (Stop/Limit), de a számításuk alapja az **Első Éles Pozíció Ára** legyen (vagy a piaci szél, de a reláció megmarad).
3.  **Távolság Logika:**
    *   1. (Éles) -> 2. (Pending): `Spread * 1.5` (Start Mult).
    *   2. -> 3. (Pending): `Spread * 1.0` (Step Mult).
4.  **Panel Kapcsoló:** Ki kell vezetni egy új kapcsolót: `ENTRY: PENDING` (Régi) vs `ENTRY: MARKET` (Új).

**Megjegyzés:** Ha ezzel megvagyunk, és marad idő, akkor jöhet az "Irányított Sorozatlövés" (Csak Buy / Csak Sell), de a prioritás az "Éles Indítás" beépítése a meglévő szimmetrikus rendszerbe.

**Tanulság:** A `CTrade` szinkron módja lassú hálókhoz; az aszinkron mód kötelező a "Burst" effekthez. A forward deklarációk az MQL5-ben veszélyesek lehetnek, jobb a függvényeket használat előtt definiálni.
