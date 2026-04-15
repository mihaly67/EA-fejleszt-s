# KUTATÁSI JELENTÉS: Új RAG környezet és Data Chatbotok
**Dátum:** 2026-04-15
**Készítette:** Jules (Agent)
**Forrás:** Új felhasználói repository gyűjtemény (`RAG_CHATBOT_CSV_DATA_LLM_github.db`)

## 1. Vezetői Összefoglaló
A kiadott kutatási feladatnak megfelelően letöltöttem és kielemeztem a megadott új kódbázist (11,742 fájl a kibontott SQLite adatbázisban). A Handover és az Agent.md szabályait (különös tekintettel a memóriakorlátokra és a KISS elvre), valamint a legutóbbi Felhasználói instrukciókat figyelembe véve vizsgáltam meg az eszközöket. Fókuszomban az **MT5 EA fejlesztés, CSV adatelemzés, statisztikai számítások és adatvizualizáció** állt.

Az LLM modellek és RAG-ek intenzív lokális futtatását a 8GB VPS-en kerülni kell, azonban több olyan pehelysúlyú, zseniális mérnöki megoldást ("kincset") találtam, amely forradalmasíthatja a meglévő analitikai és pipeline építő folyamatainkat!

---

## 2. Feltárt Kincsek és Integrációs Javaslatok

### 💎 KINCS 1: `sqlite-vec` (A FAISS Gyilkosa)
**Forrás repo:** `sqlite-vec-main`
*   **Mi ez?** Egy extrém kicsi, C-ben írt SQLite kiterjesztés vektor kereséshez. Nincs külső függősége, és bárhol fut, ahol az SQLite (még WASM-ben is!). Képes float, int8 és bináris vektorokat tárolni virtuális `vec0` táblákban.
*   **Miért zseniális nekünk?** Jelenleg a RAG adatbázisunk (`SWAT_DB`) külön FAISS indexet és külön SQLite meta-adatbázist használ. A FAISS RAM-igényes, különösen a betöltéskor. A `sqlite-vec`-kel egyetlen `.db` fájlban tudnánk tartani a vektorokat és a szöveget/metaadatot, brutális memóriamegtakarítást és egyszerűsítést elérve a Ryzen 3 VPS-en.
*   **Javasolt akció:** A jövőben érdemes tenni egy próbát a `build_rag_db.py` és a `rag_interrogator.py` átírásával, hogy kizárólag `sqlite-vec`-et használjanak.

### 💎 KINCS 2: `fastembed` (A PyTorch Kiváltója)
**Forrás repo:** `fastembed-main`
*   **Mi ez?** Egy pehelysúlyú, hihetetlenül gyors Python beágyazó (embedding) könyvtár, amely ONNX Runtime-ot használ PyTorch helyett. Nem igényel GPU-t és gigabájtos függőségek letöltését.
*   **Miért zseniális nekünk?** A RAG építő scriptek jelenleg a `sentence-transformers`-t töltik be, ami magával rántja a PyTorch-ot és az Intel MKL-t, gyakran a memóriakorlát (OOM) határán egyensúlyozva a 8GB RAM-on. A `fastembed` drasztikusan csökkentené a memórialábnyomot az embeddings generálásakor.
*   **Javasolt akció:** A következő RAG-frissítéskor a `sentence-transformers`-t cseréljük le `fastembed`-re a vektorizáló scriptekben.

### 💎 KINCS 3: PandasAI és Streamlit CSV Agensek (Vizualizációs trükkök)
**Forrás repók:** `pandas-ai-main`, `ChatBot-CSV-main`, `AI-Datanalysis-main`
*   **Mi ez?** Kódok, amelyek LangChain és OpenAI/Ollama (LLM) segítségével Python kódot (Pandas) generálnak és futtatnak dinamikusan CSV fájlokon, majd Streamlit-ben vizualizálják (pl. Plotly segítségével).
*   **Miért zseniális nekünk?** Bár a lokális LLM (Ollama) futtatása a mi VPS-ünkön tilos a szűkös erőforrások miatt, az itt használt **vizualizációs és DataFrame feldolgozási architektúrát** ("Agent.py" szerkezete, biztonságos kód-végrehajtás whitelist-el) egy-az-egyben újrahasznosíthatjuk a meglévő MT5 Heatmap (`visualize_behavior.py`) scripteink interaktív Streamlit Dashboard-dá alakításához! A felhasználó feltöltheti a MT5 CSV-t, és a script (LLM nélkül, de az ő Streamlit trükkjeiket használva) azonnal rendereli a statisztikákat.

### 🔴 AMIT EL KELL VETNÜNK (A "Devil's Advocate" Szűrő)
1.  **Lokális Ollama Agentek (pl. `awesome-llm-apps-main/rag_tutorials/local_rag_agent/local_rag_agent.py`):** Ezek a scriptek Qdrant vagy LanceDB mellett próbálják futtatni a 3.2B paraméteres (Llama3.2) modelleket. A mi 3-magos 8GB-os VPS-ünk azonnal összeomlana tőle (OOM hiba). Szigorúan tartjuk magunkat ahhoz, hogy a VPS-en csak könnyű statisztika, HMM elemzés és MLOps preprocessing fusson.
2.  **Komplex RAG keretrendszerek (LlamaIndex):** Túl sok abstrakció. Maradunk az egyedi `rag_interrogator.py` megoldásunknál (Kaszkád és Fúrás), amely testre van szabva az MT5 EA kódbázis megértésére.

---

## 3. Következő Lépések Javaslata a Felhasználónak
1.  **Azonnali nyereség:** Javaslom, hogy teszteljük a `fastembed`-et a VPS-en. Ha sikeresen generálja a vektorokat PyTorch nélkül, drasztikusan biztonságosabbá válik a RAG frissítési folyamatunk!
2.  **Középtávú cél:** Az MT5 elemző (Heatmap) scripteket elkezdhetjük átalakítani Streamlit alapú interaktív UI-ra, felhasználva a talált CSV Chatbotok frontend logikáit.

**Készen állok a további specifikus EA vagy statisztikai fejlesztési feladatokra!**