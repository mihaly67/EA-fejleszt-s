# SESSION HANDOVER V2 - Data Miner Fixes (2026-06-17)

## KÖZVETLEN MÓDOSÍTÁSOK A VPS-EN
Az utolsó körben kizárólag a Data Miner EA javítására fókuszáltunk, ahogy az ICA és az MLOps előírja.

### 1. Data Miner EA Javítása és M1 Átállás
- Fájl a VPS-en: `/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Indicators/Jules/Merkava_Data_Miner_M1_v1_02.mq5`
- A korábbi tick-alapú adatbányászatot **M1 (1 perces gyertya) OHLCV adatokra** cseréltük, ami kritikus a zajszűrés miatt az ML modelleknél.
- Javítottuk a "undeclared identifier 'UpdateHistorical'" és a paraméter ("t") fordítási hibát. Az EA most már megfelelően felépít egy `MqlTick` struktúrát (dummy_tick) a `CopyRates` adatokból (time, bid, ask, last, volume értékekkel), és az elérhető `m_nav_system.Refresh(_Symbol, dummy_tick, t)` hívást használja a hibrid indikátorok (EMA, Pulse, Flow) léptetéséhez.

## KÖVETKEZŐ LÉPÉSEK (NEXT SESSION)
1. **Adatbányászat:** A felhasználónak az MT5 MetaEditorban le kell fordítania (Compile) a `Merkava_Data_Miner_M1_v1_02.mq5` fájlt, és lefuttatnia egy érdemi történelmi időszakra (pl. az elmúlt 6-12 hónap M1 gyertyáira).
2. **Feature Generálás:** A kinyert adatokat a már a szerveren lévő `/home/misi/Merkava_ML_Ops/src/feature_engineering.py` segítségével (ami tartalmazza a Triple Barrier címkézést) Parquet formátumú feature mátrixszá kell alakítani. Ezt meg lehet tenni a VPS parancssorából is.
