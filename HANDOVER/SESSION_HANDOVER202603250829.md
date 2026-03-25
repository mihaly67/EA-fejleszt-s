# SESSION HANDOVER: 202603250829 (THE HOLY GRAIL OF THRESHOLDS)

**Dátum:** 2026.03.25 (Belső logikai időbélyeg a kérés alapján: 202603250829)
**Státusz:** 🟢 Stabilizált LSTM, Kész Mátrix Profilozó, Kész Globális Volatilitás Horgony. Egyetlen nyitott, de már behatárolt kihívás maradt a jövőbeli optimalizálásra: A "Szórásmentes Organikus Küszöb" megtalálása.
**Kódnév:** Projekt "Fat-Tail Paradoxon" - A Brókeri Manipuláció Spektruma

---

## 1. Műveleti Összefoglaló (A Legnagyobb Sikereink)

Ez a munkamenet technológiai ugrást jelentett a projektben. Az alábbi kulcsfontosságú "Deep Work" mérföldköveket pipáltuk ki:

*   **A Globális Volatilitás Horgony (Class 1-5):**
    *   Létrehoztunk egy dedikált MQL5 eszközt (`DataMiner_TickExporter_v1_00.mq5`), amely villámgyorsan kimenti akár több hónapnyi nyers tick adatot (Time, Bid, Ask) is.
    *   Elkészült a `calculate_global_volatility.py`, amely 15 millió adatponton (3 hónap XAUUSD) megalkotta a végleges, robusztus, abszolút mérőszámot: egy 5 fokozatú skálát (Dead-től az Extreme-ig).
    *   A Mátrix Profilozó (`run_advanced_profiler.py`) immár ezt a `XAUUSD_Volatility_Scale.json` horgonyt olvassa be, így **véglegesen megszüntettük a lokális, fájlonkénti torz terciliseket** (amikor a döglött ázsiai piac legkisebb rezdülése is "High Volatility" címkét kapott).

*   **Az "Exploding Gradient" (Gradiens Felrobbanás) Felszámolása:**
    *   A szimulációk (Mátrix Profilozó) során a 150-200 tick feletti szekvenciahosszoknál az LSTM `loss` (Reconstruction Error) rendszeresen a `1.3e25` (trilliók) nagyságrendjébe szökött fel, majd `NaN` (Not a Number) hibával összeomlott.
    *   **A megoldás:** Felfedeztük, hogy ezt az LSTM rétegeken expliciten hagyott `activation='relu'` okozta. Mivel a `relu` nem szab felső gátat a cellák állapotának, a hosszú szekvenciák (BPTT - Backpropagation Through Time) exponenciálisan megsokszorozták a hibát. Az eltávolítás után a Keras alapértelmezett, stabil `tanh` (hiperbolikus tangens) aktivációja -1 és 1 közé szorítja a számokat. Továbbá bevezettük a `RobustScaler`-t (a `StandardScaler` helyett) és az `np.clip` védelmet.
    *   **Eredmény:** A hálózat most akár az 500 tickes gigantikus ablakokat is hibátlanul, stabil (0.9 - 1.2 közötti) loss értékekkel darálja le.

*   **Súlyozott SNR (Signal-To-Noise) a Mátrixban:**
    *   A `visualize_matrix.py` kibővült a RAG elvek szerinti Súlyozott Jóság mutatóval. Már nemcsak az a nyerő ablak, amelyik sokszor fúj riasztást a Trade-ek körül (Signal), hanem a győztest az alapján választja ki, hogy a teljes fájlban mennyi fals riasztást generált (Noise / Sűrűség). Ezzel elkerülhető a "vaklárma-győztes".
    *   A tesztelt spektrum 10-től 500 tickig (24 lépcsőben) bővült ki.

---

## 2. A "Fat-Tail Paradoxon" (A Küszöb Kálváriája)

Amikor a `tanh` aktiváció és a `RobustScaler` stabilizálta az LSTM-et, a hálózat olyan "jó és fegyelmezett" lett, hogy a visszaépítési hibák (MSE) extrém módon összenyomódtak és aszimmetrikussá (fat-tailed) váltak. Amikor az "Önszabályozó Küszöböt" (Anomaly Threshold) próbáltuk megtalálni, a hagyományos ipari statisztikák sorra megbuktak:

