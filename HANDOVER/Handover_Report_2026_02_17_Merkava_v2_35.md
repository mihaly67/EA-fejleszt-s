# Session Handover Jelentés: Merkava v2.35 & Stealth Registry v1.04

**Dátum:** 2026.02.17 22:05
**Státusz:** **Sikeres (Deep Randomization)**
**Verzió:** Merkava v2.35 (Deep Random Stealth)

## 1. Vezetői Összefoglaló
A felhasználó jelezte, hogy a generált véletlenszámok egymás utáni híváskor túlságosan hasonlítanak (`1216746626` -> csak az utolsó számjegyek változnak). Ez a `MathRand()` lineáris természetéből és a statikus seedelésből fakadt. A `StealthRegistry` v1.04-es verziójában bevezettük a **Deep Randomization** technikát, amely mikroszekundum alapú dinamikus újraseedeléssel és XOR keveréssel biztosítja a számok nagy szórását.

## 2. Megvalósított Javítások

### A. Stealth Registry v1.04 (`StealthRegistry.mqh`)
*   **Dinamikus Seed:** Minden `GetRandomMagic()` hívás elején meghívjuk a `MathSrand((int)GetMicrosecondCount())`-ot. Mivel a mikroszekundum számláló rendkívül gyorsan pörög, két egymást követő hívás garantáltan más seed-et kap.
*   **XOR Keverés:** Két külön `MathRand()` hívást kombinálunk bitenkénti XOR művelettel (`r1 << 15 ^ r2`), ami tovább növeli az entrópistát és megtöri a lineáris mintázatokat.
*   **Humanizált Tartomány:** A kimenet továbbra is szigorúan `10,000` és `999,999` közötti egész szám.

### B. Merkava v2.35 (`Merkava_v2_35.mq5`)
*   **Verziófrissítés:** A kód átállt a v2.35 verziószámra.
*   **Panel Kijelzés:** A verzió string frissítve: `MERKAVA v2.35 (Deep Stealth)`.

### C. Teszt Script (`Test_StealthRegistry.mq5`)
*   **Validáció:** A script mostantól nem csak a tartományt, hanem a **szórást (variance)** is ellenőrzi. Ha két egymást követő szám különbsége kisebb mint 5000, figyelmeztetést ad (bár a javítással ez szinte lehetetlen).

## 3. Telepítési Útmutató
1.  **Másolás:** A `Merkava_v2_35_Source.zip` tartalmát csomagold ki a megfelelő helyre (`MQL5/Indicators/`).
2.  **Fordítás:** Fordítsd le a `Merkava_v2_35.mq5` fájlt és a `Test_StealthRegistry.mq5` scriptet.
3.  **Teszt:** Futtasd a `Test_StealthRegistry` scriptet. A kimeneten látnod kell: `PASS: Variance ... OK`.

## 4. Fájlok (Artifacts)
*   `MQL5/Indicators/Jules/Merkava_v2_35.mq5`
*   `MQL5/Indicators/Indicators/StealthRegistry.mqh`
*   `MQL5/Indicators/Jules/Test_StealthRegistry.mq5`
