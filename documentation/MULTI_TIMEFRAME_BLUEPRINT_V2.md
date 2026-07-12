# 📊 MULTI-TIMEFRAME (HIBRID) STATISZTIKAI VALIDÁCIÓ V2

A felhasználó kiváló meglátása és az MQL5 RAG-ok alapján a rendszert "Hibrid" architektúrára emeljük. Egyetlen, rövid tick-ablak (N=15) vak a makro piaci mozgásokra. Ahhoz, hogy az EA valódi "Tanácsadó" (Advisor) legyen, látnia kell az "Időjárást" (Makro) és az aktuális "Széllökéseket" (Mikro) is.

Mivel nincsenek nagy hardveres erőforrásaink, de az MT5 kiválóan kezeli a zárt gyertyákat, a megoldás a Gyertya-alapú és Tick-alapú statisztika O(1) komplexitású ötvözése.

## 1. A Hibrid Adatfolyam Architektúra

### A) Makro Ablak: Zárt Gyertyák (Időjárás / Kontextus)
A HMM vagy az SSA motor számára sokkal olcsóbb és tisztább, ha a hosszú távú kontextust **zárt gyertyák (OHLC: Nyitás, Magas, Alacsony, Zárás)** alapján számoljuk (pl. M15, M30, H1 idősíkon).
- **Előny:** Zárt gyertyákból származó Kaufman Efficiency Ratio (ER), Oszcilláció, vagy Volume pontos képet ad arról, hogy a piac trendel vagy oldalazik. Nem terheli a memóriát több ezer tick tárolása.
- **Kimenet:** `Macro_State` (Betonfal, Oldalazás, Káosz). Ezt elég gyertyánként vagy percenként egyszer kiszámolni.

### B) Mikro Ablak: Tick Stream (Széllökések / Végrehajtás)
Itt jön be a mi Vaku 3.0 Motorunk (O1RingBuffer). Az EA a belépés pillanata *előtt* vizslatja a legutolsó 15-300 ticket.
- **Előny:** Felismeri az apró brókeri manipulációkat (Spread tágítás, Whipsaw, Lefagyás), amelyek egy H1 gyertyában (mint egy apró kanóc) teljesen észrevehetetlenek lennének.
- **Kimenet:** A `Theater_Risk_Pct` (Viterbi Jövőkutatás), amit az imént írtunk meg a Python kódban.

## 2. A "Faggatás" és Döntési Mátrix (A Szinergia az EA-ban)
Amikor a kereskedési logika (pl. egy indikátor) belépési jelet ad, az EA mindkét dimenziót "kifaggatja", és az alábbi logikai mátrix alapján tesz javaslatot:

| 📅 Makro Ablak (Zárt Gyertyák: pl. M30) | ⏱️ Mikro Ablak (Tickek: Viterbi Predict) | 🤖 EA Tanácsadó (Döntés) | Magyarázat |
| :--- | :--- | :--- | :--- |
| **Erős Trend** (Magas ER) | **Tiszta** (Risk < 20%) | ✅ **ZÖLD LÁMPA** | A nagy kép tiszta, a bróker sem avatkozik be mikroszinten. Kiváló belépés. |
| **Erős Trend** (Magas ER) | **Manipuláció** (Risk > 40%) | ⏸ **SÁRGA LÁMPA (VÁRJ)** | Az irány jó, de a bróker épp most dobálja az árat (Whipsaw/Spread). Várj 1 percet a belépéssel. |
| **Oldalazás/Káosz** (Zajos OHLC) | **Tiszta** (Risk < 20%) | ❌ **PIROS LÁMPA** | Lehet, hogy épp most csend van (pillanatnyi nyugalom), de a piac a makro idősíkon kiszámíthatatlan. Nincs trade. |
| **Oldalazás/Káosz** | **Manipuláció** | ❌ **PIROS LÁMPA** | Tökéletes vihar. Tiltott zóna. |

## 3. Implementációs Terv (A Kód Szintjén)
1. **Python / ONNX:** A `vaku3_offline_validator.py` HMM betanítása után megvizsgáljuk, hogy egy külön `vaku_macro_validator.py` HMM is kell-e a gyertyákra (vagy elég egy sima ER kalkuláció MQL5-ben).
2. **MQL5 EA:** Az EA beépítve megkapja a Gyertya-alapú Makro állapotot (ezt akár az MQL5 is könnyen tudja számolni `iATR` és `Kaufman ER` alapján), és a ZMQ hídon (vagy az ONNX inferencen) KIZÁRÓLAG a Mikro Tickeket kérdezi le a Python Viterbi predikciótól.

*Konklúzió:* Ez a hibrid, zárt gyertya + tick predikció ötvözet adja a legalacsonyabb VPS erőforrásigényt és a legbiztonságosabb Advisory (Tanácsadó) rendszert.
