# Merkava Stealth Stratégia: Emberi Viselkedés és Álcázás (v1.0)

**Dátum:** 2026.02.16
**Cél:** Az algoritmikus kereskedési viselkedés álcázása "emberi" jellegűvé, hogy megtévesszük a brókerek profilozó rendszereit.
**Alapelv:** "A tökéletes végrehajtás gyanús. Az emberek rendetlenek, lassúak és következetlenek."

---

## 1. MQL5 Natív Megvalósítás (1. Fázis - Azonnali)
*Ezek a funkciók közvetlenül a `StealthEngine.mqh`-ban valósíthatók meg külső függőségek nélkül.*

### A. Időbeli Ingadozás (Anti-Machine Timing)
*   **Koncepció:** Az algoritmikus megbízások gyakran kiszámítható időközönként érkeznek (pl. pontosan 0 ms-mal a tick után). Az embereknek reakcióidejük van (200 ms - 1500 ms).
*   **Megvalósítás:**
    *   `Sleep()` használata Gauss-eloszlással (Átlag: 400 ms, Szórás: 150 ms).
    *   **Véletlenszerű Újrajegyzés (Re-quotes):** Néha utasítsunk el egy érvényes jelet ("habozás" szimulálása).
    *   **Munkamenet Fáradtság:** A kereskedési munkamenet előrehaladtával növeljük kissé a késleltetéseket ("fáradtság" szimulálása).

### B. Árfolyam Zaj (Anti-Clustering)
*   **Koncepció:** A tömeg viselkedése a kerek számoknál (pszichológiai szintek) csoportosítja az SL/TP-t. Az algoritmusok ezekre vadásznak. Ahhoz, hogy "emberek, de okosak" legyünk, kerülnünk kell a tökéletes matematikai szinteket.
*   **Megvalósítás:**
    *   **Mikro-Pip Zaj:** Adjunk hozzá/vonjunk ki `MathRand()` értéket (pl. +/- 1-5 pont) a számított Belépési/SL/TP árakhoz.
    *   **"Fat Finger" (Kövér Ujj) Szimuláció (Alacsony Valószínűség):** 0.1% esély arra, hogy kissé rosszabb áron lépjünk be (csúszás szimulálása) vagy kissé eltérő lotmérettel (pl. 0.10 helyett 0.11).

### C. Metaadat Obfuszkáció (Álcázás)
*   **Koncepció:** A brókerek a `MagicNumber` és az `OrderComment` alapján profilozzák a stratégiákat.
*   **Megvalósítás:**
    *   **Dinamikus Magic Számok:** Alap ID + véletlenszerű eltolás munkamenetenként (gondos nyomon követést igényel). *Kockázat: bonyolítja a kereskedés kezelését.*
    *   **Emberi Megjegyzések:** Váltogassunk egy listáról "emberi" megjegyzéseket (pl. "", "kezi", "hir", "t1", "teszt"). **Soha** ne használjuk a "Merkava_v2.30" nevet.

---

## 2. Python Híd Integráció (2. Fázis - Haladó)
*Szükséges a komplex ML viselkedéshez vagy GUI spoofinghoz. Az `EXT_THIEFS`-ben található `dwx-zeromq-connector` mintát használja.*

### A. Architektúra: ZeroMQ Híd
*   **Mechanizmus:** Az MQL5 "buta" végrehajtó terminálként működik. A Python futtatja az "agyat".
*   **Könyvtárak:**
    *   **MQL5:** `ZeroMQ_MT4.mqh` (MT5-re adaptálva).
    *   **Python:** `pyzmq`, `pandas`, `FinRL` (döntési logikához).

### B. GUI Spoofing (Végső Álcázás)
*   **Koncepció:** Az MQL5 `OrderSend` API teljes megkerülése. A bróker egérkattintásokat lát a terminál gombjain, nem API hívásokat.
*   **Eszközök:** `pyautogui` (megtalálható az `EXT_THIEFS`-ben), `selenium-stealth` (kevésbé releváns asztali alkalmazáshoz).
*   **Munkafolyamat:**
    1.  A Python elemzi a piaci adatokat.
    2.  A Python kiszámítja a kereskedést.
    3.  A Python a `pyautogui` segítségével az egérkurzort az MT5 terminál ablakának "Vétel" gombjára mozgatja.
    4.  A Python kattint.
    *   **Előnyök:** Megkülönböztethetetlen a kézi kereskedéstől.
    *   **Hátrányok:** Magas késleltetés, törékeny (az ablak pozíciója számít), blokkolja a felhasználót a PC használatában.

### C. Viselkedés Klónozás (ML)
*   **Koncepció:** LSTM/Transformer modell betanítása (pl. `FinRL` vagy `nautilus_trader` segítségével) a *tényleges* kézi kereskedési előzményeken, hogy megtanulja az "emberi" mintákat (pl. bosszúkereskedés, pozícióépítés).
*   **Megvalósítás:** A Python modell megjósolja egy kereskedés "Emberi Valószínűségét". Az MQL5 csak akkor hajt végre, ha a valószínűség > küszöbérték.

---

## 3. Megvalósítási Ütemterv

### 1. Lépés: `StealthEngine.mqh` (Jelenlegi Feladat)
*   [x] `GetHumanDelay()` (ApplyHumanDelay): Gauss-eloszlású véletlen alvás.
*   [x] `GetFuzzyPrice(price)`: Mikro-pip zaj hozzáadása.
*   [x] `GetHumanComment()`: Véletlenszerű kiválasztás listából.

### 2. Lépés: EA Integráció
*   [ ] Az `OrderSend` hívások burkolása a `Merkava_v2.31`-ben a `StealthEngine` metódusaival.
*   [ ] Bemeneti Paraméterek Hozzáadása: `bool EnableStealth`, `int MaxDelayMS`.

### 3. Lépés: Python Híd (Jövőbeli)
*   [ ] `dwx-zeromq-connector` beállítása.
*   [ ] Python `Strategic_Command.py` szkript felépítése.
