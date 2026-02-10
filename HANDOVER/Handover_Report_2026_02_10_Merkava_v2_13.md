# Handover Report - 2026.02.10 Merkava v2.13 (Instant Entry & Panel Refactor)
**Status:** ✅ **STABIL** (v2.13)

## 📌 Helyzetjelentés
A mai session során sikeresen implementáltuk a "Symmetric Instant Entry" (Azonnali Szimmetrikus Belépés) funkciót, és refaktoráltuk a felhasználói felület (UI) kódját egy külön könyvtárba. A rendszer immár v2.13 verziószámon fut.

### 🏆 Elért Eredmények (v2.13)
1.  **Instant Entry (Burst Mode):**
    *   Új kapcsoló a panelen: `ENTRY: PENDING` (Csapda) vs `ENTRY: MARKET` (Azonnali).
    *   **Market Mód:** A "FIRE GRID" gomb megnyomásakor az 1. szint azonnal nyit egy Buy és egy Sell pozíciót (Hedge) piaci áron.
    *   A rács többi eleme (L2, L3...) várakozó megbízásként (Pending) kerül elhelyezésre, a megfelelő geometriai távolságra a piaci széltől.
2.  **UI Refaktorálás (PanelControl):**
    *   A panel logikája (gombok, mezők, eseménykezelés) átkerült a `PanelControl_v2_13.mqh` könyvtárba.
    *   Ez tisztábbá teszi a fő EA fájlt (`Merkava_v2_13.mq5`).
3.  **Architektúra Javítás (Types):**
    *   Létrehoztunk egy `Types_v2_13.mqh` fájlt a közös Enum-ok (`ENUM_FIRE_MODE`, `ENUM_ENTRY_MODE`) tárolására, elkerülve a körkörös függőségeket.
4.  **Technikai Javítások:**
    *   **Pointer Szintaxis:** A környezeti sajátosságok miatt a `CTrade` és `CSymbolInfo` pointereket **pont (.) operátorral** érjük el a nyíl (`->`) helyett a `FireControl`-ban.
    *   **Hedge Ellenőrzés:** Az EA induláskor figyelmeztet, ha nem Hedging típusú számlán fut (mivel az Instant Entry hedge-t igényel).

### 📂 Aktív Rendszerkomponensek (v2.13)
| Komponens | Fájl | Verzió | Leírás |
| :--- | :--- | :--- | :--- |
| **Expert Advisor** | `MQL5/Indicators/Jules/Merkava_v2_13.mq5` | **v2.13** | Fő EA, PanelControl integrációval. |
| **Fire Control** | `MQL5/Indicators/Indicators/FireControl_v2_13.mqh` | **v2.13** | Instant Entry logika, dot syntax fix. |
| **Panel Control** | `MQL5/Indicators/Indicators/PanelControl_v2_13.mqh` | **v2.13** | UI logika és eseménykezelés. |
| **Types** | `MQL5/Indicators/Indicators/Types_v2_13.mqh` | **v2.13** | Közös definíciók. |
| **Egyéb** | `NavSystem_v2_06`, `BlackBox_v2_05` | - | Változatlan. |

### ⚠️ Ismert Korlátok / Figyelmeztetések
*   **Netting Számla:** Az "Instant Entry" mód (Market Buy + Market Sell) Netting számlán azonnali zárást eredményezhet (vagy csak a különbözetet nyitja). A rendszer ezt jelzi a logban, de nem tiltja le.
*   **Szintaxis:** A `FireControl` könyvtárban a pointerek eléréséhez a **pont (.)** operátort kell használni ebben a fejlesztői környezetben. A szabványos C++ nyíl (`->`) fordítási hibát okoz.

### 📝 Következő Lépések (Javaslat)
*   **Tesztelés:** Az új v2.13-as verzió éles tesztelése (Demo számlán), különös tekintettel az Instant Entry sebességére és a rács pontos elhelyezésére.
*   **Irányított Burst:** A jövőben a `MARKET` mód kiegészíthető lenne irányított (Csak Buy / Csak Sell) opcióval is.

### 🔄 Előző Verzió (v2.12)
A v2.12-es verzió "monolitikus" (Panel könyvtár nélküli) változata vissza lett állítva és biztonsági tartalékként szolgál, de a fejlesztés a v2.13 ágon folytatódik.
