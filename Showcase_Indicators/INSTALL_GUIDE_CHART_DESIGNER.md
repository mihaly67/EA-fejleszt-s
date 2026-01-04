# Telepítési Útmutató: Chart Designer EA (GUI Panel)

Ez az eszköz egy grafikus felületet (panelt) biztosít a chart színeinek dinamikus, kattintás alapú beállításához és mentéséhez.

## Használat

1.  Nyisd meg a Metatrader 5 terminált.
2.  A Navigátor ablakban keresd meg az **Experts** (Szakértők) -> **Utilities** mappát.
3.  Húzd rá a chartra a **`Chart_Designer_EA`** nevű programot.
4.  Megjelenik egy panel a chart bal felső sarkában.

## Funkciók

*   **Kategóriák:**
    *   `Backgrnd` (Háttér): Szürke/Fekete árnyalatok betöltése a palettára.
    *   `Bullish` (Bika): Zöld árnyalatok.
    *   `Bearish` (Medve): Piros árnyalatok.
    *   `Grid Color` (Rács): Szürke árnyalatok.
*   **Paletta:** 10 db színes gomb. Kattints rájuk, és a chart azonnal frissül.
*   **Kapcsolók:**
    *   `Grid On/Off`: Rács ki/be kapcsolása.
    *   `OHLC On/Off`: Árfolyam adatok ki/be kapcsolása.
*   **Mentés:**
    *   `SAVE DEFAULT.TPL`: Ha elégedett vagy a beállítással, kattints erre. Ez elmenti az állapotot alapértelmezettként.

## Fontos
Ha végeztél a beállítással, távolítsd el az EA-t a chartról (jobb klikk -> Expert List -> Remove), különben a panel ott marad.
