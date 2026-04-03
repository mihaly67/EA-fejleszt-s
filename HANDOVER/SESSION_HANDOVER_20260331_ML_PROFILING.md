# SESSION HANDOVER: 20260331_ML_PROFILING (A DINAMIKUS VAKU 3.0 ÉS A FINRL COPILOT)

**Dátum:** 2026.03.31
**Státusz:** 🟢 Sikeres Integráció. A Szkenner (`scan_broker_parameters.py`) sikeresen beépült a Címkézőbe (`label_broker_reaction.py`). Az AI többé nem hardkódolt, statikus (és sokszor irreális) értékekkel dolgozik, hanem minden egyes CSV fájl esetében valós időben (dinamikusan) kiszámolja a brókeri reakciók (Spread, Adverse Excursion, Whipsaw, Latency) P50 és P90-es percentilisét. Megoldottuk a Forex (5 tizedes) és az Indexek/Fémek (2 tizedes) eltérő volatilitásából fakadó "mikrozaj" (fals pozitív) problémát is egy **Adaptív Volatilitás Skálázó (Noise Floor)** bevezetésével.
**Kódnév:** Projekt "Sötét Szoba" (A Bróker Ujjlenyomata) - 2. Fázis

---

## 1. Műveleti Összefoglaló (A Mai Session Eredményei)

*   **A Szkenner és a Címkéző Összevonása:**
    *   A `label_broker_reaction.py` mostantól a processálás legelső lépéseként lefuttat egy memóriabeli Szkennert a fájl összes trade-jére, és kinyeri a tényleges eloszlásokat.
    *   A statikus `LabelerConfig` értékek (pl. `EXCURSION_THRESHOLD = 1.5` pont) háttérbe szorultak. Helyettük a fájl specifikus **P90-es Adverse Excursion** és **P90-es Spread Multiplier** értékek léptek életbe. A `WHIPSAW_THRESHOLD` szintén P90 alapú lett.
    *   **Eredmény:** Az EURUSD teszten a hamis "Lassú Kivéreztetés" (Adverse Excursion) találatok száma 81-ről 18-ra zuhant!
*   **Adaptív Volatilitás Skálázás (Forex vs. Index/Fémek):**
    *   A script megvizsgálja az átlagárat (pl. `avg_price < 5.0`). Ha 5 alatt van (Forex, pl. 1.05000), akkor a formázást automatikusan `.5f`-re állítja, és bekapcsol egy "Noise Floor"-t.
    *   **A Noise Floor jelentősége:** Ha a piac annyira döglött, hogy a P90-es Adverse Excursion csak `0.00001` (1 mikropip), a rendszer ezt felülbírálja egy minimum `0.00005` (5 pont) Forex, vagy `0.05` Fém/Index padlóval. Ez megakadályozza, hogy az AI a természetes "fehér zajt" manipulációnak (Target=1) lássa lapos piacokon.
*   **A Vaku 3.0 (Offline Validátor) Jelentésének Mentése:**
    *   A `vaku3_offline_validator.py` (a HMM Smoking Gun bizonyítéka) ezentúl nem csak a konzolba (terminálba) írja az eredményeit, hanem elmenti a `reports_tmp/` mappába egy TXT fájlba (pl. `VAKU3_REPORT_Merkava_EURUSD_v1.10_*.txt`), így a felhasználó könnyedén archiválhatja és visszanézheti az eredményeket.
*   **Az "Idő-Csapda" Megoldása (Tick Sűrűség Profilozó):**
    *   Mivel bebizonyosodott, hogy a nappali (Londoni) és éjszakai (Ázsiai) tick sűrűség között brutális különbségek vannak, a fix *15 tickes* HMM ablak (ami éjjel tökéletes) nappal túlságosan "vaksi" a HFT forgalom miatt.
    *   Létrehoztunk egy új eszközt: `profile_tick_density.py`. Ez a fájl megméri a CSV-k másodpercenkénti tick-sebességét (Tick/sec), és **javaslatot tesz egy Dinamikus HMM Ablakméretre**, ami fizikai időben (pl. 3 másodperc) tartja a fókuszt ahelyett, hogy statikus tickszámhoz ragaszkodna.

---

## 2. A "Színház" (Manipuláció) Nappali vs. Éjszakai Profilja

A mai elemzések (EURUSD és XAUUSD tesztek alapján) megcáfoltak korábbi feltételezéseket, és éles különbséget mutattak a bróker nappali és éjszakai algoritmikus viselkedése között:

*   **Az Éjszakai Profil (22:00 után - Kis Likviditás):**
    *   **Fegyver:** Tick Lefagyasztás (Latency).
    *   **Viselkedés:** A bróker megnyomja a "Hold" gombot. A tickek megállnak (akár 11 másodpercre). A volatilitás (Whipsaw) összeomlik, és a piac egyszerűen befagy a trade után.
