# Session Handover Jelentés: Merkava v2.36 & Stealth Registry v1.05

**Dátum:** 2026.02.17 22:20
**Státusz:** **Sikeres (Deep Randomization & Encoding Fix)**
**Verzió:** Merkava v2.36 (Stealth Registry Custom PRNG)

## 1. Vezetői Összefoglaló
A felhasználó "Active Monitoring" jeleket tapasztalt (az algoritmus ideges viselkedése) és jelezte, hogy a generált Magic Number-ek még mindig "clumping" (csoportosulás) jeleit mutatják, valamint a CSV logban "ismeretlen írásjelek" (kódolási hiba) vannak. Válaszul a `StealthRegistry`-t teljesen átírtuk: elhagytuk a Metatrader `MathRand()`-ot, és egy saját, nagy entrópiájú PRNG-t (LCG) implementáltunk, valamint szigorítottuk a fájlírási kódolást.

## 2. Megvalósított Javítások

### A. Stealth Registry v1.05 (`StealthRegistry.mqh`)
*   **Custom PRNG (LCG):** Saját lineáris kongruenciális generátor implementáció.
*   **High-Entropy Seed:** A seed-et a `GetMicrosecondCount()`, `TimeCurrent()`, `GetTickCount()`, `AccountInfoInteger(ACCOUNT_LOGIN)` és a `TicketCount` XOR kombinációjából képezzük. Ez garantálja, hogy soha nincs két azonos indítás.
*   **Kódolási Javítás:** A CSV fájlok explicit `FILE_ANSI` módban, de szigorúan ASCII karakterekkel (és `IntegerToString` konverzióval) íródnak, elkerülve a bináris szemetet és a "kínai karaktereket".
*   **Humanizált Magic:** A kimenet szigorúan 10,000 és 999,999 közötti egész szám.

### B. Merkava v2.36 (`Merkava_v2_36.mq5`)
*   **Verziófrissítés:** A kód átállt a v2.36 verziószámra.
*   **Panel Kijelzés:** A verzió string frissítve: `MERKAVA v2.36 (Deep Stealth)`.

### C. Teszt Script (`Test_StealthRegistry.mq5`)
*   **Validáció:** A script ellenőrzi a saját PRNG szórását.

## 3. Telepítési Útmutató
1.  **Törlés (Ajánlott):** Töröld a régi `MQL5/Files/Merkava_Stealth/Logs/*.csv` fájlokat, hogy tiszta lappal indulj (kódolás miatt).
2.  **Másolás:** A `Merkava_v2_36_Source.zip` tartalmát csomagold ki.
3.  **Fordítás:** Fordítsd le a `Merkava_v2_36.mq5`-öt és a `Test_StealthRegistry.mq5`-öt.
4.  **Teszt:** Futtasd a teszt scriptet. A kimeneten nagy eltérést ("High Variance") kell látnod a számok között.
5.  **Log Ellenőrzés:** Nyisd meg az új log fájlt. Most már olvasható szöveget és tiszta egész számokat kell látnod.

## 4. Fájlok (Artifacts)
*   `MQL5/Indicators/Jules/Merkava_v2_36.mq5`
*   `MQL5/Indicators/Indicators/StealthRegistry.mqh`
*   `MQL5/Indicators/Jules/Test_StealthRegistry.mq5`
