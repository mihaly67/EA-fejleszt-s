# SWAT4 (ML-Ops & Black Ops) RAG Rendszer

Ez a mappa tartalmazza a SWAT4 integrált RAG (Retrieval-Augmented Generation) rendszerét. A rendszer 4 fő szekciót fed le egyetlen közös, strukturált FAISS+SQLite adatbázisban:
1. **ML_Ops**: FinRL, EventStudy, LSTM anomália detektorok.
2. **Black_Ops**: HellsGate, DXCam, memóriainjektálók.
3. **Thief**: Lefordított API tolvajok.
4. **Colombo**: Debugger és monitorozó rendszerek.

A RAG rendszer segítségével vektorosan (jelentés alapján) kereshetsz az open-source repók kódjában és dokumentációjában, kizárva a bloatware-t (pl. lefordított `.exe`, `.dll` vagy `.pth` fájlokat).

---

## 1. Környezet Visszaállítása (Telepítés)

A rendszer és az ahhoz tartozó RAG adatbázis beállítása automatizált.
Futtasd a telepítő scriptet a mappa gyökeréből:

```bash
python3 restore_envSWAT4.py
```

**Mit csinál a script?**
- Feltelepíti a vektorizáláshoz szükséges Python könyvtárakat (`faiss-cpu`, `sentence-transformers`, `gdown` stb.).
- Letölti a becsomagolt RAG adatbázist a Google Drive-ról.
- Kicsomagolja a `Knowledge_Base/RAG_DB` mappába a `swat4_unified_compressed.index` és a `swat4_unified_knowledge.db` fájlokat.

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

**1. Szűrés Fő Kategóriára (`--category`):**
Ha csak a gépi tanulás érdekel, és nem akarod, hogy a C++ injektorok bekavarjanak:
```bash
python3 rag_interrogator.py --query "calculate CUSUM threshold" --category "ML_Ops"
python3 rag_interrogator.py --query "hook NtAllocateVirtualMemory" --category "Black_Ops"
```

**2. Szűrés Programnyelvre (`--lang`):**
Ha csak a C++ memóriakezelés vagy a Python ML kód érdekel:
```bash
python3 rag_interrogator.py --query "normalize raw tick data" --lang "Python"
python3 rag_interrogator.py --query "get process id" --lang "C++"
```

**3. Szűrés Repóra (`--repo`):**
Ha egy adott projekt belsejében keresel:
```bash
python3 rag_interrogator.py --query "capture screen" --repo "DXCam"
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
1. Futtasd a `structured_knowledge_builder.py` scriptet a letöltött forráskódok mellett (ez létrehoz egy `swat4_unified_data.jsonl` fájlt).
2. Futtasd a `build_rag_db.py` scriptet, ami beolvassa a `jsonl`-t és legenerálja az új SQLite DB-t és FAISS indexet a `Knowledge_Base/RAG_DB` alá.
