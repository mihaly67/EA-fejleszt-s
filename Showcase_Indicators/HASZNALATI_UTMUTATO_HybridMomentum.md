# Használati Útmutató: Hybrid Momentum Indicator v1.10

Ez az indikátor nem egy egyszerű MACD. Egy **Hibrid Rendszer**, amely csak akkor ad jelet, ha a "Meggyőződés" (Conviction) elég magas. Ha a piac bizonytalan (zaj), az indikátor elrejti a hisztogramot.

## 1. A Kijelző Elemei

*   **Színes Oszlopok (Hisztogram):** Ez a fő kereskedési jel.
    *   Az oszlop magassága mutatja a **Lendületet (Momentum)** ÉS a **Meggyőződést (Conviction)**.
    *   Minél magasabb az oszlop, annál biztosabb a jel.
*   **Kék Vonal (MACD):** A trend iránya.
*   **Piros Pöttyös Vonal (Signal):** A jelzővonal.

---

## 2. Jelzések Értelmezése

### 🟢 Vételi Jel (LONG)
1.  **Megjelenés:** Az oszlopok **ZÖLD** színűek (a 0 vonal felett).
2.  **Belépő (Entry):**
    *   Amikor a hisztogram **átvált a negatív (piros) tartományból pozitívba**.
    *   VAGY: Amikor egy "üresjárat" (nincs oszlop) után **megjelenik az első Zöld oszlop**.
3.  **Erősség:** Figyeld a színárnyalatot!
    *   🍃 **Világos Zöld:** Gyenge kezdődő lendület.
    *   🌳 **Sötét Zöld (Élénk):** Erős, gyorsuló trend. **(Ideális tartás)**

### 🔴 Eladási Jel (SHORT)
1.  **Megjelenés:** Az oszlopok **PIROS** színűek (a 0 vonal alatt).
2.  **Belépő (Entry):**
    *   Amikor a hisztogram **átvált a pozitív (zöld) tartományból negatívba**.
    *   VAGY: "Üresjárat" után **megjelenik az első Piros oszlop**.
3.  **Erősség:**
    *   🌸 **Halvány Piros:** Gyenge kezdődő esés.
    *   🌹 **Sötét/Mély Piros:** Erős, zuhanó trend. **(Ideális tartás)**

### 🚫 "Lyukak" a Hisztogramban (A Csapda Szűrő)
Ha **nem látsz oszlopot** (vagy csak a vonalakat látod), az azt jelenti:
*   **ALACSONY MEGGYŐZŐDÉS (Low Conviction).**
*   A piac oldalaz, nincs elég volumen, vagy az ATR (volatilitás) túl alacsony.
*   **Teendő:** **NE KERESKEDJ!** Várd meg, amíg újra megjelenik egy határozott oszlop. Ez a funkció véd meg a "fűrész" (whipsaw) veszteségektől.

---

## 3. Hogyan szűr az indikátor? (Miért tűnik el?)
Az indikátor a háttérben 4 dolgot figyel. Ha ezek nem egyeznek, leveszi a jelet:
1.  **Volumen:** Van elég kereskedés? (Ha nincs, eltűnik).
2.  **ATR:** Van elég mozgás? (Ha lapos a piac, eltűnik).
3.  **WPR & Stoch:** Túl vett/adott zónában vagyunk? (Ez az indikátor a kitöréseket szereti, tehát a szélsőséges zónák **erősítik** a jelet, nem fordítják!).

## 4. Tesztelési Tippek (Holnapra)
*   **Trend:** Keress olyan szakaszt, ahol az oszlopok folyamatosan nőnek és sötétednek.
*   **Forduló:** Amikor a sötét szín elkezd "fakulni" (Sötétzöld -> Világoszöld), az a lendület fulladását jelzi. Ez lehet egy **Kilépési (Exit)** jel.
*   **Skálázás:** Ha minden oszlop eltűnik, próbáld csökkenteni a `InpConvictionThreshold` értéket (pl. 0.4-ről 0.2-re), hogy érzékenyebb legyen.
