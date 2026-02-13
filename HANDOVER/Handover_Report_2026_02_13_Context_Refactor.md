# Handover Report - 2026.02.13 - Context Indicator Refactor (Critical)

**Status:** ⚠️ **Working with Patch (v2.16)** / 🛠️ **Refactor Required (v3.18)**
**Action:** High Priority Task for Next Session
**Current State:**
*   **EA (`Merkava_v2_16`):** Patched.
    *   Default inputs synchronized with `HybridContextIndicator_v3.17` (Micro: 3/5/3, etc.).
    *   `input group` removed to fix parameter alignment bugs.
    *   Fibo features disabled (Inputs removed).
*   **Library (`NavSystem_v2_08`):** Patched.
    *   Debug logging added to verify parameters.
    *   Fibo parameters hardcoded to `false/0` in `iCustom` call.
*   **Indicator (`ZigZag.mq5`):** Patched.
    *   Added bounds check (`if(shift-back < 0) continue;`) to prevent `array out of range` crash.
*   **Indicator (`HybridContextIndicator_v3.17`):** ❌ **NOT Self-Contained.**
    *   Analysis confirmed it calls `iCustom("Examples\\ZigZag")` internally. This dependency causes instability when the EA passes parameters.

## 🚀 Feladat a Következő Session-re (Next Steps)

**Cél:** Létrehozni a **`HybridContextIndicator_v3.18.mq5`** verziót, amely **teljesen önálló (Self-Contained)**, és nem függ külső indikátoroktól.

### 1. ZigZag Logika Beépítése (Embedding)
*   **Létrehozás:** Másold le a v3.17-et v3.18 néven.
*   **Kódolás:**
    *   Töröld az `OnInit`-ből az `iCustom` hívásokat (`micro_zz_handle`, `sec_zz_handle`, `ter_zz_handle`).
    *   Implementáld a ZigZag számítási logikáját (High/Low keresés, Backstep) **közvetlenül a `HybridContextIndicator` kódjába**.
    *   Mivel 3 különböző beállítás (Micro, Sec, Ter) fut párhuzamosan, javasolt egy `CalculateZigZagState` függvény vagy osztály használata, hogy ne kelljen 3-szor leírni a kódot.
*   **Adatforrás:** A `CopyBuffer` helyett a belső számítás eredményeit (tömböket) használd a `FindHistoricResistance` és `FindHistoricSupport` függvényekben.

### 2. EA Frissítése
*   Módosítsd a `Merkava_v2_16.mq5`-ben (vagy v2.17-ben) az `InpContextPath` alapértelmezett értékét:
    *   `"Jules\\HybridContextIndicator_v3.18"`

### 3. Tesztelés
*   Ellenőrizd, hogy az indikátor önállóan (EA nélkül) is helyesen működik-e a charton.
*   Ellenőrizd, hogy az EA alatt is megjelenik-e, és a szintek helyesek-e (nem feketék/láthatatlanok).

---
**Megjegyzés:** Ez a refaktorálás elengedhetetlen a rendszer hosszú távú stabilitásához. A külső `iCustom` hívások (főleg az `Examples` mappából) verzióütközéseket és rejtett hibákat okoznak.
