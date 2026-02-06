# Handover Report - Project Merkava: Stealth & Precision Phase
**Dátum:** 2026.02.06 18:06
**Tárgy:** Zero Latency Hitelesítve - Következő: Tizedesjegyek & Teljes Álcázás (Stealth)
**Címzett:** Commander (User) / Next Agent

## 🛑 Státusz: SIKER (VERIFIED)
A mai session során **validáltuk** a rendszer működését. A felhasználó által küldött CSV teszt (`Mimic_Merkava_GOLD_v1.05_BW_DirectCalc_20260206_174251.csv`) elemzése igazolta, hogy:
1.  **Zero Latency:** Nincs többé adatberagadás. Az árak és indikátorok tickről tickre frissülnek.
2.  **PL Számítás:** A `Realized`, `Session` és `Floating` PL számítások logikailag helyesek és pontosan követik a számlaegyenleg változását.
3.  **CCI Eltávolítva:** A kérésnek megfelelően a CCI oszlop és logika kikerült.

---

## 🚀 KÖVETKEZŐ SESSION TERV (UTASÍTÁS)

A következő fejlesztési ciklus a **Pontosság** és a **Láthatatlanság (Stealth)** jegyében zajlik. A cél a bróker algoritmusainak megtévesztése ("Zavaros legyen").

### 1. Feladat: Tizedesjegyek Beállítása (PRIORITÁS #1)
*   **Cél:** A CSV naplóban minden indikátor értéknek meghatározott pontossággal kell szerepelnie a zajszűrés és olvashatóság érdekében.
*   **Teendő:**
    *   `BlackBox.mqh` `StringFormat` maszkjainak frissítése.
    *   Javasolt: RSI (2 tizedes), MACD (5 tizedes), Flow Delta (2 tizedes).

### 2. Feladat: "Camouflage" (Álcázás) Fejlesztése
A `Camouflage.mqh` modult jelentősen bővíteni kell az alábbi **Counter-Intelligence** funkciókkal:

*   **Magic Number Randomizálás:** Minden indításkor új, véletlenszerű Magic Number generálása (vagy egy tartományból választás).
*   **Spread Target "Jitter" (Remegtetés):**
    *   A fix `1.5x` Spread szorzó helyett egy véletlenszerű tartomány (pl. `1.42` - `1.58`) használata minden lövésnél.
    *   Ez megakadályozza, hogy a bróker statisztikailag felismerje a fix távolságú csapdákat.
*   **Grid Step "Chaos":**
    *   A fix `1.0x` lépésköz helyett véletlenszerű eltérések (pl. `0.95` - `1.05`).
*   **Aszimmetria (Tükörkép Megszüntetése):**
    *   A Long és Short oldali hálók ne legyenek tökéletes tükörképei egymásnak. Eltérő távolságok és méretek alkalmazása.
*   **Signature Spoofing (Lenyomat Hamisítás):**
    *   A Pending Order-ek elhelyezésekor apró, véletlenszerű késleltetések vagy árfolyam-eltolások (offset) alkalmazása.
    *   **Cél:** "Egy se legyen olyan, hogy egyforma lenyomat legyen."

### 3. Kutatási Feladat (Thief & Colombo)
*   **Forrás:** Vizsgáld meg a `Knowledge_Base` könyvtárakat (Thief's Library - Hummingbot/VectorBT és Colombo).
*   **Kérdés:** Milyen technikákat használnak a HFT és Market Maker algoritmusok a detektálás elkerülésére? (Pl. Order book "flickering", randomizált execution time).
*   **Implementáció:** Ültesd át ezeket az elveket a `Camouflage` és `FireControl` modulokba.

### 💂 Könyvtár Strukturális Javaslat
Hozz létre egy új mappát a fejlesztéshez, ha a logika túl bonyolulttá válik:
*   `MQL5/Indicators/Stealth_Systems/` (Ide kerülhetnek a fejlett randomizáló algoritmusok).

**Összegzés:** A rendszer motorikusan kész. Most a páncélzatot és az álcahálót kell rátennünk.

*"A legjobb álcázás az, ha az ellenség azt hiszi, csak a szél fújja a leveleket."*