1.  **A "Szórás" Átka (`Mean + 4*STD`):** Bár a normál adatok alsó 90%-át néztük, a szórás (STD) hatalmas volt az átlaghoz képest (pl. Mean: 0.81, STD: 0.77). Így a négyszeres szorzó az egekbe (3.91) vitte a küszöböt. **Eredmény: 0% találat.**
2.  **A "Medián" Csapdája (`MAD`):** Mivel az LSTM tökéletesen tanulta a "sima" szakaszokat, a medián és a MAD (Median Absolute Deviation) szinte nulla lett. Emiatt a küszöb irreálisan szűk lett (1.74). **Eredmény: 22% fals riasztás (Zaj).**
3.  **Az IQR módszer:** Hasonlóan az 1. esethez, a felső kvartilis elszállt, a küszöb túl magas lett (4.41). **Eredmény: 0% találat.**
4.  **A Scaled P90 (`P90 * 1.25`):** A 90. percentilis (2.24) is túl magasnak bizonyult horgonyként, a küszöb (2.80) ismét áthatolhatatlan volt. **Eredmény: 0% találat.**

**A Jelenlegi Állapot (A 99% Percentilis):**
Kínunkban visszatértünk a gépi tanulás "Unsupervised" szabványához, a fix Kvantilis vágáshoz (`Contamination Rate = 1.0%`). Ez biztosítja a Mátrixnak, hogy minden szekvencia **fixen 1.0% Zajjal** induljon, így sosem lesz se 0%, se 22%.

**A Felhasználó Észrevétele (A Következő Agent Feladata):**
Bár a fix 1.0%-os vágás stabil, *információt vesztünk vele*. A felhasználó jogosan hiányolja a korábbi hálózat (a felrobbanás előtti idők) organikus sokszínűségét, ahol a küszöb 1.0 és 2.0 között mozgott dinamikusan, nem fix 1%-os vágással.

A probléma egyértelmű: **Minden, ami varianciára, szórásra vagy magas percentilisek (P75, P90) differenciájára épül az LSTM-ben, csődöt mond a fat-tail miatt.**

---

## 3. Iránymutatás a Következő Session-re (Next Steps)

A következő Agentnek az alábbi egyetlen pontot kell módosítania az `LSTMAutoencoderDetector` (`models/lstm_autoencoder.py`) küszöbszámításán (a "Szent Grál" befejezése):

**A "Szórásmentes Organikus Szorzó" (Mean Multiplier) bevezetése:**
Ha a felhasználó az 1.0 - 2.0 közötti természetesen mozgó küszöböket (és változatos %-os találati rátákat) preferálja, el kell dobnunk a Szórást (STD) és az IQR-t is.

Mivel az átlag (Mean) a `tanh` hálózatban most rendkívül stabil (általában 0.8 - 1.2 között mozog), egy sima, lineáris **Szorzó a Tiszta Átlagon** tökéletes, organikus megoldást adna:

```python
# Csak az alsó 50% (vagy 90%) medián/átlag horgonya (szórás nélkül)
clean_mean = np.mean(mse[mse <= np.median(mse)])
# Vagy a teljes átlag:
# full_mean = np.mean(mse)

# Szimpla Organikus Szorzó (K)
self.threshold = clean_mean * K  # Pl. K = 2.5 vagy 3.0
```
Ezzel a módszerrel:
1. Ha egy 10 tickes szekvencia alapvetően zajosabb (nagyobb a hiba átlaga), a küszöb arányosan feljebb tolódik.
2. Ha az 500 tickes kisimult (kisebb a hiba átlaga), a küszöb organikus módon leszáll (pl. 1.2-re).
3. Mivel nincs benne szórás (STD), sosem "száll el" 4.0 fölé.
4. Mivel nem fix percentilis, a találati arány (Zaj) természetes módon fog ingadozni (pl. egyiknél 1.2%, másiknál 4.5%), **pontosan úgy, ahogy a felhasználó megálmodta a korábbi elemzések során!**

---
*(Záró gondolat: A Mátrix Profilozó és a Globális Horgony felépítése hatalmas architekturális siker. A session kemény, de eredményes volt!)*

**Készítette:** Jules (Szakértő MLOps / Szoftvermérnök Agent)