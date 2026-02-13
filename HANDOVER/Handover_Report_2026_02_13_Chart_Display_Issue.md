# Handover Report - 2026.02.13 - Merkava v2.16 (Unresolved Charting Issue)

**Status:** ❌ **Chart Display Issue UNRESOLVED**
**Action:** Investigation Required in Next Session
**Current State:** v2.16 Restored, Original ZigZag Restored (Patched)

## 🚨 A Probléma Összefoglalása
A `Merkava_v2_16` EA futtatásakor a `HybridContextIndicator_v3.17` (és annak ZigZag vonalai) **NEM jelennek meg a charton**.

### Tények és Megfigyelések
1.  **Indikátor Önmagában:** Ha a felhasználó manuálisan húzza rá a chartra a `HybridContextIndicator_v3.17`-et, az **tökéletesen működik**, megtalálja a `ZigZag`-ot és kirajzolja a szinteket.
2.  **EA Futtatása:** Ha az EA (`Merkava`) próbálja feltenni (`NavSystem::AttachToChart`), az indikátor **nem látszik**.
3.  **ZigZag Állapota:**
    *   Az eredeti (felhasználó által biztosított) `ZigZag.mq5` vissza lett állítva.
    *   Bár a napló korábban `array out of range` hibát jelzett (amit javítottunk biztonsági ellenőrzéssel), a javítás után **sem** jelenik meg az indikátor az EA alatt.
4.  **Konklúzió:** A ZigZag indikátor önmagában működőképes. A hiba forrása **NEM a ZigZag kódjában** van, hanem abban, ahogy az EA (`NavSystem`) inicializálja, paraméterezi vagy a chartra illeszti ("Attach") a Context indikátort.

## 🛠️ Téves Feltételezések (Debunked Theories)
*   *Téves:* A ZigZag kódja hibás/inkompatibilis. -> **Cáfolva:** Önmagában működik.
*   *Téves:* Hiányzó fájl. -> **Cáfolva:** Minden fájl a helyén van.
*   *Téves:* "Fekete négyzetek" hiba. -> **Megoldva:** Ez csak az átmeneti (rossz) standard ZigZag miatt volt.

## 📋 Feladatok a Következő Session-re
**Cél:** Megtalálni, miért nem sikerül a `NavSystem`-nek megjelenítenie a működő indikátort.

1.  **NavSystem Debug:**
    *   Újra beépíteni a részletes diagnosztikát (`Print` logok).
    *   Ellenőrizni a `ChartIndicatorAdd` visszatérési értékét és a `GetLastError()` kódját.
    *   Ellenőrizni, hogy a `m_handle_context` érvényes-e (`INVALID_HANDLE`?).

2.  **Paraméterátadás Vizsgálata:**
    *   Összehasonlítani az EA által átadott paramétereket az indikátor alapértelmezett értékeivel. Lehet, hogy egy specifikus paraméterkombináció (amit az EA kényszerít) "láthatatlanná" teszi az indikátort, vagy hibát okoz a logikában (pl. `InpShowPivots` véletlen felülírása?).

3.  **Chart ID és Ablak Index:**
    *   Biztosítani, hogy a `chart_id` (általában 0) és a `subwindow` (0) helyes-e az EA futása közben (pl. Strategy Tester vs. Live Chart).

## 📦 Fájlok Állapota
*   `MQL5/Indicators/Examples/ZigZag.mq5`: Eredeti (felhasználói), biztonsági patch-el ellátva.
*   `MQL5/Indicators/Jules/HybridContextIndicator_v3.17.mq5`: Eredeti v2.16 backupból.
*   `Merkava` és könyvtárak: v2.16 backupból helyreállítva.
