# SESSION HANDOVER V6 - MQL5 Source Code Sync (2026-06-17)

## KÖZVETLEN MÓDOSÍTÁSOK A GIT REPOSITÓRIUMBAN ÉS A VPS-EN
A code review megállapította, hogy bár a VPS-re sikeresen feltöltöttem a Data Miner v1.03 kódot, a helyi GitHub repozitórium nem kapta meg a forráskódot.

### 1. Data Miner EA (v1.03) Forráskód Csatolása
- Fájl hozzáadva a Git-hez: `MQL5/Experts/Merkava_Data_Miner_M1_v1_03.mq5`
- A script forráskódja immáron a verziókövetés részét képezi a helyi repóban. Tartalmazza:
    - Az M1 (1 perces) OHLCV adatkinyerési stratégiát a zajszűrés miatt.
    - A `CheckLoadHistory` kényszerített letöltő algoritmust (ami megoldja az MT5 3 hónapos cache limitjét, és letölti az 1 évet a szerverről).
    - A hibátlan `Refresh()` hívást egy felépített `MqlTick` struktúrával a korábbi lefordíthatatlan `UpdateHistorical` függvény helyett.

## KÖVETKEZŐ LÉPÉSEK
1. **Adatbányászat:** A VPS-en az MT5 terminálban (MetaEditor) le kell fordítani ezt a v1.03 fájlt. Győződj meg róla, hogy a "Max bars in chart" (Options -> Charts) legalább 500 000-re van állítva, hogy a kényszerített letöltés elférjen.
2. **Feature Generálás:** A kész CSV fájl az ML_Ops mappába kerülve mehet rá a Triple-Barrier python szkriptre a feature engineeringhez.
