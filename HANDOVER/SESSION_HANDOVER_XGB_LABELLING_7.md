# SESSION HANDOVER V7 - Data Miner Script Update (2026-06-17)

## KÖZVETLEN MÓDOSÍTÁSOK A GIT REPOSITÓRIUMBAN ÉS A VPS-EN
A code review megállapította, hogy bár a VPS-re sikeresen feltöltöttem a Data Miner v1.04 kódot, a helyi GitHub repozitórium nem kapta meg a legújabb *Script* forráskódot, hanem benne maradt a működésképtelen Expert Advisor verzió (v1.03).

### 1. Data Miner EA (v1.03) Törlése
- Fájl törölve a Git-ből: `MQL5/Experts/Merkava_Data_Miner_M1_v1_03.mq5`

### 2. Data Miner Script (v1.04) Forráskód Csatolása
- Fájl hozzáadva a Git-hez: `MQL5/Scripts/Merkava_Data_Miner_Script_v1_04.mq5`
- Az új, Script-típusú MQL5 fájl (amelyet a MetaTrader-ben a *Scripts* fülről kell indítani) immáron a verziókövetés része. Tartalmazza:
    - Az M1 (1 perces) OHLCV adatkinyerési stratégiát.
    - A `CheckLoadHistory` kényszerített letöltő algoritmust (ami megoldja az MT5 3 hónapos cache limitjét, aszinkron blokkolás és fagyás nélkül).
    - A BlackBox logolást a Triple-Barrier feature engineering python kód számára.

## KÖVETKEZŐ LÉPÉSEK
1. **Adatbányászat:** A VPS-en az MT5 terminálban (MetaEditor) a *Scripts* (Szkriptek) mappából nyisd meg és fordítsd le a `Merkava_Data_Miner_Script_v1_04.mq5` fájlt. Húzd rá a chartra az adatletöltés elindításához.
