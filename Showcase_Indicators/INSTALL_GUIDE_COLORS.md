# Telepítési Útmutató: Professzionális Színséma

A Metatrader 5 alapértelmezett színei ("Green on Black") gyakran zavaróak vagy nem esztétikusak. Az alábbi lépésekkel beállíthatod a kért "Professzionális" témát (Sötétszürke háttér, Erdőzöld/Téglavörös teli gyertyák), és elmentheted alapértelmezettként.

## Használat

1.  Nyisd meg a Metatrader 5 terminált.
2.  A Navigátor ablakban keresd meg a **Scripts** (Scriptek) mappát.
3.  Keresd meg a **`Configure_Chart_Template`** nevű scriptet.
4.  Húzd rá bármelyik nyitott chartra.
5.  A felugró ablakban ellenőrizheted a színeket (alapértelmezésben a kért értékek vannak beállítva).
6.  Kattints az **OK** gombra.

## Mi történik?

*   A script azonnal átállítja az aktuális chart színeit.
*   Automatikusan elmenti a beállításokat a **`default.tpl`** fájlba.
*   **Eredmény:** Mostantól minden *új* chart megnyitásakor ez a színséma fog betöltődni automatikusan.

## Színek
*   **Háttér:** `C'20,20,20'` (Nagyon sötét szürke)
*   **Bika (Emelkedő):** `clrForestGreen` (Erdőzöld) - Teli test
*   **Medve (Csökkenő):** `clrFireBrick` (Téglavörös) - Teli test
*   **Rács:** `clrDimGray` (Halvány szürke)
