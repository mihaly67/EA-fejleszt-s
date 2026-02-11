# Handover Report - 2026.02.11 Merkava v2.14 Plan (Directional Attack)
**Status:** ⚠️ **PENDING** (Git Conflict - Code Attached)

## 📌 Helyzetjelentés
A v2.13 -> v2.14 fejlesztés során kritikus Git konfliktus lépett fel a "távoli" (Github) és "helyi" (Sandbox) repók között, ami megakadályozta a `push` műveletet.
A konfliktus feloldása érdekében a fejlesztett kódokat **ebben a ZIP fájlban** adjuk át, hogy a következő session-ben tiszta lappal (Clean Start) lehessen őket integrálni.

### 🏆 Elért Fejlesztések (v2.14)
A kódban (ami a ZIP-ben található) a következő funkciók **már implementálva vannak**:

1.  **Irányított Támadás (Directional Attack):**
    *   `FireControl_v2_14.mqh`: A `FireGrid` függvény mostantól fogad egy `ENUM_ATTACK_DIR` paramétert (`ATTACK_BOTH`, `ATTACK_BUY`, `ATTACK_SELL`).
    *   A logika képes szűrni a megbízásokat irány szerint (pl. `ATTACK_BUY` esetén csak Buy Stop/Limit megbízásokat helyez el).
2.  **Kétoszlopos Panel (Split Layout):**
    *   `PanelControl_v2_14.mqh`: A panel szélessége 320px-re nőtt.
    *   **Bal Oszlop:** A régi v2.13 vezérlők (Beállítások, FIRE TRAP, CEASE FIRE).
    *   **Jobb Oszlop:** Új gombok:
        *   `FIRE BUY` (Erdőzöld)
        *   `FIRE SELL` (Téglavörös)
3.  **Teljes Logika Megőrzése:**
    *   `Merkava_v2_14.mq5`: A v2.13 teljes logikáját (PhysicsEngine, BlackBox, Deal History) átmásoltuk, és kiegészítettük az új eseményekkel (`EVENT_FIRE_BUY`, `EVENT_FIRE_SELL`).

### 📦 Csatolt Fájlok (Merkava_v2_14_Source.zip)
A `HANDOVER` mappában található `Merkava_v2_14_Source.zip` tartalmazza:
*   `Merkava_v2_14.mq5` (Fő EA)
*   `FireControl_v2_14.mqh` (Irányított logika)
*   `PanelControl_v2_14.mqh` (Split Panel)
*   `Types_v2_14.mqh` (Új Enum-ok)

### 📝 Teendők a Következő Session-ben
1.  **Környezet Helyreállítása:** `restore_env_TC.py` futtatása (vagy tiszta `git pull origin main`).
2.  **Fájlok Kibontása:** A `Merkava_v2_14_Source.zip` tartalmát be kell másolni a megfelelő helyekre:
    *   `.mq5` -> `MQL5/Indicators/Jules/`
    *   `.mqh` -> `MQL5/Indicators/Indicators/`
3.  **Beküldés (Submit):** Mivel a fájlok már készen vannak, csak egy "Add & Commit" szükséges egy friss ágon.

**Ez a módszer megkerüli a jelenlegi git szinkronizációs hibát.**
