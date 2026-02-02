# COLUMBO KÖNYVTÁR: VPS Építési Útmutató

Ez a dokumentum lépésről-lépésre leírja, hogyan kell felépíteni a **Colombo Tudáskapszulát** a VPS-en.

## 1. Előkészületek (Mappaszerkezet)

A VPS-en hozd létre a munkakönyvtárat (pl. `Github_colombo_repo`), és másold bele a letöltött repository mappákat ÉS a két python scriptet (`fetch_columbo_repos.py`, `builder_columbo_config.py`).

A végső szerkezetnek pontosan így kell kinéznie:

```text
Github_colombo_repo/
├── alibi-detect-master/
├── causalml-master/
├── chaosmonkey-master/
├── dowhy-main/
├── mlfinlab-master/
├── open_spiel-master/
├── perspective-master/
├── PettingZoo-master/
├── pyod-master/
├── quantstats-main/
├── swift-composable-architecture-main/
├── fetch_columbo_repos.py     <-- (Audit Script)
└── builder_columbo_config.py  <-- (Építő Script)
```

**Fontos:** A mappaneveknek **pontosan** egyezniük kell a fenti listával! Ha a ZIP-ből máshogy csomagoltad ki (pl. verziószám van a végén), nevezd át őket, vagy módosítsd a python scriptek elején a `REPO_DIRS` listát.

## 2. Környezet Beállítása (Python)

Győződj meg róla, hogy van telepítve Python 3. Nincs szükség extra külső könyvtárakra a scriptekhez (csak a beépített `os`, `json`, `zipfile` modulokat használják), így a `pip install` lépés most kihagyható, ha standard Python környezeted van.

## 3. Lépés: Auditálás (Opcionális, de ajánlott)

Először futtasd le az ellenőrző scriptet, hogy lásd, mindent megtalál-e a rendszer.

```bash
python3 fetch_columbo_repos.py
```

**Kimenet:** A képernyőre kiírja a talált fájlokat, és létrehoz egy `COLUMBO_REPO_AUDIT.txt` fájlt.
*Ellenőrizd:* Ha azt írja valamelyik mappára, hogy `❌ NOT FOUND`, akkor javítsd a mappanevet!

## 4. Lépés: A Tudáskapszula Építése (Build)

Ha az audit rendben volt, indítsd el a fő építőt:

```bash
python3 builder_columbo_config.py
```

Ez a folyamat pár percig tarthat (a fájlok számától függően).
A script:
1.  Végignézi az összes mappát.
2.  Kiszűri a tudást (.py, .md, .ipynb, stb.).
3.  Létrehozza a `knowledge_base_columbo.jsonl` fájlt.
4.  Automatikusan betömöríti: **`knowledge_base_columbo.zip`**.

## 5. Végső Lépés: Mentés (Rescue)

A létrejött **`knowledge_base_columbo.zip`** fájlt kell visszajuttatnod hozzám (vagy feltölteni a Google Drive-ra, ahonnan a `rescue_knowledge_vault.py`-hoz hasonló módszerrel majd letöltjük).

**Sok sikert, Rendszerfőnök!**
Jules
