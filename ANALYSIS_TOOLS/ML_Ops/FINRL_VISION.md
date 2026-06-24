# A VAKU 3.0 JÖVŐKÉPE: AZ ONLINE (LIVE) COPILOT ARCHITEKTÚRA

**A Jelenlegi Helyzet (Statikus / Offline Validáció):**
Jelenleg a Vaku 3.0 (és a Labeler) statikus fájlokon dolgozik (pl. 15 tickes ablak a HMM számára, 10 tickes jövőbetekintés a Labelerben). Ez kiválóan működött a késő esti (22:00), alacsony likviditású és alacsony tick-sűrűségű (Tick Density) CSV fájlokon, ahol a bróker elsődleges manipulációs fegyvere a *Tick Lefagyasztás* (Latency) volt.
Azonban a nappali (pl. 20:00), aktívabb piacokon a tick-sűrűség sokszorosára ugrik, így a bróker beavatkozása (a rángatás, azaz Whipsaw) nem fér bele a fix 10-15 tickes ablakba, ami torzításhoz vezet.

**Az 1. Mérföldkő: Dinamikus Időablak (Tick Density Profiling)**
Mielőtt online működésbe kapcsolnánk, a rendszernek fel kell ismernie a napszakot a tick-sűrűség alapján. Erre jött létre a `profile_tick_density.py` kutatási script, ami megméri:
- A Makro Átlagsebességet (Tick/sec a teljes sessionre)
- A Mikro Csúcssebességet (P50/P90)
Ez az eszköz képes kiszámolni egy **Dinamikus Ablakméretet** a HMM és a Címkéző számára. Így a modell képes lesz arra az utasításra, hogy: *"Ne 15 ticket vizsgálj előre, hanem 3 másodpercnyi fizikai időt!"* (Legyen az éjjel 6 tick, nappal pedig 150 tick).

---

## A Végleges Cél: A "Copilot Copilotja" (Online FinRL Integráció)

Amikor az offline tesztelés befejeződik, az architektúra egy élő, **Online Copilot** rendszerré fejlődik. Ennek a Copilotnak két szintje lesz, amelyek szinergiában dolgoznak a 8GB RAM-os VPS limitált erőforrásain:

### 1. A Viselkedési (Behavioral) Copilot (A Jelenlegi Vaku 3.0)
Ez a szint felel a **Situational Awareness**-ért (Állapotfelmérés). Nem prediktálja az árat, hanem valós időben "szimatol" a bróker ujjlenyomatai után.
*   **Bemelegítési (Warm-up) Fázis:** Az online indulás első N percében csak olvassa a tick-sűrűséget és a spread eloszlást. Ebből valós időben adaptálja a HMM ablakméretét és a Címkéző P90 küszöbeit (Adverse Excursion, Whipsaw).
*   **Azonnali Diagnózis:** Egy algoritmikus nyitás pillanatában futtatja a dinamikusan méretezett HMM Viterbi dekódolást, és azonnal kiált, ha a bróker a tiszta trendet ("Betonfal") internalizálja ("Színház").

### 2. A Pénzpiaci (FinRL) Copilot (A Jövőbeli Irány)
A HMM csak annyit mond meg, hogy "Baj van, a bróker ellened játszik." De a döntést (Tartsam a pozíciót? Zárjam be azonnal? Duplázzak rá?) egy Financial Reinforcement Learning (FinRL) ügynöknek kell meghoznia.
*   **Az Összeköttetés:** A Vaku 3.0 kimenete (a HMM állapot ID: `[0, 1, 2]`) egyenesen belemegy a FinRL Agent Állapottérébe (State Space).
*   **A "Copilot Copilotja":** A FinRL Agent (pl. egy PPO vagy SAC modell) így nem vakon kereskedik a nyers árakon, hanem "látja" a bróker viselkedését. Megtanulja, hogy ha a Vaku 3.0 "Színház" (Manipuláció) állapotot jelez egy egyébként emelkedő piacon, akkor az adott stratégiát azonnal szüneteltetni kell, míg "Betonfal" állapotban érdemes növelni a kitettséget.

**A VPS Teljesítmény (Hardware Constraints) Biztosítása Online Módban:**
Hogy a 8GB RAM és a CPU kibírja ezt a dupla Copilot terhelést:
1. Az Adatfolyam kezelését (Tickek) C++ / MQL5 oldalon kell tartani.
2. A Python oldal egy `collections.deque` (vagy `NumpyRingBuffer`) memóriával csak az utolsó (dinamikus méretű) X ticket tartja a memóriában O(1) sebességgel frissítve (Welford Algoritmus).
3. A FinRL Agent predikciója (Action inference) szintén O(1) mátrixszorzás, míg a betanítása offline történik a letöltött CSV-k címkézett "Smoking Gun" bizonyítékain.
