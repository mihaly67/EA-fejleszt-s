# MQL5 DATA MINER SCRIPT SPECIFICATION (OFFLINE/WEEKEND EXTRACTION)

**Author:** Jules
**Target:** MQL5 Agent (Next Session - Side Branch)
**Objective:** Készíteni egy működőképes MQL5 eszközt, amely zárt piacokon (hétvégén) és nyitott piacokon is képes visszamenőleges tick- és indikátoradatokat kinyerni és a `BlackBox` segítségével CSV-be írni. Amíg ez nincs meg, a fő ML (Machine Learning) szál nem tud folytatódni!

---

## 1. A Probléma Háttere (The Problem)

A korábbi próbálkozások során a `Merkava_Data_Miner_v1.0.mq5` (mint Expert Advisor) kudarcot vallott a hétvégi történelmi adatgyűjtésben két okból:
1. **EA Korlátok:** Ha a tick-letöltő `for` ciklust az `OnInit()`-be tettük, a MetaTrader 5 "Initialization takes too long" (3 másodperces limit) hibával megölte a programot. Ha az `OnTick()`-ben hagytuk, hétvégén (mivel nincs beérkező élő tick) a kód sosem futott le.
2. **Múltbeli Indikátor Olvasás (A fő hiba):** Amikor az adatokat az `OnInit()`-en belül, a `CopyTicksRange` által visszaadott történeti tick-eken iterálva nyertük ki, a `m_nav_system.Refresh(ticks[i])` után meghívott indikátor lekérések (`CopyBuffer(handle, 0, 0, 1, buffer)`) **végig ugyanazt a konstans, jelenlegi (legutolsó) indikátorértéket adták vissza** az 1 millió történelmi sornál is!
   *Ennek oka, hogy a `CopyBuffer` 0-ás indexe egy élő charton mindig a jelen pillanatot jelenti, a MetaTrader engine nem szimulálja visszafelé az időt egy egyszerű For-ciklus kedvéért.* A teszterben (Strategy Tester) működne, de a felhasználó könyvtárszerkezete miatt a teszter használata jelenleg nem megoldható.

---

## 2. A Feladat (The Task)

A következő ügynök feladata **LÉTREHOZNI EGY MQL5 SCRIPTET** (nem EA-t!), például `MQL5/Scripts/Merkava_Offline_Miner.mq5` néven, amely képes helyesen letölteni a múltbeli tickeket és a hozzájuk tartozó pontos múltbeli indikátor értékeket egy aktív vagy inaktív chartról.

### Követelmények és Megoldási Javaslatok (Guidelines)

1. **Script Architektúra (`OnStart`):**
   Mivel a Scriptek az `OnStart()` metódusban futnak, rájuk **nem vonatkozik az `OnInit` 3 másodperces időkorlátja**, és lefutnak azonnal ráhúzáskor (akár hétvégén is). A teljes adatletöltő (`CopyTicksRange`) iterációs ciklust ide kell helyezni.

2. **Idő-szinkronizált Indikátor Olvasás (A Kulcs):**
   A legfontosabb feladat a `NavSystem` vagy a `Script` indikátor-lekérő logikájának megváltoztatása úgy, hogy ne a `0`-ás indexet (jelent) kérje le!
   * Amikor iterálsz egy történelmi ticken (`ticks[i]`), le kell kérned a tick pontos idejét (`ticks[i].time`).
   * Ezt az időt az `iBarShift(_Symbol, _Period, ticks[i].time)` függvénnyel át kell alakítani egy **gyertya indexszé (shift)** a jelenhez képest (pl. kiderül, hogy az a tick 452 gyertyával ezelőtt volt).
   * Ezt a "shift" értéket kell átadni a `CopyBuffer` hívás start pozíciójának (`CopyBuffer(handle, buffer_num, shift, 1, array)`).
   * *Figyelem:* Ehhez lehet, hogy a `NavSystem` getter-eit módosítani kell, hogy fogadjanak egy `shift` vagy `time` paramétert, vagy a Sriptben kell direktben lekezelni az indikátor handlereket (bár az első az elegánsabb).

3. **Függőségek Betartása (Strict Paths):**
   A felhasználó MetaTrader könyvtárszerkezete rögzített. Az `#include` útvonalak a Scriptből ugyanúgy kell mutassanak a NavSystemre, ahogy az EA tette. A Sripteket a `MQL5/Scripts/` vagy a `MQL5/Indicators/Jules/` mappába is teheted, de az include útvonal (pl. `../Indicators/NavSystem_v2_22.mqh`) a lokális környezethez kell igazodjon. A Custom Indicatorok path-ja továbbra is `"Jules\\"`.

4. **Nincs "Smart Filter":**
   Minden letöltött ticket maradéktalanul be kell írni a CSV-be (a BlackBox segítségével), ahogy a javított Data Miner tette, mert az ML HMM-nek szüksége van az összes mikro-anomáliára.

**Sikerkritérium:** Ha a felhasználó egy szombat délután ráhúzza a Scriptet az EURUSD chartra, a létrejövő CSV fájl tick-enként különböző (és helyes) MACD, EMA és WPR értékeket kell, hogy mutasson, nem pedig egy végtelenül ismétlődő konstans számot.