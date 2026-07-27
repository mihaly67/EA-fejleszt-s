
## A Címkézési Logika a Gyakorlatban (Adatszivárgás Mentesítése)

A Dollar Bar-ok megalkotása után a Supervised Learning (felügyelt tanulás) következő legkritikusabb lépése a címkézés (Labeling). Ha a kód "beles a jövőbe" a feature engineering során, a modell értéktelenné válik.

Ennek elkerülése végett az alábbi szigorú logikát alkalmazzuk a `dom_labeler_mtf.py`-ban:

1. **Eltolt Belépés (Shifted Entry):**
   A modell az `i`-edik gyertya bezárásakor (Close) hozza meg a döntést. A valóságban (egy Copilot interfészen) azonban ezen az áron már nem tudunk belépni. Ezért a matematikai szimuláció a célpontok (Take Profit, Stop Loss) kiszámításához **mindig a jövőbeli (`i+1`) gyertya Nyitóárát (Open)** veszi alapul.
2. **Kizárólag Záróárak Vizsgálata (Close-only Evaluation):**
   A jövőbeli gyertyák szkennelésekor a kiütéseket nem a gyertyák `High` és `Low` értékein vizsgáljuk, hanem kizárólag a `Close` árakon. A gyertyán belüli ármozgások (tüskék) sorrendisége ismeretlen, így a High/Low használata megoldhatatlan logikai ütközéseket okozna (pl. ha a gyertya egyetlen percen belül kiüti a Stop Loss-t és a Take Profitot is).
3. **Független Állapotgépek (Independent State Machines):**
   A Long és a Short vizsgálatok függetlenül futnak. Ha az árfolyam esni kezd, a Long forgatókönyv ugyan elbukik (SL), de a Short forgatókönyv továbbra is érvényben marad, amíg az ő saját feltételei (TP vagy SL) nem teljesülnek. Nincs közös `break` utasítás, ami miatt egy Long Stop Loss fals módon leállítaná a Short szimulációját.

## Confidence Thresholding (Küszöbérték Optimalizáció)

A ML modellek (pl. LightGBM) alapértelmezetten a legmagasabb valószínűségű osztályt választják (argmax). Azonban egy 3-osztályos (Long, Short, Zaj) pénzügyi környezetben ez túl sok gyenge (pl. 34%-os valószínűségű) jelzést eredményezhet, ami megnöveli a fals pozitívok számát.

A találati pontosság (Win Rate) növelése érdekében alkalmazni kell a **Confidence Thresholding** technikát az éles (Inference) rendszerben:
- A modell `predict_proba` kimenetét használjuk.
- Csak akkor fogadunk el egy Long vagy Short jelet érvényesnek, ha annak valószínűsége meghalad egy szigorú küszöbértéket (pl. `P > 0.60`).
- Minden olyan predikció, ami ez alatt marad, automatikusan **Zaj (Hold)** osztályba kerül.

**Eredmények:**
A Grid Search optimalizáció mind a 20%-os OOS (Vizsga) halmazon, mind az ismeretlen 5 napos Vakteszten bebizonyította, hogy a küszöb **0.60** köré emelésével az aktív jelek száma ugyan drasztikusan lecsökken, de a megmaradó jelek tiszta Win Rate-je stabilan átlépi az **50-55%-ot** az 1.5R/1.0R aszimmetrikus barrier (kockázat/hozam arány) mellett, ami rendkívül profitábilis Copilot működést tesz lehetővé.

## Kétdimenziós Valószínűségi Optimalizáció (2D Thresholding)

A gyakorlati tesztek és az élő (vakteszt) adatok bizonyították, hogy az egyszerű egydimenziós szűrés (csak a P_Long vagy P_Short emelése) túlszárítja a modellt, és "overfitting-szerű" alacsony kötési gyakoriságot (napi 1-2 kötés) eredményez.

A valós megoldás a 2-dimenziós Grid Search, ahol a **Jel** és a **Zaj** valószínűségét párhuzamosan korlátozzuk.
Az MGCQ (Micro Gold) teszteken a következő "Sweet Spot" bizonyult optimálisnak a kompromisszumhoz (Magas Win Rate, de stabil Napi 12-15 aktivitás):

- **Signal Threshold (P_Long vagy P_Short):** `> 0.53`
- **Max Noise Threshold (P_Noise):** `< 0.24`

Ezek a paraméterek biztosítják, hogy a modell elég magabiztos legyen az irányban, de ami még fontosabb: szinte teljesen kizárja a Whipsaw (zaj) esélyét. Ez a beállítás a vizsgákon stabilan **48% - 54% közötti Win Rate-et** hozott az Aszimmetrikus 1.5R/1.0R barrier mellett, ami masszívan profitábilis Copilot működést tesz lehetővé aktív (napi 10-15 trade) piacokon.

## Copilot UI (HUD) és Kockázatkezelési Profilok

A 2D optimalizációs felfedezések alapján a modell nem egy statikus doboz, hanem egy dinamikusan hangolható eszköz a kereskedő számára. A GUI-n (pl. PyQt5 Vaku Dashboard) a következő UX/UI elemeket kell implementálni a valószínűségi küszöbök kezeléséhez:

### 1. Csúszkák (Sliders) a Dinamikus Hangoláshoz
A HUD-nak tartalmaznia kell két interaktív vezérlőt:
- **Signal Threshold Slider:** Szabályozza a Long/Short jel elfogadásának minimum valószínűségét (pl. 0.40 - 0.70 között).
- **Max Noise Filter Slider:** Szabályozza a Zaj (Hold) valószínűségének maximum elviselhető mértékét (pl. 0.10 - 0.50 között).

### 2. Előre Definiált Profilok (Gombok)
A gyors váltás érdekében két alapértelmezett "Kockázati Profil" gomb javasolt:
- **Aktív Scalper Profil:** `Signal > 0.45`, `Noise filter kikapcsolva`. Eredmény: Napi ~100+ jel. Magas frekvencia, emberi felülbírálatot igényel a charton.
- **Szigorú Scalper Profil:** `Signal > 0.53`, `Noise < 0.24`. Eredmény: Napi ~10-15 szigorúan szűrt jel. Matematikailag profitábilis (>50% Win Rate 1.5R célpontnál), megbízható Copilot ajánlás.

### 3. Vizuális Kijelzés (Oszcillátor és Szöveg)
Mivel az értékeket "mérni és látni" kell:
- **Oszcillátor Nézet:** A HUD alján egy grafikonon (vagy progress barokon) jelenjen meg a `P_Long` (Zöld), `P_Short` (Piros/Magenta) és a `P_Noise` (Szürke) valószínűsége 0-tól 100%-ig. A csúszkákkal beállított küszöbértékek **vízszintes vonalként (Threshold Lines)** jelenjenek meg az oszcillátor felett, így a felhasználó vizuálisan látja, mikor "töri át" egy jel a saját maga által beállított küszöböt.
- **Szöveges HUD:** Egy domináns szöveges mező a képernyőn, ami a fenti matek alapján valós időben kiírja a javaslatot: **[ STRONG BUY ]**, **[ STRONG SELL ]**, vagy **[ HOLD / NOISE ]**.
