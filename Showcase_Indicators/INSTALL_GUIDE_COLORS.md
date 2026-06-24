# Telepítési Útmutató: Professzionális Színséma és Finomhangolás

A Metatrader 5 alapértelmezett színei ("Green on Black") gyakran zavaróak vagy nem esztétikusak. Az alábbi lépésekkel beállíthatod a kért "Professzionális" témát (Sötétszürke háttér, Erdőzöld/Téglavörös teli gyertyák), finomhangolhatod a rácsot és az egyéb elemeket, majd elmentheted alapértelmezettként.

## Használat

1.  Nyisd meg a Metatrader 5 terminált.
2.  A Navigátor ablakban keresd meg a **Scripts** (Scriptek) mappát.
3.  Keresd meg a **`Configure_Chart_Template`** nevű scriptet.
4.  Húzd rá bármelyik nyitott chartra (vagy kattints rá jobb gombbal és válaszd a "Execute..." opciót).
5.  **Beállítások Ablak:** A felugró ablakban finomhangolhatod a paramétereket:
    *   **Színek:** Változtasd meg a hátteret, gyertyaszíneket ízlés szerint.
    *   **Láthatóság (Visibility):**
        *   `InpShowGrid`: Rács mutatása (True/False). Alapértelmezett: **False** (Kikapcsolva).
        *   `InpShowPeriodSep`: Napelválasztó vonalak.
        *   `InpShowAskLine` / `InpShowBidLine`: Árfolyamvonalak.
        *   `InpShowOHLC`: Bal felső sarokban az árfolyam adatok.
6.  Kattints az **OK** gombra.

## Mi történik?

*   A script azonnal átállítja az aktuális chartot a megadott beállításokra.
*   Automatikusan elmenti a beállításokat a **`default.tpl`** fájlba.
*   **Eredmény:** Mostantól minden *új* chart megnyitásakor pontosan ez a téma és beállítás fog betöltődni automatikusan.

## Alapértelmezett Színek (Módosítható)
*   **Háttér:** `C'20,20,20'` (Nagyon sötét szürke)
*   **Bika (Emelkedő):** `clrForestGreen` (Erdőzöld) - Teli test
*   **Medve (Csökkenő):** `clrFireBrick` (Téglavörös) - Teli test
*   **Rács:** `clrDimGray` (Halvány szürke) - Alapból kikapcsolva
