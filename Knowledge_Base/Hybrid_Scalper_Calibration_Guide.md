# Hybrid Scalper Calibration Guide (v4.1)

A **Hybrid Scalper Refined** indikátor helyes működéséhez elengedhetetlen a `SaturationPoints` paraméter megfelelő beállítása az adott instrumentum volatilitásához igazítva.

## Ajánlott Beállítások

| Instrumentum Típus | Példa Párok | Ajánlott `SaturationPoints` | Magyarázat |
| :--- | :--- | :--- | :--- |
| **Forex (Major)** | EURUSD, GBPUSD, USDCAD | **10** | A Forex párok mozgása kicsi (pipben mérve). 10 pont (1 pip) elmozdulás már erős jelnek számít 1 perces charton. |
| **Forex (JPY)** | USDJPY, GBPJPY | **10** | Hasonlóan a többi Forex párhoz, 10 pont (0.01 JPY) az irányadó. |
| **Indexek** | DAX (GERMANY40), SP500, US30 | **20** | Az indexek volatilisabbak, de a pontértékük nagyobb. A 20 pontos skála adja a legszebb görbét. |
| **Nyersanyag** | GOLD (XAUUSD) | **50** | Az arany volatilitása nagy. 50 pont (50 cent) elmozdulás kell a telítéshez. |
| **Kripto** | BTCUSD | **100** | A Bitcoin hatalmas pontértékű mozgásokat produkál. Legalább 100 dolláros elmozdulás kell a jelhez. |

## Mi történik, ha rossz az érték?

*   **Túl Kicsi Érték (pl. 1 Goldon):** A jel folyamatosan a plafonon (+1) vagy padlón (-1) lesz ("szögletes" görbe). Nem látod a finom mozgásokat.
*   **Túl Nagy Érték (pl. 100 EURUSD-n):** A jel "lapos" lesz, alig tér ki a 0-tól. A kereskedési szinteket (0.8) sosem éri el.

## Hogyan használd?
Az indikátor beállításainál keresd a **"CALIBRATION"** szekciót:
*   `InpSaturationPoints`: Írd be a fenti táblázatból a megfelelő értéket.
*   `InpTrendSaturation`: A Trend szűrő (M5) érzékenysége. Általában lehet nagyobb (pl. 50), hogy csak az erős trendeket mutassa.
