# EA Fejlesztés & ML-Ops RAG Rendszer

Ez a mappa tartalmazza a EA Fejlesztés, FinRL és ML-Ops projektekhez tartozó FAISS + SQLite alapú RAG (Retrieval-Augmented Generation) rendszer telepítéséhez és lekérdezéséhez szükséges eszközöket.

A RAG rendszer segítségével vektorosan (jelentés alapján) kereshetsz a projektben található forráskódokban, dokumentációkban és konfigurációs fájlokban.

---

## 1. Környezet Visszaállítása (Telepítés)

A rendszer és az ahhoz tartozó RAG adatbázis beállítása automatizált.
Futtasd a telepítő scriptet a mappa gyökeréből:

```bash
python3 restore_env_ea.py
```

**Mit csinál a script?**
- Feltelepíti a vektorizáláshoz szükséges Python könyvtárakat (`faiss-cpu`, `sentence-transformers`, `gdown` stb.).
- Letölti a becsomagolt RAG adatbázist a Google Drive-ról.
- Kicsomagolja a `Knowledge_Base/RAG_DB` mappába a `ea_fejlesztes_compressed.index` és a `ea_fejlesztes_knowledge.db` fájlokat.

*(A RAG DB mappa automatikusan bekerül a `.gitignore` fájlba, így nem szemeteli tele a Git tárolót).*

---

## 2. RAG Keresés (Kihallgatási Protokoll)

A kódbázis logikájának feltérképezéséhez **KÖTELEZŐ** a `rag_interrogator.py` eszközt használni. Mivel ez a RAG adatbázis strukturált (külön metaadat oszlopokat tartalmaz), a keresést nagyon pontosan tudod szűrni nyelvre, kiterjesztésre vagy forrás repóra/mappára.

### Alapvető használat:
Nem a konkrét kódot, hanem a **koncepciót vagy problémát** kell angolul megfogalmazni.

```bash
python3 rag_interrogator.py --query "How to calculate dynamic CUSUM threshold in Python"
```

### 💡 Haladó Szűrések (Ajánlott)

**1. Szűrés Programnyelvre (`--lang`):**
Ha csak a Python backendben vagy a Javascript UI-ban keresel:
```bash
python3 rag_interrogator.py --query "normalize raw tick data" --lang "Python"
python3 rag_interrogator.py --query "execute order via MT5" --lang "MQL5"
```

**2. Szűrés Mappára/Repóra (`--repo`):**
Ha a keresést a letöltő motor egyik konkrét komponensére akarod szűkíteni:
```bash
python3 rag_interrogator.py --query "FinRL state estimation" --repo "ML_Ops"
```

**3. Szűrés Fájltípusra (`--type`):**
Kereshetsz csak a dokumentációkban (Markdown, txt) vagy a konfigurációkban (JSON, YAML) a kód (Code) helyett:
```bash
python3 rag_interrogator.py --query "default format selection" --type "Configuration"
python3 rag_interrogator.py --query "setup instructions" --type "Documentation"
```

**4. Szomszédság (Kontextus) betöltése (`--neighborhood`):**
Ha a kapott kódrészlet csonka (pl. lemaradt a függvény fejléce vagy egy fontos import), a `--neighborhood` bekapcsolásával megkapod a RAG adatbázisban szereplő előző és következő darabkát is.
```bash
python3 rag_interrogator.py --query "initialize GaussianHMM diag matrix" --neighborhood
```

---

## [Opcionális] Saját RAG adatbázis újraépítése

Ha a jövőben frissül a repó kódja, a következő módon generálhatod újra a helyi adatbázisod:
1. Futtasd a `structured_knowledge_builder.py` scriptet a letöltött forráskódok mellett (ez létrehoz egy `ea_fejlesztes_data.jsonl` fájlt).
2. Futtasd a `build_rag_db.py` scriptet, ami beolvassa a `jsonl`-t és legenerálja az új SQLite DB-t és FAISS indexet a `Knowledge_Base/RAG_DB` alá.
