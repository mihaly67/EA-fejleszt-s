# HANDOVER: HUD Development & Tick-Level Candlestick Rendering

## 1. Jelenlegi Állapot (Mit értünk el)
- A **Merkava V1.9 Beta Copilot** backendje (Python) és az adatbányászata (MQL5) tökéletesen és stabilan működik. A kettő közötti ZeroMQ és TCP socket kapcsolat (5555 és 5557-es portok) valós időben továbbítja az adatokat.
- A modell gond nélkül prediktálja a probabilitásokat (P_Long, P_Short, P_Noise) és a kimeneti jeleket az M1 gyertyák és tick sebességek alapján.
- A jelenlegi HUD (`Live_Trading/src/copilot_hud.py` vagy `Micro_LGBM/src/copilot_hud.py`) jelenleg **PyQtGraph** alapokon nyugszik.
- **A Probléma:** A PyQtGraph a beérkező tick streamet (ahol másodpercenként jöhet több update) úgy értelmezte, hogy minden érkező adatpontra új koordinátát (új gyertyát) rajzolt. Ez a vizualizáció széteséséhez vezetett. Bár a makro (idő) adja meg a gyertya keretét, a mikro (tick) mozgatja a High/Low/Close értékeket az adott időbélyegen belül. A PyQtGraph ezzel nem tudott organikusan megbirkózni, különösen "Zero-Volume" vagy doji tickeknél.

## 2. A Megoldás Iránya (Mit kell tenni a következő sessionben)
- A felhasználó kutatómunkája és a klónozott RAG tudásbázis (`Knowledge_Base/External_Repos/`) alapján a **PyQtGraph lecserélésre kerül**.
- Az új grafikus motor a **`lightweight-charts-python`** lesz (a TradingView hivatalos API-jának python wrappere).
- **Miért?** Ez a könyvtár rendelkezik egy `update_from_tick()` metódussal, ami alapból megoldja a makro/mikro problémát. Ha az időbélyeg ugyanaz, a grafikon nem rajzol új x-koordinátát, csak a meglévő gyertya High/Low/Close értékeit frissíti folyamatosan, felépítve a formát.
- **Integráció:** A `lightweight-charts-python` beágyazható a meglévő PyQt5 ablakba egy `QWebEngineView` segítségével. (A VPS-en futó sandbox környezet miatt lehet, hogy szükséges telepíteni a `PyQtWebEngine` modult a virtulális környezetbe).
- Külön kérés volt, hogy fontoljuk meg a `DearPyGui` használatát is, amely szintén le lett klónozva a VPS-re. Ezt is vizsgáld meg, mielőtt elköteleződsz a `lightweight-charts-python` mellett.

## 3. Fejlesztői Környezet a VPS-en
- Ne a `Live_Trading` éles fájljait szerkeszd elsőre!
- Egy új, elszigetelt könyvtár jött létre a VPS-en: **`/home/misi/ML_Ops/HUD_Development/`**.
- Ebben a könyvtárban található a `hud_rag_search.py` is, amivel keresni tudsz az összegyűjtött repók (lightweight-charts, finplot, pyqtgraph, DearPyGui) forráskódjaiban. Példa futtatás: `python3 /home/misi/ML_Ops/HUD_Development/hud_rag_search.py realtime tick`.
- A klónozott harmadik féltől származó GUI könyvtárak itt találhatók a VPS-en: `/home/misi/ML_Ops/Knowledge_Base/External_Repos/`

## 4. Instrukciók a Következő Ügynöknek
1. Olvasd el ezt a fájlt és a `memory.jsonl`-t.
2. Navigálj a VPS-en lévő `/home/misi/ML_Ops/HUD_Development/` mappába (használd az sshpass-t vagy a vps bridge-t).
3. Készíts egy izolált, tesztelhető HUD prototípust (pl. `test_tv_hud.py`), amelyik feliratkozik a ZMQ 5557-es portjára, és PyQtWebEngine használatával rendereli a `lightweight-charts-python` chartot.
4. Teszteld az `update_from_tick` függvény használatával. Ha megérkezik a 100 gyertyás "history" json payload, használd a `chart.set()` metódust. Ha "update" tick érkezik, használd a `chart.update_from_tick()` metódust!
5. Csak akkor integráld be a fő `copilot_hud.py`-ba, ha a prototípus már stabilan rajzolja a gyertyákat.
