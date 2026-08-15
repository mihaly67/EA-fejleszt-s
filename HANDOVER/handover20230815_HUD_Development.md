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
- **Integráció:** A `lightweight-charts-python` beágyazható a meglévő PyQt5 ablakba egy `QWebEngineView` segítségével.
- Külön kérés volt, hogy fontoljuk meg a `DearPyGui` használatát is, amely szintén le lett klónozva a VPS-re. Ezt is vizsgáld meg, mielőtt elköteleződsz a `lightweight-charts-python` mellett.

## 3. Fejlesztői Környezet a Lokális (Sandbox) és VPS gépen
- **MUNKAMÓDSZER (Szigorú Szabály):** A kódolást és fejlesztést a lokális "sandbox" környezetedben végezd, de a **FUTTATÁST** és a tesztelést minden esetben a VPS-en (5.189.163.88) hajtsd végre `sshpass` (jelszó: 1104) vagy `vps_bridge.py` segítségével, ahogy eddig is tettük! Sose próbálj komoly MQL5 vagy GUI kódokat futtatni a headless lokális konténeredben!
- Ne a `Live_Trading` éles fájljait szerkeszd elsőre! Egy új, elszigetelt könyvtár jött létre a VPS-en a root mappában a fejlesztésre: **`/home/misi/LGBM_mlops/HUD_Development/`**.
- A klónozott harmadik féltől származó GUI könyvtárak itt találhatók a VPS-en: **`/home/misi/LGBM_mlops/Knowledge_Base/External_Repos/`**

## 4. Fejlett Kontextuális RAG Kereső (FTS5)
- Az `External_Repos` mappában egy `gui_rag.db` (SQLite FTS5) adatbázis generálódott a 5 klónozott repóból.
- Ebben a könyvtárban található egy rendkívül erős kontextuális RAG script is a VPS-en: **`hud_rag_agent.py`**.
- Ez a kereső nem csak a kulcsszavas sort dobja ki, hanem beolvassa a kódkörnyezetet is (előtte 5, utána 15 sor), ezáltal bonyolult lekérdezések is értelmezhetőek vele.
- **Használat a VPS-en:** `sshpass -p '1104' ssh -o StrictHostKeyChecking=no misi@5.189.163.88 'python3 /home/misi/LGBM_mlops/Knowledge_Base/External_Repos/hud_rag_agent.py "how to add realtime candlestick QWebEngineView"'`

## 5. Instrukciók a Következő Ügynöknek
1. Olvasd el ezt a fájlt és a `memory.jsonl`-t.
2. Navigálj be a `/home/misi/LGBM_mlops/HUD_Development/` mappába a VPS-en.
3. Készíts egy izolált, tesztelhető HUD prototípust a Sandboxodban, de a VPS-en futtasd és teszteld, amelyik feliratkozik a ZMQ 5557-es portjára, és PyQtWebEngine használatával rendereli a `lightweight-charts-python` chartot.
4. Használd a VPS-en a RAG eszközt (`hud_rag_agent.py`), hogy megértsd a beágyazási logikát az `update_from_tick()` metódusra fókuszálva.
5. Csak akkor integráld be a fő `copilot_hud.py`-ba, ha a prototípus már stabilan rajzolja a gyertyákat.
