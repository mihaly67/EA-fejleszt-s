# SWAT RAG Kihallgatási Protokoll (Jules Számára)

Mivel a MiniLM modell egy általános nyelvi modell (elsősorban a szemantikát, kommenteket, és architekturális elképzeléseket érti, nem a nyers kódot), az alábbi 3 szigorú szabályt KELL alkalmazni a SWAT_DB keresésekor az SQLite és vektor-kereső szkriptek (pl. `swat_rag_query.py`) használata során:

## 1. A "Hibrid Szűrő" Taktika (Metadata + Vektor)
A SWAT_DB alapja SQLite. Soha ne bízz mindent csak a vektoros (szemantikai) keresésre. Először MINDIG szűrj metaadatokra (pl. fájl kiterjesztés, repo név) SQL-ben, és csak az így kapott, erősen releváns halmazon (pl. csak a `.c` fájlokban) futtasd a vektoros hasonlóságkeresést (`vector_distance`).
Példa Helyes Működésre:
`SELECT file_path, code_chunk FROM swat2_db WHERE repo_name = 'BOAZ' AND file_extension = '.c' ORDER BY vector_distance(embedding, query_vector) LIMIT 5;`

## 2. Keresés Funkcióra, ne Szintaxisra (Prompt Engineering)
A MiniLM fogalmakat ért. Amikor a kereső promptot (query) összeállítod a vektorizáláshoz, SOHA NE nyers kódsorokat vagy pontos függvényneveket írj be (pl. `bpf_probe_read_user(&data.payload, copy_size, buff)`).
Helyette írd le a funkciót/célt emberi nyelven:
Példa Helyes Keresésre: *"How to safely read network payload buffer from user space memory to kernel space using eBPF without triggering verifier bounds checking error"*
Ezzel a MiniLM a szöveges leírás (vagy repó dokumentációk/kommentek) alapján hajszálpontosan meg fogja találni a kódrészletet.

## 3. A "Szomszédság" (Context Window) Lekérdezése
A JSONL/SQLite adatbázisban a kód darabokra van vágva. Ha egy vektoros keresés megtalálja a tökéletes függvényt, de a fájl elejéről hiányzik az include vagy egy változódeklaráció, alkalmazd a "Szomszédság" lekérdezését.
Mivel SQLite-ban vagyunk, a ROWID vagy az egyedi azonosítók/metaadatok (pl. chunk_index) alapján SQL-ből lekérheted a fájl előző (n-1) és következő (n+1) darabját is a sorrendből, hogy összeálljon a teljes, működő kontextus.
