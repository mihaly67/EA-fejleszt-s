# ÉLŐ (LIVE) ARCHITEKTÚRA ÉS HUD TERVEZET: 3-Paraméteres Dollar Bar Scalping

Ez a dokumentum a már bizonyítottan működő, ML-alapú 3-paraméteres (M15, M30 makro) LightGBM prediktív modell éles, valós idejű (Real-Time) MT5 környezetbe történő integrációját írja le.

---

## 1. Az Adatfolyam és Inicializálás (Bemelegítés)

A valós idejű Dollar Bar generálás és feature számítás (pl. 100-as periódusú Z-Score-ok, mozgóátlagok) megköveteli a "bemelegítést" (Warm-up). Azonnal nem lehet predikciót mondani az első élő tickre.

### MQL5 EA (Expert Advisor) Feladata:
Az MT5 EA (ZMQ vagy nyers TCP socketen, pl. port: 5556) keresztül kommunikál a Python backenddel.
- **START (Init) Fázis:** Az EA indulásakor a `CopyTicks` függvénnyel lekér minimum 15,000 korábbi történelmi ticket (ami elegendő legalább ~1000 Dollar Bar létrehozásához, hogy a 100-as mozgóátlagok beálljanak).
- Ezt a batch-et egy "WARMUP" csomagként egyben átküldi a Pythonnak.
- Ezzel párhuzamosan lekéri a történelmi M15 és M30 gyertyákat, és elküldi a nyitás pillanatában érvényes Close árakat.
- **LIVE Fázis:** A bemelegítés nyugtázása után az EA átáll `OnTick` eseményvezérelt módra, és minden egyes árváltozást vagy volumenváltozást (TICK_FLAG_VOLUME) élőben streamel (pl. `TICK|Bid|Ask|TradeVol|M15_Close|M30_Close|Timestamp`).

---

## 2. Python Backend: Live Dollar Bar Engine

A Python oldalnak egy folyamatosan futó szálon (Thread) vagy Aszinkron eseményhurokban kell futnia.

### A feldolgozás logikája (Memóriában):
1. **Adat Ingeszció:** Az `MT5SocketBridge` másodpercenként többezer ticket fogad.
2. **Tick Accumulator (Tick Bar):** A beérkező tickeket (ahogy az offline script is) folyamatosan egy átmeneti `current_bar` szótárba akkumulálja.
3. **Threshold Checker:** Minden új tick után ellenőrzi: `current_dollar_val >= 444000`.
4. **Dollar Bar Lezárása:** Ha a határt átlépte:
   - A gyertya "Close" állapota rögzül.
   - Bekerül egy fix méretű FIFO (First-In-First-Out) memóriapufferbe (pl. `collections.deque(maxlen=200)`).
   - A FIFO pufferből az utolsó lezárt gyertyára **azonnal lefuttatja a Feature Engineeringet** (kiszámolja az M15/M30 RSI-t, BB Z-score-t a lezárt adatokból, kiszámolja a Dist_15m, Dist_30m és Price Velocity értékeket, megcsinálja a shift(1)-et a jelenlegi predikcióhoz).
5. **Inference (Predikció):** Az azonnal betöltött `lightgbm.Booster` a friss feature vektoron lefut: `predict_proba(X)`.

---

## 3. Döntési Mechanizmus és Biztonsági Szűrők

Az előző vaktesztek és optimalizációk alapján a "Szigorú Scalper" (>= 50% Win Rate) profil a következőket követeli meg a predikcióból kinyert 3 dimenziótól (`P_Short`, `P_Noise`, `P_Long`):

- **Csak akkor küldünk a HUD-ra "ÉRVÉNYES JELET", ha:**
  - VAGY: `P_Long > 0.33` ÉS `P_Noise < 0.27`
  - VAGY: `P_Short > 0.33` ÉS `P_Noise < 0.27`
- Ha ezen a rácson kívül esik a számított valószínűség, a belső állapot `HOLD / NOISE` marad.

*(Fontos: A valós idejű gép sosem "címkéz" Aszimmetrikusan, hiszen a jövőt nem ismeri. A gép csak valószínűségeket köp ki a betanult súlyok alapján).*

---

## 4. PyQt5 HUD (Kijelző / Oszcillátor) Tervezet

Mivel hardveres AVX limitációk vannak, a Streamlit/Web helyett a könnyű `PyQt5` és a `pyqtgraph` (vagy sima QProgressBar) architektúra javasolt a megjelenítésre.

### UI Elrendezés:

1. **Felső Sáv: Státusz és Ár**
   - MT5 Kapcsolat ikon (Zöld/Piros).
   - Jelenlegi Bid/Ask.
   - Élő Dollar Bar státusz (pl. `$312,000 / $444,000` progress bar, ami mutatja mikor záródik a következő gyertya).

2. **Középső Domináns Sáv: AI Döntés**
   - Hatalmas betűkkel az aktuális státusz:
     - 🟢 **STRONG BUY**
     - 🔴 **STRONG SELL**
     - ⚪ **HOLD (NOISE)**

3. **Alsó Rész: Valószínűségi Oszcillátor (A lényeg)**
   - Egy valós idejű oszcillátor görbe (pl. utolsó 50 Dollar Barra visszamenőleg).
   - Három futó vonal: `P_Long` (Zöld), `P_Short` (Piros), `P_Noise` (Szürke folytonos).
   - **Vízszintes küszöbvonalak:** Piros szaggatott vonal `0.27`-nél (Noise Max), és Kék szaggatott vonal `0.33`-nál (Signal Min).
   - A felhasználó vizuálisan látja, ahogy a zöld (Long) vonal "kitör" a 0.33-as küszöb fölé, miközben a szürke (Zaj) vonal bezuhan a 0.27 alá.

4. **Oldalsáv: Vezérlők**
   - Két csúszka (Slider), amelyekkel menet közben finomhangolható a `0.33`-as Signal és `0.27`-es Noise küszöb (így a "Szigorú" módból "Aktív" módba válthat a kereskedő, ha úgy ítéli meg a piacot).
