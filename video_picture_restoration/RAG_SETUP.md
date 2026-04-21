# AI Picture & Video Restoration RAG Rendszer

Ez a mappa tartalmazza a gépi látáshoz, kép- és videó-helyreállításhoz kapcsolódó összes AI backend (pl. ESRGAN, GFPGAN) és Frontend GUI (pl. Waifu2x-Extension-GUI, SDNext) eszközének integrált RAG (Retrieval-Augmented Generation) rendszerét.

A RAG rendszer segítségével vektorosan (jelentés alapján) kereshetsz a 49+ különböző open-source repó kódjában és dokumentációjában.

---

## 1. Környezet Visszaállítása (Telepítés)

A rendszer és az ahhoz tartozó hatalmas adatbázis beállítása teljesen automatizált.
Lépj be a könyvtárba, majd futtasd a telepítő scriptet:

```bash
python3 restore_env_pv.py
```

**Mit csinál a script?**
- Feltelepíti a vektorizáláshoz szükséges Python könyvtárakat (`faiss-cpu`, `sentence-transformers`, `gdown` stb.).
- Letölti a becsomagolt RAG adatbázist a Google Drive-ról.
- Kicsomagolja a `Knowledge_Base/RAG_DB` mappába a `video_picture_restoration_compressed.index` és a `.db` fájlokat.

*(A RAG DB mappa és a nagy letöltött fájlok `.gitignore`-ban vannak, így véletlenül sem kerülnek be a verziókezelőbe).*

---

## 2. RAG Keresés (Kihallgatási Protokoll)

A kódbázis megértéséhez **KÖTELEZŐ** a `rag_interrogator.py` eszközt használni. Mivel ez a RAG adatbázis strukturált (külön metaadat oszlopokat tartalmaz), a keresést nagyon pontosan tudod szűrni nyelvre, kiterjesztésre vagy a származási repóra.

### Alapvető használat:
Nem a konkrét kódot, hanem a **koncepciót vagy problémát** kell angolul megfogalmazni.

```bash
python3 rag_interrogator.py --query "How to upscale an image using Real-ESRGAN"
```

### 💡 Haladó Szűrések (Ajánlott)

**1. Szűrés Programnyelvre (`--lang`):**
Ha csak a C++ motor érdekel, vagy csak a frontend (Vue/React):
```bash
python3 rag_interrogator.py --query "initialize video capture" --lang "C++"
python3 rag_interrogator.py --query "upload image to server" --lang "Vue"
```

**2. Szűrés Repóra (`--repo`):**
Ha egy adott projekt belsejében keresel (pl. VapourSynth pluginek):
```bash
python3 rag_interrogator.py --query "rife model inference" --repo "vs-rife"
```

**3. Szűrés Fájltípusra (`--type`):**
Kereshetsz csak a dokumentációkban (Markdown, txt) vagy csak a konfigurációkban (JSON, YAML):
```bash
python3 rag_interrogator.py --query "learning rate scheduler" --type "Configuration"
python3 rag_interrogator.py --query "setup instructions" --type "Documentation"
```

**4. Szomszédság (Kontextus) betöltése (`--neighborhood`):**
Ha a kapott kódrészlet csonka (pl. lemaradt az import rész), a `--neighborhood` bekapcsolásával megkapod a RAG DB előző és következő darabkáját is.
```bash
python3 rag_interrogator.py --query "load VRT model" --neighborhood
```

---

## [Opcionális] Saját RAG adatbázis újraépítése

Ha a jövőben frissülnek a repók, a következő módon generálhatod újra az adatbázist a saját gépeden:
1. Futtasd a `structured_knowledge_builder.py` scriptet a letöltött repók mellett (ez létrehoz egy `jsonl` fájlt).
2. Futtasd a `build_rag_db.py` scriptet, ami beolvassa a `jsonl`-t és legenerálja az új SQLite és FAISS index fájlokat.
