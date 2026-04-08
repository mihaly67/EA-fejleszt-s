# Video Downloader RAG Rendszer

Ez a könyvtár tartalmazza a Video Downloader projekthez tartozó FAISS + SQLite RAG (Retrieval-Augmented Generation) adatbázis telepítéséhez és lekérdezéséhez szükséges eszközöket. Ez a megközelítés a SWAT RAG rendszer adaptációja.

## Telepítés és Környezet Visszaállítása

Minden környezet telepítése automatikusan történik a `restore_env_vd.py` script segítségével. A script gondoskodik a szükséges Python függőségek telepítéséről, majd letölti és kicsomagolja a RAG adatbázist a Google Drive-ról.

### Függőségek (A script automatikusan telepíti őket)
- `gdown`
- `faiss-cpu`
- `sentence-transformers`
- `numpy`
- `pandas`
- `colorama`

### Végrehajtás
Futtasd a következő parancsot a projekt gyökeréből (vagy ebből a mappából, ha átmásoltad):

```bash
python3 restore_env_vd.py
```

**Eredmény:**
A script létrehoz egy `Knowledge_Base/RAG_DB` mappát, ahová kicsomagolja a `video_downloader_github_compressed.index` és a `video_downloader_github.db` fájlokat.
*(Megjegyzés: A RAG adatbázis mappája automatikusan a `.gitignore` fájlhoz adódik, így nem kerül a Git tárolóba.)*

---

## RAG Keresés (Kihallgatási Protokoll)

A kódbázis megértéséhez és specifikus funkciók kereséséhez **kötelező** a `rag_interrogator.py` parancssori eszközt használni. Mivel ez vektoros keresést (szemantikai keresést) használ, nem a pontos kódszintaxist kell megadni, hanem a keresett funkció vagy probléma leírását (lehetőleg angolul).

### Használati Példák

**1. Alap keresés (top 5 találat):**
```bash
python3 rag_interrogator.py --query "How to download video using aria2c"
```

**2. Keresés forrás szerinti szűréssel (Hibrid Szűrő Taktika):**
A `--source` paraméterrel szűrhetsz adott fájltípusokra vagy fájlnevekre, hogy csökkentsd a hamis pozitív találatok számát.
```bash
python3 rag_interrogator.py --query "download initialization" --source ".py" --limit 10
```

**3. Szomszédság lekérdezése (Teljes Kontextus):**
Ha a kapott kódrészlet nem tartalmazza például a szükséges `import` nyilatkozatokat vagy a kontextust, a `--neighborhood` jelzővel a script visszaadja a RAG adatbázis előző és következő blokkját is.
```bash
python3 rag_interrogator.py --query "config loader class" --neighborhood
```

## További Információk

A jelenlegi index és adatbázis nevei amikre a rendszer támaszkodik:
- Index fájl: `video_downloader_github_compressed.index`
- Adatbázis fájl: `video_downloader_github.db`

Ezek a `Knowledge_Base/RAG_DB/` mappában lesznek elhelyezve a telepítés után.
