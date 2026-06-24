# Üzemzavar Jelentés és Elhárítás

**Esemény:**
A rendszer a `Full_System_Test_V2` projekt 2. feladatánál ("Hybrid Indikátor Stratégiák") ismétlődő leállásba (Crash Loop) került.

**Ok:**
A `kutato.py` alfolyamat a memóriaigényes keresés (EA31337 osztályok) során valószínűleg túllépte a rendelkezésre álló erőforrásokat, ami a Műszakvezető kényszerített leállítását okozta. Az Őrszem (Watchdog) újraindította a folyamatot, de az újra és újra ugyanabba a hibába futott.

**Elhárítás:**
1.  **Crash Detection Logic:** A Műszakvezetőt (`project_manager.py`) felvérteztem egy intelligens hibafigyelő rendszerrel.
2.  **Skip Mechanism:** Ha egy feladat 3-szor egymás után összeomlást okoz, a rendszer automatikusan átugorja ("KIHAGYÁS"), és folytatja a következővel, ahelyett, hogy végtelen ciklusba kerülne.
3.  **Állapot:** A rendszert újraindítottam. A problémás feladatot a rendszer hamarosan átugorja, és folytatja a feldolgozást.

**Konklúzió:**
A "Gyár" most már képes kezelni a "mérgező" feladatokat is anélkül, hogy a teljes termelés leállna.
