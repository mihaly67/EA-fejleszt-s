# Cross-Repo Handover: AI RAG & Long-Term Memory Architecture

Ez a dokumentum a 2026-os RAG kutatási és környezetépítési fázis (Epic Session) részletes technikai összefoglalója.
**Cél:** Ha ezt a fájlt beemeled egy másik repóba (pl. SWAT4, MT5 EA projektek, stb.), az ott dolgozó AI ágensek azonnal képesek lesznek megérteni a kiépített infrastruktúrát és alkalmazni a "Fractal-Memory" alapú RAG feldolgozást OOM (Out Of Memory) hiba nélkül.

## 1. Az Alapprobléma: Memória Kimerülés (OOM) 8GB VPS-en
A masszív RAG adatbázisok (pl. "Ultimate RAG" 10,000+ fájllal) SQLite feldolgozása során a `cursor.fetchall()` és az LLM teljes adatbetöltése (Vacuum Cleaner Effect) kifagyasztotta az ágenseket és a szervert.
A megoldás a **Fractal-Memory Meta-RAG architektúra**.

## 2. Megoldás: Fractal-Memory (LIMIT/OFFSET) és RAG Scout
- Létrehoztunk egy eszközt (`ENVIRONMENT_SETUP/rag_scout.py` és `autonomous_rag_scout.py`), amely **NEM tölti be a fájlok tartalmát** a memóriába.
- Kizárólag a könyvtárstruktúrát és a függvény/osztály szignatúrákat (Regex-szel) nyeri ki.
- **SQL Batching:** A `fetchall()` helyett szigorú `LIMIT 500 OFFSET X` logikát és `ORDER BY rowid` determinisztikus sorrendet használtunk.
- Eredmény: A teljes RAG adatbázis feltérképezhető 50MB RAM alatt, és generál egy `repo_lista.txt` és `knowledge_signatures.txt` "térképet", amiből az LLM célzott lekérdezéseket indíthat (`rag_interrogator.py`).

## 3. Long-Term Agent Memory (JSONL Archival Memory)
- **Szemantikus Kontextus Kezelés (Új):** Ha egy ágens elveszti a fonalat egy régi döntéssel kapcsolatban, a találgatás helyett kötelező futtatnia a `python3 ENVIRONMENT_SETUP/skills/semantic_memory_search.py --keyword "Téma"` parancsot. Ez Regex keresést végez a JSONL fájlban.
- Az ágensek kontextusablaka (Context Window) korlátozott. Hogy elkerüljük a "felejtést" és a hallucinációt, létrehoztuk az `agent_memory_manager.py`-t.
- **Működése:** Nem használ nehézkes keretrendszereket (Mem0, Letta, MemOS), hanem egy egyszerű `Knowledge_Base/agent_memory.jsonl` fájlba appendál.
- **Agent Behavior Protocol (Szabály):** Minden ágensnek **Tilos** új tervet (set_plan) készítenie, amíg le nem futtatta a memóriát beolvasó parancsot:
  `python3 ENVIRONMENT_SETUP/agent_memory_manager.py --action read --limit 5`
- A memóriamenedzser tartalmaz egy token-számlálót is. Ha a lekérdezett memória átlépi a 8000 tokent, az ágensnek kötelező "Condense" (Sűrítés) akciót végrehajtania.

## 4. Dinamikus Eszközkészítés (Autonomous Tool Builder)
- A RAG tudásbázisok (pl. felhős AI repók) önmagukban csak szövegek. Létrehoztuk az `autonomous_tool_builder.py`-t, aminek az a célja, hogy a kinyert "tudásból" futtatható lokális scripteket (Python skills) készítsen az ágens számára a `ENVIRONMENT_SETUP/skills/` mappába.
- **Példák (Mikre képes ez a struktúra):**
  - Célzott, webalapú API doksi letöltése (Playwright / Context7).
  - CSV adatelemző logikák átemelése más MLOps repókból és futtatása.
  - Önreflexiós és hibakereső hurok (`self_reflection.py`).

## 5. Teendők az Új Repóban az Ágens Számára (Neked, ha olvasod)
1. Futtasd az ottani env setup fájlt, és ellenőrizd az `agent_memory.jsonl` állapotát.
2. Ha hatalmas RAG adatbázist kell feldolgoznod, **soha ne próbáld meg egyben**. Használd a `rag_scout.py` mintájára a chunking és LIMIT/OFFSET módszert.
3. Minden nagyobb logikai szakasz végén használj `--action write` akciót a `agent_memory_manager.py`-vel, hogy a tudásod átmenjen a következő sessionre!

## 6. Plusz Képességek (Anti-Timeout és Anti-Hallucination)
A legújabb importált scriptek (`ENVIRONMENT_SETUP/skills/` mappában) további védelmet nyújtanak:
- **`agent_keepalive.py`**: Hosszú (több órás) RAG generálásoknál futtasd a háttérben, hogy a DevBox/Sandbox network ne dobjon timeoutot (`nohup python3 agent_keepalive.py &`).
- **`semantic_memory_search.py`**: Ha elvesztetted a kontextust egy régi funkcióról (pl. "Mi volt a döntés 3 héttel ezelőtt az MQL5 fájloknál?"), ez a script képes Regex kulcsszavas keresést végezni a JSONL memóriádban!
- **`self_healing_executor.py`**: Ha autonóm módon kell scripteket futtatnod és debugolnod (Self-Reflection), ezzel a futtatóval kapd el a hibákat az LLM számára, ahelyett hogy közvetlenül Bash-ből omlana össze a kód.
