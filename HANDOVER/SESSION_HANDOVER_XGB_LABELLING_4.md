# SESSION HANDOVER V4 - Data Validation & MT5 History (2026-06-17)

## ADATELLENŐRZÉS EREDMÉNYE
- Fájl a VPS-en: `/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/Merkava_XAUUSD_MINER_M1_v1.02_20260617_182426.csv`
- **Sorok száma:** 96 244
- **Dátumtartomány:** 2026.03.05 - 2026.06.12 (Kb. 3 hónap)

## AZ "1 ÉV HELYETT 3 HÓNAP" JELENSÉG OKA
A hiba nem a kód hardkódolásából ered (a script 2025.03.09-től kéri az adatot). Ez a **MetaTrader 5 MqlRates aszinkron adatelérési korlátja**. Az MT5 terminál lokális memóriájában (history) nincs letöltve az XAUUSD M1 1 éves múltja. A `CopyRates` függvény pedig azonnal visszatér azzal a mennyiséggel, ami épp a gép memóriájában van (jelenleg a legutóbbi 3 hónap).

### MEGOLDÁS (FELHASZNÁLÓI FELADAT A VPS-EN):
Mielőtt az EA-t újra futtatná a felhasználó, az MT5-ben manuálisan le kell tölteni a teljes történetet:
1. MetaTrader 5 terminál -> `CTRL + U` (Symbols)
2. XAUUSD kiválasztása -> `Bars` fül
3. Timeframe: M1, Dátum: 2025.01.01-től -> `Request` gomb.
Ezután az EA probléma nélkül kiexportálja a 300 000+ sort.

## KÖVETKEZŐ LÉPÉS
Amint a felhasználó letöltötte a teljes 1 éves adatbázist a fenti módszerrel és legenerálta az új CSV-t az MT5 `Files` mappájába, a `feature_engineering.py` (Triple-Barrier method) szkriptet futtatni kell a végleges XGBoost mátrix (`.parquet`) elkészítéséhez a VPS-en.
