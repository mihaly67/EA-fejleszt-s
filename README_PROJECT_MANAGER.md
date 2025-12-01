# Jules Projekt Menedzser Rendszer (Factory Mode + Watchdog)

Ez a rendszer egy autonóm "gyárként" működik, hibatűrő (self-healing) mechanizmusokkal.

## Komponensek
1.  **Műszakvezető (`project_manager.py`):** A központi daemon. Figyeli az Inboxot, szervezi a munkát, kezeli a "Resume" (folytatás) logikát.
2.  **Munkás (`kutato.py`):** Optimalizált RAG keresőmotor.
3.  **Indító (`start_factory.py`):** Gondoskodik az adatok letöltéséről (/tmp) és a Menedzser helyes indításáról.
4.  **Őrszem (`watchdog.py`):** Folyamatosan (percenként) ellenőrzi, hogy fut-e a Menedzser. Ha leállt, újraindítja.

## Használat (Production)

### 1. A Rendszer Indítása (Őrszemmel)
Ezzel az egy paranccsal indítsd el a teljes rendszert:

```bash
python watchdog.py &
```

Ez a szkript:
1.  Ellenőrzi/Letölti a RAG adatbázist.
2.  Elindítja a Műszakvezetőt.
3.  A háttérben marad és őrködik.

### 2. Ellenőrzés
-   **Logok:** `factory.log` (Menedzser kimenete), `watchdog.log`.
-   **Folyamat:** `ps aux | grep project_manager`

### 3. Feladat Kiadása
Ahogy eddig, JSON fájlok a `tasks_inbox/` mappába.

### 4. Leállítás
```bash
touch STOP_MANAGER
```
(Ez leállítja a Menedzsert. Az Őrszem látni fogja, hogy leállt, DE ha a STOP fájl ott van, a Menedzser újraindulás után azonnal kilép, így nem pörög feleslegesen. A teljes leállításhoz érdemes az Őrszemet is leállítani: `pkill -f watchdog.py`.)

## Hibatűrés
-   **Újraindulás:** Ha a Menedzser összeomlik, az Őrszem 60 másodpercen belül újraindítja.
-   **Folytatás (Resume):** A Menedzser `.progress` fájlokban követi a részfeladatok állapotát. Újrainduláskor onnan folytatja, ahol abbahagyta (nem kezdi elölről a kész feladatokat).
