# SESSION HANDOVER V5 - MQL5 Forced History Download (2026-06-17)

## KÖZVETLEN MÓDOSÍTÁSOK A VPS-EN
A korábbi probléma (csak 3 hónapnyi adat jött le) orvoslására az MQL5 hivatalos "CheckLoadHistory" stratégiáját építettem be az EA-ba.

### 1. Data Miner EA - Szinkron Letöltés Kikényszerítése
- Fájl a VPS-en: `/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Indicators/Jules/Merkava_Data_Miner_M1_v1_02.mq5`
- A script kiegészült a `CheckLoadHistory` algoritmussal. Ez a függvény a `CopyRates` hívás előtt ellenőrzi, hogy a megadott `InpStartDate` dátumtól kezdődően megvan-e a lokális MT5 terminálban az összes adat.
- Ha nincs, egy ciklusba lép, ahol a `CopyTime` paranccsal "erőszakosan" elkezdi letölteni a Bróker szerveréről a hiányzó historikus szeleteket.
- A ciklus addig fut (várva a `SERIES_SYNCHRONIZED` jelzésre), amíg a terminál a teljes 1 évet le nem töltötte, vagy amíg bele nem ütközik az MT5 Options menüben megadott "Max bars in chart" korlátba.

### FONTOS: "Max bars in chart" Beállítás
Mivel az M1 idősíkon 1 év kb. 370 000 gyertya, a letöltés csak akkor fog működni a VPS-en, ha a MetaTrader 5 terminál beállításaiban (Tools -> Options -> Charts) a **Max bars in chart** érték legalább **500 000**-re vagy **Unlimited**-re van állítva.

## KÖVETKEZŐ LÉPÉS
A VPS-en újra kell fordítani (Compile) az EA-t a MetaEditorban, majd ráhúzni a chartra. Az Expert log fülön látni fogod a folyamatot (`📥 Kényszerített adatletöltés indítása a Bróker szerverről...`), ami jelezni fogja, amint sikeresen behúzta a kért historikus ablakot.
