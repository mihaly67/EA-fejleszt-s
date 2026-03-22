# SESSION HANDOVER: 20260303221418 (REALTIME_ADAPTIVE_MATRIX)

**Dátum:** 2026.03.22 (Belső logikai időbélyeg a kérés alapján: 20260303221418)
**Státusz:** ⚠️ Paradigmaváltás a Paradigmaváltásban: A Gemini-vakvágány leleplezése és a Mátrix Profilozó születése.
**Kódnév:** Projekt "Szent Grál" - A Brókeri Manipuláció Valódi Spektruma

## 1. Műveleti Összefoglaló (Mit végeztünk el?)
A Gemini kutatás alapján sikeresen implementáltuk a `run_streaming_simulation.py`-ba a **Dinamikus Szekvenciahosszt (Kaufman Efficiency Ratio)**, a **Hibrid Drift Kezelést (Page-Hinkley teszt)**, a **Spektrális Zajszűrést (Savitzky-Golay)**, valamint a Keras sebességoptimalizálását (**Mini-Batch $O(1)$ inferencia**).

A tesztelés (egy 3 órás, 2179 tickes CSV-n) során azonban a valóság arcul csapta az elméletet: a szimulátor **30 percig** futott a 8GB RAM-os VPS-en.

## 2. A Vakvágány Leleplezése (A Probléma Gyökere)
A felhasználó log-elemzése rámutatott a kritikus hibára:
Amikor a szimulátor menet közben megváltoztatta az LSTM "látóterét" (pl. 80 tickről 120 tickre a volatilitás miatt), a Keras hálózat bemeneti dimenziói (`Input Shape`) fizikailag megváltoztak. Ez kikényszerítette az aktuális hálózat megsemmisítését, és a múlt (history_df) "ősrobbanástól" való **kényszerű újratanítását**. Egy 1 milliós adatsoron ez az EA teljes lefagyását okozta volna (atomerőművet igénylő folyamat).

Továbbá logikailag is felismertük, hogy a **Gemini "bias-variance trade-off" elmélete az Algo-Trader (árfolyam-előrejelzés) világára optimalizált**:
*   *Gemini Elmélet:* Pörgős piacon KIS ablak kell, mert csak az új, gyors trend számít.
*   *A Mi Valóságunk (Brókeri Szándék keresése):* Pörgős (zajos) piacon a brókeri manipuláció egy "zaj a zajban". Ahhoz, hogy az AI a természetes káoszból kiszűrje a mesterséges brókeri tüskét, **NAGY kontextusra (100-150 tick)** van szüksége, hogy lássa a teljes hullámmintázatot. Döglött piacon viszont a semmiből kiugró tüske detektálásához egy KIS ablak is elég.
*   **Konklúzió:** A mi tapasztalataink (és a korábbi Állókép Profilozó) fordított megállapításai voltak a helyesek az *Unsupervised Anomaly Detection* terén.

## 3. A Mátrix Profilozó Születése (A Megoldás)
Mivel az idősor fizikai feldarabolása (Volatilitás-vödrözés) összetöri az LSTM szekvenciális memóriáját, megalkottuk a **`run_advanced_profiler.py` (Mátrix Profilozó)** scriptet.

**Mit csinál a Mátrix?**
1.  Nem vágja szét a fájlt. Végigmegy rajta egyben, és minden tickhez (az elmúlt 500 tick alapján) kiszámolja a **Tick Volatilitást** és a **Tick Sűrűséget**, majd felcímkézi a piacot (`Low_Volatility`, `Medium_Volatility`, `High_Volatility`). Ezzel levédi a rendszert a brókeri rángatások okozta fals "pörgős" címkéktől.
2.  Párhuzamosan betanítja és lefuttatja a teljes spektrumot (40, 80, 120, 150 tickes ablakok).
3.  Az eredményeket kimenti egy `MATRIX_ANALYZED_...` CSV fájlba.

Ezután a **`visualize_matrix.py`** script csoportosítja a nyitott kereskedéseket a Piaci Állapotok (Volatilitás) szerint, és egyértelműen kimutatja: *"Alacsony volatilitásnál a 80-as ablak nyert, Magas volatilitásnál a 120-as."*

Az első 6 fájl elemzése megdöbbentő eredményt hozott: A volatilitás szinte alig számít a mi esetünkben. A **120 tickes ablak** a piac minden fázisában konzisztensen 80-100%-os felismerést hozott a brókeri manipulációkra, míg a dinamikus ugrálás (40/150) sorra elvérzett.

## 4. A Következő Ügynök Feladata (A Jövő)
A felhasználó jelenleg további tucatnyi kereskedési CSV-n futtatja a Mátrix Profilozót (`run_advanced_profiler.py`), hogy statisztikailag is bebetonozza a "Szent Grál" (egy egyetemes, fix) szekvenciaszámot (pl. 120 tick).

**A Te feladatod lesz (ha a felhasználó jóváhagyja az eredményeket):**
1.  Nyisd meg a `run_streaming_simulation.py`-t.
2.  **Gyomláld ki** belőle a Kaufman ER-t, a dinamikus ablakváltást (`update_window_size`), és az ősrobbanás-újratanításokat (`history_df`).
3.  Alakítsd át a szimulátort egy **Kőkemény, Egysebességes (Fix pl. 120 tickes) Rolling Window** architektúrára, ami a Page-Hinkley drift tesztet kizárólag a `Threshold` kalibrálására használja, de sosem piszkálja az Input Dimenziót.
4.  Ezzel a szimulátor (és a jövőbeli MT5 EA) $O(1)$ Minibatch inferenciával 3 órányi adatot várhatóan 3 perc alatt fog ledarálni, felesleges "látótér-váltások" nélkül, a legmagasabb találati pontossággal.

**Készítette:** Jules (Szakértő Szoftvermérnök Agent)
