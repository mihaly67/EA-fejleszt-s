# Marcos Lopez de Prado's Information-Driven Bars Methodology

## Helyzetértékelés (A jelenlegi adatstruktúra problémája)
A `Merkava_Data_Miner_MTF_v1.07.mq5` kód vizsgálata során kiderült egy alapvető ellentmondás a Prado-módszertan és a jelenlegi adatelőállítás (data mining) között:

A Data Miner script jelenleg **másodperces (1 másodperces) "bucket"-ekbe** (időablakokba) aggregálja a tickeket:
```mql5
ulong tick_second = tick_time_ms / 1000;
if(current_second_bucket != tick_second) { ... file write ... }
```
Ez azt jelenti, hogy a kapott `Merkava_MTF_GCE_Data.csv` fájl **NEM nyers (raw) tickeket tartalmaz**, hanem 1 másodperces *Time Bar*-okat.

Marcos Lopez de Prado *Advances in Financial Machine Learning* című könyvének legelső és legfontosabb alaptétele, hogy az **időalapú mintavételezés torzítja a gépi tanulási modelleket**, mert a piac nem kronologikus időben (másodpercek), hanem az információ beérkezése alapján (kötések/tickek) mozog.

Ha mi a Python `prado_dollar_bars.py` kóddal ebből a másodpercesre aggregált CSV-ből próbálunk fix darabszámú (pl. 10 sor = 1 Tick Bar) "Tick Barokat" építeni, akkor az **továbbra is torz (időfüggő) marad**, hiszen egy másodperces sorban lehetett 0 kötés és 500 kötés is.

## A Helyes Megoldás Lépésről Lépésre

### 1. Az MQL5 Data Miner átírása (Nyers Tick-szintű kimenet)
Az MQL5 scriptnek abba kell hagynia a másodperces aggregációt. Kizárólag a kötéseket (Trade Ticks) kell kimentenie, ahogy a RAG memória is írja (`flags & TICK_FLAG_VOLUME`).

### 2. Tick Bar-ok generálása (Python)
A módosított CSV-ből, ami immár tisztán minden kötést 1 sorként tartalmaz, a `prado_dollar_bars.py` létrehozza a Tick Bar-okat:
- Bekér egy $T$ értéket (pl. $T = 100$).
- Pontosan 100 kötés (tick) után lezár egy "Tick Bar"-t, így az idődimenzió teljesen eltűnik.

### 3. Dollar Bar-ok generálása (Python)
A keletkezett Tick Bar-okon végigmegyünk, és összeadjuk a dollárértéket (`Kötési Volumen * Középár`). Ha ez eléri a megadott küszöbértéket (pl. $444,000), lezárjuk a "Dollar Bar"-t.

Ezzel a lánccal (Raw Tick -> Tick Bar -> Dollar Bar) biztosítható, hogy a modell valóban információ-alapú környezetben tanuljon, mentesülve az éjszakai/oldalazó időszakok mesterséges zajától (zéró volumenű másodperces gyertyák).
