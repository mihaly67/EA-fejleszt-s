# A LightGBM "Feature Fusion" Architektúra és Adatfolyam: CSV-től a Modell PKL-ig

Ez a dokumentum bemutatja a teljes folyamatot lépésről lépésre, megmagyarázva, hogyan lesz a nyers MT5 adatból (Tick és 1-perces OHLCV) egy betanított, optimalizált és élő kereskedésre kész LightGBM modell.

---

## 1. Az Alapok: Miért kell két külön CSV?

A klasszikus gépi tanulás időalapú gyertyákat (pl. 1 perces) használ. Azonban az algoritmikus kereskedésben ez problémás (kiváltképp a skálp környezetben), mivel az információ és a volatilitás nem egyenletesen oszlik el az időben (például hajnalban 10 perc alatt semmi nem történik, délután 3-kor pedig másodpercek alatt óriási mozgás van).

Ezért **két külön adathalmazra (CSV) van szükség**, amelyek két különböző célt szolgálnak, majd a későbbiekben fuzionálnak:

### A) A Tick szintű / Order Book CSV (Micro szint - A "Cselekvés")
* **Jelleg:** Eseményvezérelt (szinkronizálatlan, aszinkron).
* **Tartalom:** Nyers kötések (Trade Ticks), Bid/Ask volumenek (Order Book Imbalance).
* **Célja:** Ebből képezzük a **Dollár Bárokat (Dollar Bars)**. A dollár bár nem időalapú, hanem forgalom alapú (pl. minden alkalommal, amikor X dollár értékű kötés történik a piacon, lezárul egy gyertya). Ez "kiegyenesíti" a volatilitást: nyugalomban ritkábban, pánikban sokkal gyakrabban záródnak a bárok. Ez adja a modell mikro-momentumszintű belépési jelzéseit.

### B) Az 1-Perces (M1) OHLCV CSV (Macro szint - A "Környezet/Struktúra")
* **Jelleg:** Idővezérelt (kronologikus, pl. percenként pontosan 1 sor).
* **Tartalom:** M1 Open, High, Low, Close, és MQL5-ből kinyert egzakt geometriai szintek (pl. ZigZag pivot távolságok, támasz/ellenállás).
* **Célja:** Ez adja meg a "Nagy Képet" vagy struktúrát. Egy dollár bár (ami mondjuk 5 másodperc alatt alakult ki) önmagában nem "tudja", hogy hol van a napi trendhez vagy egy makro támaszszinthez képest. Az időalapú adatok (Kaufman AMA, Stochastic 2,3,3, ZigZag távolságok) szolgáltatják ezt a kontextust.

---

## 2. Az Adat-transzformáció és a "Feature Fusion" (A Feldolgozás Lépései)

A folyamat Python szkripteken keresztül halad végig (a `LGBM_mlops` struktúrában a szerveren).

### Lépés 2.1: Dollár Bárok Képzése (A Mikro Szint)
**Felelős kód:** `prado_dollar_bars.py`
A nyers tick CSV-t beolvassa a program. Első lépésben "Tick Bárokat" készít (pl. 10 kötésenként egy gyertya), majd ezen bárok (Volume * Ár) kumulációjával megalkotja a **Dollár Bárokat**.
* *Kimenet:* Egy DataFrame, amelynek sorai egy-egy Dollár Bár, amihez hozzá van csatolva a zárás pontos milliszekundumos időbélyege (`End_Timestamp`).

### Lépés 2.2: Makro Geometriai Képződmények (A Makro Szint)
**Felelős kód:** `macro_feature_engineer.py` és (pl. `kaufman_ama.py`)
A rendszer az 1-perces (M1) CSV-ből kiszámolja a strukturális mutatókat. Itt NEM használunk lassú, időalapú lagging indikátorokat (mint pl. 15 perces RSI). Helyette gyors **Stochastic (2,3,3)**, **Kaufman AMA** és **ZigZag távolságokat** számolunk.
Kritikus: Ezeket a távolságokat az aktuális volatilitással, azaz az **ATR**-el normalizáljuk (pl. `(Close - AMA) / ATR`), hogy a modell mindig relatív, "matematikailag befogadható" értékeket lásson, ne nyers dollár távolságokat.
* *Kimenet:* Egy időalapú DataFrame M1 pontossággal.

### Lépés 2.3: A Nagy Fúzió (Merge AsOf)
Hogyan egyesítjük a forgalom alapú bárokat az idő alapú bárokkal anélkül, hogy a jövőbe látnánk (Lookahead Bias)?
A Pandas **`merge_asof`** függvényét használjuk.
Minden egyes Dollár Bár lezárásakor (pl. 14:03:22-kor) a program visszanéz a makro (M1) adatbázisba, és **kikeresi az utolsó, már lezárt 1-perces gyertyát** (tehát a 14:03:00-ás, vagy 14:02:00-ás adatot, attól függően mikor zárt). Ezt a strukturális információt (ZigZag, AMA, Stochastic) "ráragasztja" a dollár bár mellé.
*Így a mikro mozgás megkapja az akkori aktuális makro kontextust.*

