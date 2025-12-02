# Jövőbeli Fejlesztési Ütemterv (Roadmap)

## 1. Tudásbázis Bővítés (Előkészületben)
A jelenlegi RAG (MQL5 + Articles) rendszer mellé a következő speciális adatbázisok integrációját tervezzük:

### A. Data Science & Machine Learning
-   **Témák:** Adattudomány, Feature Engineering, Labeling, Neurális Hálók (NN).
-   **Cél:** A "Kereskedelmi Asszisztens" képessé tétele nemcsak a technikai elemzésre, hanem a modern AI-alapú piacvizsgálatra is.
-   **Implementáció:** Hasonlóan a `research_articles`-hez, külön mappába (`/tmp/ds_ml_knowledge`) kerülnek, és az `indexer.py` feldolgozza őket.

### B. GitHub Fejlesztői Tudásbázis
-   **Forrás:** Különálló GitHub repository-k (Open Source trading botok, keretrendszerek).
-   **Technológia:** A `kutato.py` felkészítése a `.py` (Python) és `.cpp` (C++) kódok mélyebb elemzésére is, nemcsak MQL5-re.

## 2. Architektúra Skálázása
-   Ahogy az adatbázis mérete nő, a "Szakaszos (Batch)" feldolgozás még fontosabbá válik.
-   Tervben van egy **"Prioritási Sor"** bevezetése az Inboxban, hogy a sürgős kutatások (pl. éles hiba elhárítás) megelőzzék az általános háttérkutatást.

## 3. Eredmények Vizualizációja
-   A szöveges jelentések (`.txt`) mellé HTML alapú, strukturált Dashboard generálása a kutatási eredményekből.
