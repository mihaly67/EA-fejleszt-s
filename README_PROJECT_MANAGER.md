# Jules Projekt Menedzser Rendszer (Factory Mode)

Ez a rendszer egy autonóm "gyárként" működik, ahol a **Műszakvezető** (`project_manager.py`) folyamatosan figyeli a beérkező feladatokat és kiosztja őket a **Munkásoknak** (`kutato.py`).

## Hierarchia
1.  **Főmérnök (Te):** Meghatározod a célokat és feladatfájlokat helyezel az `Inbox`-ba.
2.  **Műszakvezető:** Folyamatosan fut, feldolgozza az `Inbox`-ot, és jelentést tesz a `Reports`-ba.
3.  **Munkás:** A RAG tudásbázis (`rag_code`, `rag_theory`) segítségével végrehajtja a kutatást.

## Könyvtárszerkezet

-   `tasks_inbox/`: **Bemenet.** Ide helyezd a JSON feladatfájlokat.
-   `tasks_archive/`: **Archívum.** A Műszakvezető ide mozgatja a feldolgozott fájlokat.
-   `project_reports/`: **Kimenet.** Itt keletkeznek a részletes jelentések (.txt).

## Használat

### 1. A Gyár Indítása (Műszakvezető szolgálatba helyezése)
A rendszer háttérfolyamatként (daemon) fut:

```bash
python project_manager.py &
```
*(Javasolt a kimenetet logfájlba irányítani debug célból: `python project_manager.py > manager.log 2>&1 &`)*

### 2. Feladat Kiadása
Hozz létre egy JSON fájlt a `tasks_inbox/` mappában (pl. `tasks_inbox/uj_kutatas.json`):

```json
{
  "project_name": "Piackutatas_MACD",
  "tasks": [
    {
      "id": 1,
      "type": "research",
      "description": "MACD stratégiák keresése",
      "query": "MACD strategy",
      "scope": "ELMELET",
      "depth": 0
    }
  ]
}
```

### 3. Eredmény
A Műszakvezető észleli a fájlt, feldolgozza, és a `project_reports/` mappába menti az eredményt (pl. `Piackutatas_MACD_2023...txt`). A bemeneti fájl átkerül a `tasks_archive/`-ba.

### 4. Leállítás
A műszak befejezéséhez hozz létre egy `STOP_MANAGER` nevű fájlt a gyökérkönyvtárban.
```bash
touch STOP_MANAGER
```
A Műszakvezető a következő ciklusban észleli és leáll.

## Rendszerkövetelmények
-   A `rag_code` és `rag_theory` mappáknak (vagy `/tmp` megfelelőinek) tartalmazniuk kell az indexelt tudásbázist.