*   **A Nappali Profil (London/NY - Nagy Likviditás):**
    *   **Fegyver:** Rángatás (Whipsaw) és Fake Breakout ("Színház").
    *   **Viselkedés:** Nincs tick lefagyasztás (0 db Latency a tesztben). A bróker nem állíthatja meg a piacot az arbitrázs botok miatt. Ehelyett agresszív (pl. 0.87 pontos arany mozgás) ellenirányú rángatással próbálja kivenni a stoppokat.

---

## 3. Gemini Konzultáció: A "Scale-Dependency" Hiba és a Dinamikus Szeletelés (Slicing)

A nap végén Geminivel (a "Laborral") folytatott magas szintű matematikai és építészeti vita során feltártuk az online architektúra legkritikusabb problémáit, és kidolgoztuk az implementálandó tervet a következő Agent számára:

*   **A Szoftveres Hardver-Optimalizáció (O(1) Sebesség):**
    *   Az online rendszerben **tilos** a tick puffert menet közben újraallokálni (realloc), mert az laggot és jittert okoz (megöli az MT5 kommunikációt).
    *   **Megoldás:** Előre le kell foglalni egy fix, maximum 1000 tickes Numpy tömböt (`buffer = np.zeros(1000)`). Amikor a HMM vizsgálni akar, a pillanatnyi Tick Sűrűség (Tick Density) alapján csak egy dinamikus szeletet olvas ki belőle (pl. `buffer[-150:]` nappal, vagy `buffer[-15:]` éjjel).
*   **Az "Optikai Csalódás" (Fraktális Normalizáció):**
    *   A HMM Log-Efficiency Ratio (LogER) kalkulációja eltorzul, ha a szelet hossza ($N$) változik (mivel a bruttó zaj gyorsabban nő, mint a nettó elmozdulás). Ezt hívják Scale-Dependency hibának (Fractional Brownian Motion drift).
    *   **Megoldás:** A következő Agentnek be kell építenie egy előre kiszámolt statikus *Lookup Table*-t (Skála-Faktor Mátrix), ami O(1) sebességgel kompenzálja a LogER-t az $N$ hossza alapján (Vektorizált Broadcastinggal), mielőtt odaadná azt a HMM-nek és a Welford Scalernek.

---

## 4. A Következő Lépések (A Felhasználó Feladatai)

Az Agent munkája befejeződött, a kód tökéletesen, dinamikusan alkalmazkodik az instrumentumokhoz és a bróker valós statisztikáihoz.

A **Felhasználónak a következőket kell tennie a VPS-en vagy a lokális MX Linux+Wine környezetén:**
1.  **Adatgyűjtés (Kötések Nélkül) - Hétfői Stressz Teszt:** Indítsd el a BlackBox adatbányászt egy demó számlán úgy, hogy NE kössön. Gyűjts 1-1 órás adatokat délelőtt (Londoni nyitás), délután (NY), este (20:00) és éjszaka (02:00).
2.  **Tick Sűrűség Profilozás:** Futtasd le ezeken az üres fájlokon a `python3 profile_tick_density.py` scriptet.
3.  **Az Eredmény Elemzése:** A script meg fogja mondani (egy TXT riportban), hogy a különböző napszakokban átlagosan mennyi volt a Max Tick/sec.
4.  Ezekkel a Stressz Teszt adatokkal felfegyverkezve a következő Agent meg fogja írni az O(1) komplexitású **Online TickBufferManager**-t és a **Length-Normalized LogER Lookup Table**-t a Vaku 3.0-hoz!

---

## 4. Az MX Linux (Budget MLOps) FinRL Architektúra Jövőképe

A `FINRL_VISION.md` dokumentumban rögzítettük a hosszú távú célt: a Vaku 3.0 (Behavioral Copilot) összekötését egy Financial Reinforcement Learning (FinRL) ágenssel, amely a brókeri manipulációs HMM állapotokat is figyelembe véve hoz kereskedési döntéseket.

A javasolt "Józan Ész" (Budget) AMD/Linux lokális hardware specifikáció a jövőbeli élő (Live) FinRL inference-hez:
*   **Oprendszer:** MX Linux + Wine (Tökéletes, gyorsabb Python ML MLOps futtatás natívan, minimális overhead az MT5 Wine kommunikáción).
*   **CPU:** AMD Ryzen 5 7600 (vagy régebbi 5700X)
*   **RAM:** 32GB (Kötelező a Replay Bufferek miatt)
*   **GPU:** NVIDIA RTX 3060 12GB vagy RTX 4060 8GB (Az AMD ROCm szenvedés elkerülése végett a CUDA elengedhetetlen a zökkenőmentes PyTorch/FinRL fejlesztéshez).
*   **Tárhely:** 1TB NVMe PCIe SSD.

Készítette: Jules (MLOps Tervező Agent)
Dátum: 2026.03.31.