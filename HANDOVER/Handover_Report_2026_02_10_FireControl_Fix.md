# Handover Report - 2026.02.10 (FireControl Geometry Fix)
**Status:** ✅ **STABIL & VERIFIED** (v2.11)

## 📌 Elért Eredmények
Sikerült kijavítani a Merkava v2.11 kritikus geometriai és végrehajtási hibáit. A rendszer most már helyesen kezeli a sávos (Range) és kitörési (Breakout) logikát, még extrém körülmények (Crypto spread) között is.

### 1. Geometriai Javítás (Base Price Fix)
- **Hiba:** A rácsot a középártól (`(Ask+Bid)/2`) számítottuk. Ha a távolság kicsi volt, az első szint pont az árfolyamra esett.
- **Megoldás:** A bázis mostantól a **Piaci Szél** (`Tick.Ask` vagy `Tick.Bid`).
  - **Buy Stop:** `Ask + Distance` (Felfelé építkezik).
  - **Sell Stop:** `Bid - Distance` (Lefelé építkezik).
  - Így az 1. szint mindig `Distance` távolságra van a jelenlegi végrehajtási ártól.

### 2. Crypto / High-Spread Validáció
- **Hiba:** BTCUSD-nél a spread (1200 pont) miatt a `MinDist` (60 pont) alapján számolt Stop megbízás "belógott" a spreadbe (érvénytelen ár).
- **Megoldás:** `FireControl_v2_11.mqh` mostantól ellenőrzi a `SymbolInfoTick` alapján:
  - Ha `BuyStop <= Ask`, kényszeríti: `Price = Ask + Safety`.
  - Ha `SellStop >= Bid`, kényszeríti: `Price = Bid - Safety`.

### 3. Aszinkron Végrehajtás ("Carpet Bombing")
- **Hiba:** A "lépcsőzetes" felépülés időbeli csúszás volt a szinkron `CTrade` miatt.
- **Megoldás:** A `FireGrid` ciklusa alatt `m_trade.SetAsyncMode(true)` aktív. A megbízások mikroszekundumok alatt kimennek.

### 4. GUI és Dual Mode
- **Panel:** A Módválasztó gomb ("MODE: BREAKOUT") betűmérete csökkentve, szövege rövidítve.
- **Dual Mode:** Kapcsolható a `Stop` (Breakout) és `Limit` (Reversion) logika.

## ⚠️ Következő Lépések (Roadmap - Következő Session)
A felhasználó kérése alapján a következő fejlesztés a **"Sorozatlövés" (Directional Burst)** és a **Panel Kimaxolása**.

1.  **Irányított Sorozatlövés:**
    - Külön `FIRE BUY` és `FIRE SELL` gombok.
    - Csak egy irányba építi fel a hálót (nem szimmetrikus csapda).
    - Kapcsolható: `Single` (1 db) vagy `Burst` (Sorozat).
2.  **Panel Bővítés:**
    - Vízszintes elválasztó vonal a "Szögesdrót" (Grid) és "Sorozatlövés" (Burst) között.
    - Új beviteli mezők a sorozathoz (Darab, Távolság).
3.  **Info Szekció:**
    - Valós `PL`, `Balance`, `Margin %` kijelzése.
4.  **UX:**
    - `[+]` / `[-]` gombok a beviteli mezők mellett (Spin Edit) az egér alapú gyors állításhoz.

**Fájlok:**
- `MQL5/Indicators/Jules/Merkava_v2_11.mq5` (Aktív EA)
- `MQL5/Indicators/Indicators/FireControl_v2_11.mqh` (Aktív Logika)
