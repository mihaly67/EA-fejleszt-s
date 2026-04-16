# CROSS REPOSITORY HANDOVER: Jules -> Jules

Üdv Jules! Ez a csomag az *EA/MLOps* és *SWAT4 RAG* optimalizációs folyamataink legfontosabb eszközeit (A Tool Factory-t és a RAG Search Engine-t) tartalmazza, átemelve a te Video Downloader / Video Restauráló környezetedbe.

A VPS limitációi ugyanazok maradnak (Ryzen 3 mag, 8GB RAM). Kérlek, olvasd el figyelmesen, és ezen alapján inicializáld a rendszert!

## 1. RAG Inicializáció
Az új repo-dban építened kell egy tudásbázist.
- **RAG Építés:** Futtasd a `swat4_rag/build_rag_db.py` és `swat4_rag/structured_knowledge_builder.py` eszközöket az új forráskód mappáidon. Mivel videókat dolgoztok fel, **fontos**, hogy kiterjesszétek a parser fájlkiterjesztéseket (pl. `.mp4`, `.xaml`, `.cs`, `.js` stb.). Lásd: `RAG_SETUP.md`.
- **RAG Lekérdezés:** OOM hiba elkerülésére a `rag_interrogator.py` scriptet használd SQLite LIMIT/OFFSET alapú lekérdezéssel, és soha ne próbálj minden RAG fájlt a kontextusodba (Prompt-ba) olvasni ("vacuum cleaner effect"). Csak a `knowledge_map.txt` és `knowledge_signatures.txt` magas szintű áttekintést olvasd!

## 2. A Hosszú Távú Memória Fenntartása
Mivel hosszú feladatokat fogsz megoldani, a kontextus ablakod hamar betelhet a videó-metainformációktól.
- Használd az `ENVIRONMENT_SETUP/agent_memory_manager.py` szkriptet!
- Futtasd minden 5. forduló után (vagy egy blokk végén):
  `python3 ENVIRONMENT_SETUP/agent_memory_manager.py --action write --category 'Context_Strategy' --content 'Tömörített összefoglaló arról amit eddig csináltam...'`
- Kezdéskor futtasd: `python3 ENVIRONMENT_SETUP/agent_memory_manager.py --action read` (O(1) memória visszaállítás).

## 3. UI és MCP Szerver Korlátok (A Skill Factory)
Lehetséges, hogy a videó/kép restauráló GUI interfészekhez nem tudsz csatlakozni (Puppeteer/Stitch hiánya béta módban).
- Futtasd az `ENVIRONMENT_SETUP/autonomous_tool_builder.py`-t. Ez létrehoz a `skills/` mappádban egy sor **CLI eszközt** (web_browser, stitch_ui_builder, self_healing_executor, data_analytics, correlation).
- Ezek az eszközök *Agent-to-Bot* felületek. Ha adatokat kell kielemezned (pl. Frame letöltési statisztikák, CSV logok a videókról), használd ezeket bash scripteken keresztül, mivel a bennük lévő `pandas chunksize` és SQLite LIMIT garantálja, hogy a VPS nem fagy le (OOM-Safe).

## Extra Jótanács
- A Matplotlib (ha ábrázolod a videó minőséget) könnyen Memory Leak-et okoz, ha nem takarítasz. Nézd meg a generált `chart_builder_ea.py` logikáját (`plt.clf()`, `plt.close()`), és csak így generálj új vizualizációs Python skilleket.
- Kerüld az `ProcessPoolExecutor`-t, ahol tudod. Szimpla szekvenciális adatfeldolgozást csinálj batch-elve.

Jó munkát és sok sikert a Video Restauráló repo-ban!
