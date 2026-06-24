# Vaku 3.0 HMM Műszerfal: Felhasználói és Telepítési Útmutató

Ez a dokumentum a Vaku 3.0 Online HMM (Hidden Markov Model) Műszerfal paraméterezésének logikáját és a rendszer más gépekre történő áthelyezését (hordozhatóságát) mutatja be.

---

## 1. A Rendszer Értelmezése és Paraméterezése

A műszerfal célja, hogy kiszűrje a piaci zajt (oldalazást) és előre jelezze az esetleges manipulációkat (whipsaw / spread tágítás), mielőtt az MT5 robot (Merkava) pozíciót nyitna. Ehhez a rendszer három független idősíkon (Makro, Közép, Mikro) vizsgálja a piacot valós időben, pusztán a beérkező tick adatok alapján.

### 1.1. Időablakok és Érzékenység (Bal és Középső Oszlop)
*   **Időablak (mp):** Azt határozza meg, hogy a rendszer hány másodpercnyi történelmet vizsgáljon az adott réteghez.
    *   *Makro (pl. 60 mp):* A fő trend iránya.
    *   *Közép (pl. 45 mp):* Opcionális kontroll-réteg. Ha `0`-ra van állítva, a rendszer teljesen kikapcsolja és ignorálja.
    *   *Mikro (pl. 30 mp):* Az azonnali, rövid távú lendület.
*   **Érzékenység (%):** A minimális százalékos árelmozdulás, ami szükséges ahhoz, hogy a mozgást "Trendnek" (UP vagy DOWN) tekintse az algoritmus az adott időablakon belül.
    *   *Példa:* Ha a Makro ablak 60 mp, és a Makro Érzékenység 0.05%, akkor az árfolyamnak legalább 0.05%-ot kell mozdulnia a 60 másodperccel ezelőtti önmagához képest. Ha ennél kevesebbet mozdult, az eredmény "FLAT" (lapos).

> **A Predikció Logikája:** A rendszer folyamatosan összeveti a Makro (hosszú) és a Mikro (rövid) trendeket. Ha a Makro még erősen UP, de a Mikro már beesett negatívba (divergencia), a műszerfal "Medve Forduló Várható!" riasztást ad, megelőzve ezzel, hogy a robot egy kifulladó trend csúcsán vegyen.

### 1.2. Kockázati Szűrők és Tiltások (Jobb Oszlop)
Az alábbi két szűrő a kereskedés biztonságát garantálja. A szűrők **bármelyik idősíkon** (Mikro, Közép, Makro) képesek letiltani a piacot (Piros vagy Sárga jelzés), ha az adott síkon meghaladják a limitet.

*   **Káosz Küszöb (ER <):** Az *Efficiency Ratio* (Hatékonysági Mutató) alapján számolva. Azt méri, hogy az árfolyam mennyire tiszta vonalban halad (ER közeledik az 1.0-hoz), vagy mennyire "rángat" fel-le egy helyben (ER közeledik a 0.0-hoz).
    *   *Beállítás:* Ha pl. `0.05`-re állítod, és az adott idősík ER-je ezen érték alá esik, a rendszer **PIROS (TILTVA)** jelzést ad, mert a piac csak zajos oldalazást mutat, tiszta trend nélkül.
*   **Whipsaw Kockázat (% >):** A hirtelen volatilitás-ugrásokat figyeli az átlagos múltbéli volatilitáshoz képest. A brókerek általi szándékos stop-vadászatokat (gyors fel-le tüskék, spread tágítások) hivatott kiszűrni.
    *   *Beállítás:* Ha pl. `60.0`-ra állítod, és a rövid távú rángatózás mértéke meghaladja az elmúlt időszak történelmi maximumának 60%-át, a rendszer **SÁRGA (FIGYELEM)** jelzést ad. Ilyenkor érdemes várni a belépéssel, amíg a piac megnyugszik.

---

## 2. Hordozhatóság (Költözés Saját Gépre)

A rendszer rendkívül moduláris, nincsenek bonyolult adatbázis (SQL/RAG) függőségei az élő működés során, és DLL fájlokat (mint a klasszikus ZMQ) sem használ.

**Mindössze két fájlra van szükséged:**
1.  **`vaku3_online_hybrid_v9.py`** (A Python Műszerfal)
2.  **`Merkava_Behavioral_Profiler_v1.2_Online.mq5`** (A MetaTrader 5 Expert Advisor, és az általa be-include-olt fájlok, ha újrafordítod)

### 2.1. Telepítési Lépések a Célgépen

#### 1. A Python Környezet (Venv) Létrehozása
A Python Műszerfal futtatásához egy dedikált környezet javasolt. Nyiss egy parancssort/terminált a gépeden és hozz létre egy virtuális környezetet (virtual environment), majd aktiváld (pl. `venv\Scripts\activate` Windows alatt).

Ezután telepítsd a szükséges csomagokat:
```bash
pip install numpy==1.26.4 pandas==2.2.2 pyqt5 pyqtgraph
```

*(Megjegyzés: A `numpy` 2.x és `pandas` 3.x verziói újabb processzor architektúrákat - AVX utasításkészlet - követelnek meg. Régebbi hardvereken, pl. AMD Phenom II, ezek `Érvénytelen utasítás / Illegal instruction` hibát okoznak. A fenti `1.26.4`-es verzió minden környezetben stabil).*`

*(Másold a `vaku3_online_hybrid_v9.py` fájlt ebbe a mappába).*

#### 2. Az MQL5 EA (Expert Advisor) Telepítése
1.  Nyisd meg a MetaTrader 5-öt az új gépen.
2.  Kattints a **Fájl -> Nyissa meg az Adatmappát** (Open Data Folder) menüpontra.
3.  Navigálj az `MQL5/Experts/` mappába (vagy csinálj egy saját almappát).
4.  Másold be ide a `Merkava_Behavioral_Profiler_v1.2_Online.mq5` fájlt (valamint győződj meg róla, hogy a rendszer eredeti fájljai a megfelelő relatív mappákban vannak, ha újra is akarod fordítani).
5.  Ha forráskódból másolod, nyisd meg a MetaEditorban, és nyomj **F7**-et a fordításhoz. (Ha csak az .ex5 fájlt viszed át, az is tökéletes).

#### 3. MT5 Biztonsági Beállítások (NAGYON FONTOS!)
A kommunikáció natív MT5 TCP Socketeken (WebRequest API) történik a 127.0.0.1 (localhost) IP címen a 5555-ös porton keresztül.
1.  Az MT5 felső menüjében: **Eszközök (Tools) -> Beállítások (Options)**.
2.  Lépj az **Expert Advisors** fülre.
3.  Pipáld be: **"Allow WebRequest for listed URL"** (WebRequest engedélyezése a listázott URL-ekhez).
4.  Kattints a zöld `+` jelre, és írd be: **`127.0.0.1`** majd nyomj Entert és Ok-t.

### 2.2. Indítási Sorrend
1.  **Először mindig a Pythont indítsd el!** A parancssorban (aktivált venv mellett) add ki a `python vaku3_online_hybrid_v9.py` parancsot. Megjelenik a Műszerfal.
2.  **Másodszor az EA-t.** Húzd rá a `Merkava_Behavioral_Profiler_v1.2_Online` EA-t a kiválasztott grafikonra az MT5-ben.
    *   Az EA induláskor (OnInit) azonnal csatlakozik a Pythonhoz, és átdobja a legutolsó 600 historikus ticket, amivel azonnal be is melegszik a Műszerfal, és indulhat az élő vizuális kereskedés!
