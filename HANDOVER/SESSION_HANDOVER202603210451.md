# SESSION HANDOVER: 20260321_REALTIME_STREAMING

**Dátum:** 2026.03.21
**Státusz:** 🔥 Áttörés & Paradigmaváltás: "Mozgókép" (Real-Time Streaming) a "Fénykép" (Offline Profiling) helyett.
**Kódnév:** Projekt "Önadaptív Látótér" - Valós idejű kihívások

## 1. Műveleti Összefoglaló (A Jelenlegi Állapot)
Sikeresen implementáltuk és teszteltük a `run_streaming_simulation.py`-t (Virtual Clock Streamer), amely a korábbi statikus, egyben betöltött CSV fájlok (a "Fénykép") elemzését egy eseményvezérelt, soronként adagolt adatfolyammá (a "Mozgókép") alakította.
A hálózatunk (Rolling LSTM Autoencoder) most már egy `deque` alapú csúszóablakban (Sliding Window) tárolja az utolsó `N` ticket, és képes menet közben, a "virtuális" idő múlásával újrakalibrálni a saját látóterét (Szekvenciahossz) és érzékenységét (Reconstruction Error Threshold). A hálót felkészítettük a `nan` (Exploding Gradients) hibák ellen a `clipnorm` alkalmazásával az Adam optimalizálóban.

**A Felismerés (A Probléma):**
A tegnap éjszakai (döglődő, alacsony volatilitású) piacon rögzített `11 perces` adat tesztelése során a `dtaianomaly` csomag Fourier (FFT) és Autokorrelációs (ACF) algoritmusai **tévedtek**. Míg az emberi szem (és a teljes CSV-t látó Profiler) egyértelműen látta, hogy az ideális szekvenciahossz a manipulatív oszcilláció (színész) kiszűrésére `120 tick`, addig az online FFT algoritmus `84 ticknél` "rövidlátóvá" vált.
Ennek oka, hogy a lapos piacon a brókeri "rám-ugrás" (Anomaly) nagyon ritkán történt meg, és a matematikai képletek a kis ablakban nem találtak domináns frekvenciát.

## 2. A Paradigmaváltás (A Felhasználó Zseniális Meglátása)
A felhasználó rávilágított a valódi MetaTrader 5 (MT5) Expert Advisor működési logikájára: az idő nyila előre halad.
Amikor az EA elindul, **vak**. Nincs "múltja", amiből a `dtaianomaly` számolhatna. Két kritikus fázis van:

1.  **Bemelegedési Fázis (Warm-up / Memory Fill):** Az indulás pillanatában az EA-nak meg kell határoznia, hogy a jelenlegi piaci állapot (pl. Volatilitás, Tick Sűrűség) alapján mekkora "Emlékezetre" (Tick Szekvencia Hossz) lesz szüksége a tisztánlátáshoz. (Pl. Pörgős híresemény: elég 40 tick. Döglődő éjszaka: kell a 150 tick). Az EA-nak várnia kell, amíg ez a `deque` (Rolling Window) megtelik a valós időben érkező tickekkel, és addig **szünetelteti a kereskedést**.
2.  **Folyamatos Mozgókép Elemzés (Rolling Inference):** Amint az "emlékezet" megtelt, az LSTM minden egyes új ticknél (vagy tick-csoportnál) kilöki a legrégebbit, befogadja az újat, és a "Jelenből a Múltba visszanézve" (mint egy ember a charton) megállapítja: "Ez most egy valós piaci kitörés, vagy a bróker manőverezik ellenem?"

## 3. A Következő Ügynök Feladata (A Gemini Mélykutatási Missziója)
A cél már nem a `dtaianomaly` sötétben tapogatózása, hanem egy **robosztus, LLM-szerű (Gördülő Memóriaablak) valós idejű adaptációs rendszer** kidolgozása a streaming tickadatokra.

**A Feladat:**
Olvasd át ezt a Handovert, és indíts egy Mélykutatást (Deep Research / RAG Interrogation) a következő kérdéskörökben, hogy kidolgozzunk egy architekturális megoldást a Valós Idejű MT5 Bridge-hez:

1.  **Korreláció a Piaci Állapot és a Szekvenciahossz között:** Hogyan tudjuk a Profilerünk által generált múltbeli eredményekből (pl. 40 tick vs 150 tick ideális ablak) kinyerni azokat a **Jelenlegi** (pillanatnyi) indikátorokat (Volatilitás, Szórás, Tick/Sec), amik alapján az EA *induláskor azonnal* tudni fogja, mekkora ablakot kell feltöltenie?
2.  **A "Mozgókép" (Sliding Window) LSTM Architektúra az MT5-höz:** Hogyan kezeljük a legoptimálisabban a Keras LSTM modellt élőben? Tickenként lépjünk előre (nagyon magas CPU igény), vagy tick-csoportonként (Mini-Batch streaming)? Hogyan oldják meg az LLM-ek a "Context Window" folyamatos frissítését úgy, hogy ne veszítsék el a mikro-trendeket?
3.  **Online vs Episodic Learning:** Szükségünk van-e arra, hogy a modell valós időben "újratanulja" (Online Learning / Súlyok frissítése) az elmúlt óra adatait (hogy alkalmazkodjon a napközbeni Drift-hez), vagy elegendő a fixen betanított Encoder-en csak a `Threshold`-ot (Küszöbértéket) dinamikusan tologatni a pillanatnyi volatilitás alapján?

Ezt az elemzést a Gemini (Vagy a következő ügynök) végezze el a SWAT4 RAG és az ipari standardok (pl. River, Time Series Anomaly Detection) alapján! Ne írj kódot, amíg ez az elméleti fundamentum nem tisztázott és elfogadott a felhasználó által!

**Készítette:** Jules (Szakértő Szoftvermérnök Agent)
