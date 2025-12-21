# Használati Útmutató - Hybrid Momentum Indicator v2.3

**Verzió:** 2.3 (Phase Advance - Speed Tuned)
**Dátum:** 2024.
**Típus:** Momentum Oszcillátor (Scalping Optimized)

## 📌 Áttekintés
A `HybridMomentumIndicator v2.3` a v2.2 továbbfejlesztett változata, amely kifejezetten a **sebességet (Speed)** célozza meg a stabilitás feláldozása nélkül.
Az újítás a **Phase Advance (Fázis Siettetés)** technológia bevezetése a Nonlinear Kalman szűrőbe.

## ⚙️ Újdonság: Phase Advance
A hagyományos szűrők "várnak" a trend megerősítésére. A v2.3 a trend *sebességét* (Delta) használja fel arra, hogy a szűrő kimenetét "előretolja" az időben.
*   **Képlet:** `Kimenet = Trend + (Változás * PhaseAdvance)`
*   **Hatás:** Ha az árfolyam hirtelen megindul, az indikátor azonnal reagál, még mielőtt a mozgóátlag utolérné az árat.

## 🖥️ Paraméterek
*   **InpPhaseAdvance (0.5):** A siettetés mértéke.
    *   `0.0`: Normál v2.2 működés (nincs siettetés).
    *   `0.5`: Mérsékelt siettetés (ajánlott).
    *   `1.0`+: Agresszív siettetés (gyorsabb, de zajosabb lehet).
*   **InpSignalPeriod (6):** A jelzővonal továbbra is Lowpass (stabil), hogy a gyors MACD vonal "tisztán" metssze át.

## 📊 Stratégia (M2 Scalping)
*   **Vétel:** Kék vonal (Gyors) alulról metszi a Piros vonalat (Lassú), ÉS a hisztogram Zöldre vált.
*   **Eladás:** Kék vonal felülről metszi a Pirosat, ÉS a hisztogram Pirosra vált.
*   **Szürke Hisztogram:** Gyenge forgalom (Ghost Bar) - Óvatosan a belépéssel!
