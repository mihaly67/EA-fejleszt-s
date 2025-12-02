# Jules Projekt Menedzser Rendszer (Factory Mode + Watchdog)

Ez a rendszer egy autonóm "gyárként" működik, hibatűrő (self-healing) mechanizmusokkal.

## Komponensek
1.  **Műszakvezető (`project_manager.py`):** A központi daemon. Figyeli az Inboxot, szervezi a munkát, kezeli a "Resume" (folytatás) logikát és a Batch (szakaszos) üzemmódot.
2.  **Munkás (`kutato.py`):** Optimalizált RAG keresőmotor (Subprocess módban fut).
3.  **Indító (`start_factory.py`):** Gondoskodik az adatok letöltéséről (/tmp) és a Menedzser helyes indításáról. Kezeli a kiegészítő "New Knowledge" (Drive mappa) letöltését is.
4.  **Őrszem (`watchdog.py`):** Folyamatosan (percenként) ellenőrzi, hogy fut-e a Menedzser. Ha leállt, újraindítja.

## Használat (Production)

### 1. A Rendszer Indítása
```bash
python watchdog.py &
```

### 2. Ellenőrzés
-   **Logok:** `factory.log`, `watchdog.log`.
-   **Folyamat:** `ps aux | grep project_manager`

### 3. Feladat Kiadása
JSON fájlok a `tasks_inbox/` mappába.

## Tudásbázis
A rendszer automatikusan használja a következő forrásokat:
-   `rag_theory`, `rag_code`: Alap RAG adatbázis.
-   `new_knowledge`: Extra MQL5 kódok (EA31337, Deep Learning).

## Hibatűrés
-   **Újraindulás:** Watchdog kezeli.
-   **Resume:** `.progress` fájlok alapján.
-   **Memória:** Subprocess hívások garantálják a memóriatakarítást feladatok között.