### Lépés 2.4: Címkézés (Triple-Barrier Aszimmetrikus Célpontok)
**Felelős kód:** `dom_labeler_v5.py`
Meg kell mondanunk a gépnek, hogy mi volt a jó belépő. Mivel a mikro-trendek (a skálpolásban) hamar elhalnak, a cél egy **5 gyertyás (5-bar) horizont**.
A címkéző egy **Aszimmetrikus Triple Barrier** rendszert használ (pl. Take Profit: 1.5 ATR, Stop Loss: 1.0 ATR).
* Kiemelten fontos: A `v5` verzió már nem a záróárat, hanem az **intra-bar (gyertyán belüli) High/Low (Wick/Kóc) árakat figyeli**. Ha az árfolyam felszúr a Profitba, de előtte egy tüske kivette a Stop Losst, az a kötés érvénytelen (zaj/0).
* *Eredmény:* Minden Dollár Bár kap egy Y értéket: `+1` (Sikeres Long), `-1` (Sikeres Short), vagy `0` (Zaj/Stoppolódott).

---

## 3. A Tanítás és a 4D Optuna Optimalizáció

### Lépés 3.1: LightGBM Tanítás
**Felelős kód:** A fő LightGBM tréner szkript (pl. `train_lgbm_fusion.py`)
A fuzionált adathalmazt (X) és a kiszámolt célpontokat (Y) betápláljuk a LightGBM algoritmusba. A LightGBM nem egyetlen döntést hoz, hanem **valószínűségeket (Probabilities)** ad vissza minden kimenetre:
* `P_Long` (pl. 0.42)
* `P_Short` (pl. 0.18)
* `P_Noise` (pl. 0.40)

A klasszikus megközelítés (pl. ami a legnagyobb, az a nyertes) a 3-osztályos skálp problémánál elbukik, mert a piac aszimmetrikus ("a bikák lépcsőznek, a medvék ablakon ugranak"), és az adatok zajosak.

### Lépés 3.2: 4D Aszimmetrikus Küszöbérték Optimalizálás (Optuna)
Ahelyett, hogy a nyers modellkimenetet használnánk, bejön az Optuna. Az Optuna egy kereső algoritmus, ami megtalálja azokat a pontos valószínűségi küszöbértékeket, ahol a rendszer valóban nyereséges.
Négy paramétert optimalizál egyidejűleg (4D dimenzió):
1. **`P_Long_Min`**: Mi a minimum Long valószínűség, hogy egyáltalán belépjünk? (pl. 0.55)
2. **`P_Noise_Max_Long`**: Bármilyen jó a Long esély, ha a Zaj valószínűsége efelett van (pl. >0.30), letiltja a kötést.
3. **`P_Short_Min`**: Mi a minimum Short valószínűség? (mivel a shortok agresszívebbek, ez lehet alacsonyabb is, pl. 0.45)
4. **`P_Noise_Max_Short`**: A Shortoknál megengedett maximális zaj (pl. 0.35).

Az Optuna lejátssza ezeket a küszöböket a validációs (Test) adatokon, és addig tekeri a potmétereket, amíg maximalizálja az Aktív Szignálok Nyerési Arányát (Win Rate), de úgy, hogy megtartson egy minimális tranzakciószámot (hogy ne csak napi 1 kötés legyen).

---

## 4. A Végeredmény: A Modell PKL Fájl

Amikor az Optuna megtalálja a tökéletes küszöböket, és a LightGBM modell (booster) befejezi a tanítást, a teljes "agy" lementésre kerül:

1. A modell magja: Egy `.pkl` (vagy LightGBM `.txt`/`.json` formátumú) fájl, ami tartalmazza a döntési fákat. (pl. `model.get_booster().save_model('lgbm_fusion.txt')` vagy `joblib.dump()`)
2. A felskálázásokhoz/Normalizáláshoz használt Scalerek (pl. StandardScaler).
3. A kimentett Optuna 4D Threshold értékek, amiket egy JSON config fájlban vagy magában az élő (Live) kód konstansaiként mentünk el.

Az élő kereskedési rendszer (az MT5 Socket kapcsolat, pl. `mt5_live_copilot.py`) ezt a `.pkl` fájlt olvassa be. Másodpercenként veszi a mikro adatot (Tick), hozzáfűzi (Merge) a legfrissebb makro adatot (M1), átküldi a LightGBM fákon, megkapja a valószínűségeket, ráhúzza a 4D Optuna küszöböket, és ha minden zöld... kirajzolja a szignált a képernyőre!
