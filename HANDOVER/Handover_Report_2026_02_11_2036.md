# Handover Report - 2026.02.12 01:45 - Merkava v2.15 (FINAL)
**Status:** ✅ **v2.15 Implemented, Tested & Ready**
**Previous Version:** v2.14 (Directional Attack)
**Current Version:** v2.15 (UI Update, Stats, Profit Management, Safety Margin)

## 🏆 Elért Eredmények (v2.15)
Ebben a session-ben jelentős fejlesztéseket hajtottunk végre a felhasználói felületen, a profit menedzsment logikán, és feltártunk egy kritikus bróker-specifikus korlátot.

### 1. Panel UI Fejlesztések (`PanelControl_v2_15.mqh`)
*   **Statisztikák Bővítése:**
    *   `Free Margin`: Szabad margin kijelzése.
    *   `Total P/L (Hist)`: Számlatörténeti tiszta kereskedési profit (befizetések nélkül).
    *   `Session P/L`: Aktuális munkamenet eredménye.
*   **Új Funkciók:**
    *   `Close Profit` Gomb: Azonnal lezár minden profitos pozíciót.
    *   `Virtual TP ($)` és `Virtual SL ($)` beviteli mezők: Valós idejű módosítással.
*   **Design:**
    *   Betűméret csökkentés (8pt) a Fire gomboknál.
    *   Panel magasság növelése (500px) a statisztikák számára.

### 2. Profit & Risk Management (`ProfitManagement_v2_15.mqh` & Main EA)
*   **Virtual TP/SL:**
    *   A rendszer minden tick-en ellenőrzi a pozíciókat.
    *   Ha `Profit >= Virtual TP` vagy `Profit <= -Virtual SL`, a pozíció zárásra kerül.
*   **Safety Margin (Biztonsági Korlát):**
    *   **Új Input:** `InpMaxMarginPercent` (Alapértelmezett: **70.0%**).
    *   **Logika:** Ha a `Used Margin / Equity` arány eléri a 70%-ot, az EA **letiltja** az új Grid indítását (`Fire` parancsok blokkolva).
    *   **Ok:** A tesztek során kiderült, hogy egyes brókerek (különösen HUF számlán vagy alacsony tőkeáttételnél) már 50% margin felhasználásnál ("No Money") tiltják a további pozíciókat. Ez a funkció segít elkerülni a "vakrepülést" és a függő megbízások bróker általi törlését.

### 3. Környezeti Stabilitás (`restore_env_TC.py`)
*   **Javított Szinkronizáció:** A script kiegészült egy `force_git_sync` funkcióval, ami automatikusan érzékeli a sérült `.git` állapotot, és szükség esetén újra inicializálja a repót, biztosítva a tökéletes szinkronizációt a távoli szerverrel.

## 📦 Fájlok Állapota
Az alábbi fájlok a `MQL5/Indicators/` könyvtárszerkezetben találhatók:

| Fájl | Leírás |
| :--- | :--- |
| `Jules/Merkava_v2_15.mq5` | Fő EA (Final), Safety Margin (70%), Virtual TP/SL. |
| `Indicators/PanelControl_v2_15.mqh` | UI, Stats, Close Profit, Inputs. |
| `Indicators/ProfitManagement_v2_15.mqh` | Virtual TP/SL, Close All Profit logika. |
| `Indicators/FireControl_v2_15.mqh` | v2.15 Verziókövetés. |
| `Indicators/Types_v2_15.mqh` | v2.15 Verziókövetés. |
| `ENVIRONMENT_SETUP/restore_env_TC.py` | Javított, robusztus restore script. |

## 📝 Teendők a Következő Session-ben (Next Steps - v2.16)
A következő fejlesztési ciklus (v2.16) fókuszpontjai már tisztázva vannak:
1.  **CSV Naplózás Bővítése:**
    *   +2 oszlop: EMA értékek (Fast/Slow).
    *   +6 oszlop: Pivot szintek (3 Pivot x Support/Resistance?).
    *   Összesen 8 új oszlop a `BlackBox` adatsorban.
2.  **Context Indikátor:**
    *   Integráció a rendszerbe (részletek a következő sessionben).

Köszönöm az együttműködést! A v2.15 stabil és használatra kész.
