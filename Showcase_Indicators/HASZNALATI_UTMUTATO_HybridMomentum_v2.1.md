# Használati Útmutató - Hybrid Momentum Indicator v2.1

**Verzió:** 2.1 (Nonlinear Kalman Filter)
**Dátum:** 2024.
**Típus:** Momentum Oszcillátor (Lag-Free Hybrid)

## 📌 Áttekintés
A `HybridMomentumIndicator v2.1` a projekt legfejlettebb indikátora, amely a **Lag vs. Noise (Késés vs. Zaj)** dilemmát egy tudományos megközelítéssel oldja meg.
A v2.0 (VWMA) stabil volt, de késleltetett. A v2.1 ezt a késést a **Nonlinear Kalman Filter** (Nem-lineáris Kálmán-szűrő) technológiával küszöböli ki, amely képes "előrejelezni" a trendet a zajszűrés közben.

## ⚙️ Technológia: A "Hibrid Motor"
Az indikátor két lépcsőben dolgozik:
1.  **Zajszűrés (Input Stage):** A bemeneti árfolyamot először egy rövid periódusú **VWMA (Volume Weighted MA)** szűri. Ez eltávolítja a "fantom" ármozgásokat (amelyek mögött nincs forgalom), de magában még késést okozna.
2.  **Lag Kompenzáció (Kalman Stage):** A tisztított jelet a Kálmán-szűrő dolgozza fel, amely két komponenst számol:
    *   **Lowpass:** A simított trend (mint egy EMA).
    *   **Delta:** A trend változási sebessége (a "késés" mértéke).
    *   **Eredmény:** A kettő összege (`Lowpass + Delta`) visszaállítja a jelet a valós időbe, megszüntetve az EMA késését.

## 📊 Eredmény
*   **Gyorsaság:** Olyan gyors, mint a Hull MA (HMA) vagy a DEMA.
*   **Tisztaság:** Olyan stabil, mint a VWMA (a forgalmi szűrés miatt).
*   **Scalper Beállítás:** Kifejezetten az 5-13-6 (gyors) beállításra optimalizálva.

## 🖥️ Paraméterek
*   **InpFastPeriod (5):** Gyors Kalman periódus.
*   **InpSlowPeriod (13):** Lassú Kalman periódus.
*   **InpSignalPeriod (6):** Jelzővonal.
*   **InpKalmanGain (1.0):** A késés-kompenzáció erőssége. (1.0 = Teljes kompenzáció).
*   **InpUseVolumeFilter (true):** Előszűrés és Szellem Sávok (Ghost Bars) használata.

## ⚠️ Megjegyzés
Ez az algoritmus rekurzív (az előző értékből számol), ezért a chart betöltésekor igényelhet pár másodpercet a "bemelegedéshez" (stabilizálódáshoz).
