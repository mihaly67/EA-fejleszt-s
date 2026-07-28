# Session Handover Report - 2026.07.28. (Optuna Hiperparaméter Hangolás Előkészületei)

## 1. Előző Session Eredményei (Current State)
Az előző szakaszban egy rendkívül mély, analitikus hibafeltárást (Error Analysis) végeztünk el a LightGBM algoritmus döntésein a brutális volatilitású 5 napos OOS vizsgaadaton.

A legfontosabb megállapításaink (Ezek KŐBE VANNAK VÉSVE):
1. **A Munka Könyvtár Megváltozott:** A korábbi, káosszal terhelt könyvtárat hátrahagytuk. A tiszta, szűz munkakörnyezet a VPS-en a `/home/misi/LGBM_mlops/`. Minden adat és modell ebben él. A kódkörnyezet a `venv_3MTF`.
2. **Kizárólag 3MTF Struktúra:** Bizonyítást nyert, hogy a 6 makro szint (1-60m) megbénítja a rendszert. A végleges beállítás: M15 és M30 oszcillátorok (RSI, BB, MACD, ROC, MFI) és távolságok (Dist_5m, Dist_15m, Dist_30m). **Szigorú fájlnév konvenció: minden kód és adatfájl tartalmazza a `_3MTF` jelölést!**
3. **Anti-Overlabeling Címkézés:** A rendszer "butaságának" okát megtaláltuk: az algoritmus túltanult a trendek derekán keletkezett redundáns jeleken. A bevezetett `dom_labeler_3MTF_v2.py` sikeresen kigyomlált több tízezer ismétlődő, szorosan (1.0 ATR-en belül) egymást követő címkét, így a gép csak a tiszta kitörési pontokat tanulja.
4. **A "Soft Win" Paradoxon:** Bebizonyítottuk, hogy a nyers Win Rate (pl. 44%) azért alacsony a vizsgákon, mert a modell irányított lendületet (Momentum) azonosít be jól, de a vizsgázó 1.5R/1.0R barrier túl merev a gyertyán belüli (intra-bar) viharokhoz. A gép által adott jelek több mint 55%-a valójában elér egy nyereséges szakaszt (>0.75R). Ezt a kereskedőnek (mint a Copilot parancsnokának) kell menedzselnie csúszó stopokkal. Sem a Target (1.5R), sem a Stop (1.0R) paraméterén NEM változtatunk a bróker költségek (15 USD/10 USD) miatt.

## 2. A Következő Session Feladata (Next Steps)
A jelenlegi munkakönyvtár patyolat tiszta. Rendelkezésre áll a letisztított (redundancia-mentes) adathalmaz és az alap LightGBM modell. A vizualizációs lépéseket lezártuk.

**A Feladat az új Session-ben:**
A meglévő, letisztított adathalmazon és környezetben elindítani egy **Optuna Hiperparaméter Optimalizációt**.

**Lépések:**
1. A VPS-en a `/home/misi/LGBM_mlops/src` mappában egy új, dedikált szkript (`optuna_optimizer_3MTF.py`) írása.
2. A szkript feladata, hogy a `labeled_dollar_bars_3MTF_v2.csv` (a 2 hónapos, megtisztított tanuló adathalmaz) felhasználásával, Purged K-Fold Cross Validation mellett megtalálja a legoptimálisabb LightGBM paramétereket (pl. `num_leaves`, `max_depth`, `learning_rate`, `min_data_in_leaf`, `feature_fraction`).
3. Az Optuna futás célja, hogy kihozza a maximális stabilitást a 3MTF adatokból.
4. A legjobb paraméterek elmentése és a modell újra-tanítása ezen paraméterekkel.

**FIGYELEM AZ ÚJ AGENTNEK:** Ebből az állapotból TILOS visszalépni. A címkézési szabályokat, az adathalmazt, a könyvtárat és a 3MTF konvenciót TILOS módosítani vagy felülírni. Csak az Optuna fejlesztésre szabad fókuszálni!

## 3. Optuna Tesztelési Fájlok (24 Órás Szeletek)
A felhasználó kérésére az Optuna hyperparaméter hangolást és a jövőbeli teszteléseket **NEM** kell a teljes, nehézkes 5 napos fájlon végezni. Ehelyett két gondosan szeparált 24 órás szelet áll rendelkezésre a `/home/misi/LGBM_mlops/data/` mappában:
- `exam_24h_volatile_3MTF.csv`: Extrém magas volatilitású nap (~1595 Dollar Bar, rengeteg wihpsaw és "Soft Win").
- `exam_24h_calm_3MTF.csv`: Nyugodt, közepes volatilitású nap (~1441 Dollar Bar).

**A következő session célja**, hogy az Optunával olyan paramétereket találjon, amik mindkét piaci rezsimet (viharos és nyugodt) stabil >50%-os (vagy az elérhető legmagasabb "Soft Win"-nel kompenzált) pontossággal tudják lekereskedni.
