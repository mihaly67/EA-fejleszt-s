
## A Címkézési Logika a Gyakorlatban (Adatszivárgás Mentesítése)

A Dollar Bar-ok megalkotása után a Supervised Learning (felügyelt tanulás) következő legkritikusabb lépése a címkézés (Labeling). Ha a kód "beles a jövőbe" a feature engineering során, a modell értéktelenné válik.

Ennek elkerülése végett az alábbi szigorú logikát alkalmazzuk a `dom_labeler_mtf.py`-ban:

1. **Eltolt Belépés (Shifted Entry):**
   A modell az `i`-edik gyertya bezárásakor (Close) hozza meg a döntést. A valóságban (egy Copilot interfészen) azonban ezen az áron már nem tudunk belépni. Ezért a matematikai szimuláció a célpontok (Take Profit, Stop Loss) kiszámításához **mindig a jövőbeli (`i+1`) gyertya Nyitóárát (Open)** veszi alapul.
2. **Kizárólag Záróárak Vizsgálata (Close-only Evaluation):**
   A jövőbeli gyertyák szkennelésekor a kiütéseket nem a gyertyák `High` és `Low` értékein vizsgáljuk, hanem kizárólag a `Close` árakon. A gyertyán belüli ármozgások (tüskék) sorrendisége ismeretlen, így a High/Low használata megoldhatatlan logikai ütközéseket okozna (pl. ha a gyertya egyetlen percen belül kiüti a Stop Loss-t és a Take Profitot is).
3. **Független Állapotgépek (Independent State Machines):**
   A Long és a Short vizsgálatok függetlenül futnak. Ha az árfolyam esni kezd, a Long forgatókönyv ugyan elbukik (SL), de a Short forgatókönyv továbbra is érvényben marad, amíg az ő saját feltételei (TP vagy SL) nem teljesülnek. Nincs közös `break` utasítás, ami miatt egy Long Stop Loss fals módon leállítaná a Short szimulációját.
