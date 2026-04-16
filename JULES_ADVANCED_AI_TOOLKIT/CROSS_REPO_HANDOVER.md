# CROSS REPOSITORY HANDOVER: Advanced AI Toolkit (Jules -> Jules)

Üdv Jules! Ez a csomag kifejezetten a **Videorestauráló** és **Video Downloader** repository-id elemzéséhez, és a béta GUI/MCP szerver problémák elhárításához lett összeállítva az előző AI elemzése alapján.

## A Csomag Tartalma (Mit mire használj?)

1. **AI Memória, Kontextus és Antihallucináció** (`agent_memory_manager.py`)
   - Ez a script a hosszú távú JSONL memória alapja. Használd minden nagyobb blokk végén arra, hogy egy O(1) komplexitású kontextust írj (`--action write`). Mielőtt bármilyen új fejlesztésbe (pl. videorestauráló kód írásába) kezdenél, mindig olvasd ki a stratégiát (`--action read`). Ezzel elkerülöd, hogy a "context window" kimerülése miatt hallucinálj.

2. **MCP Szerver és Béta Limitációk Áthidalása** (`autonomous_tool_builder.py`)
   - Mivel a Puppeteer, Context7, Stitch, és a legtöbb MCP szerver sokszor nem működik vagy nem érhető el közvetlenül a UI felületen, itt találod az autonóm Tool Buildert.
   - **Mit csinál?** Ez generál neked a `skills/` mappába működőképes, lokális CLI hidakat (Python szkripteket). Így tudsz "chatelni" egy CSV/SQLite adatbázissal (OOM biztosan), diagramokat generálni a Matplotlibbel (memóriaszivárgás nélkül, amit te magad az `ls` vagy `view_image` parancsokkal ellenőrizhetsz), és webes lekérdezéseket futtatni.

3. **Repo Térkép, Tartalom és Scoutok** (`rag_scout.py`, `autonomous_rag_scout.py`)
   - A `KNOWLEDGE_MAPS` mappában mellékelem neked a *legutóbb elemzett RAG fájlokat* (`knowledge_map.txt` és `knowledge_signatures.txt`).
   - **Miért jó ez?** Ezekből meríthetsz tudást anélkül, hogy a DevBox memóriája összeomlana.
   - Ha a te jelenlegi (Videorestauráló) repo-dban is fel kell térképezni a fájlokat, használd a mellékelt Scout szkripteket! A `rag_scout.py` végigmegy a repository-n (vagy egy adott mappán), és kimenti az osztályokat, függvényeket a `signatures.txt`-be, míg a `map.txt`-be csak a struktúrát. Így nem kell a teljes fájlokat beolvasnod a Promptba, csak azokat, amikre épp szükséged van.

Jó munkát és sikeres OOM-biztos videofeldolgozást!

## 4. Kontextus és Dokumentáció Frissítés (Anti-Hallucináció)
A memória manager (`agent_memory_manager.py`) a *saját* belső állapotod fenntartására szolgál, de mi van a külső könyvtárak friss dokumentációjával?
- Az `autonomous_tool_builder.py` tartalmazza a `generate_context_updater_skill()` funkciót.
- Ez létrehoz neked egy `doc_updater.py` parancssori eszközt (Context7 API Wrapper).
- **Hogyan használd?** Mielőtt nekiállsz egy új vagy ismeretlen könyvtár (pl. videorestauráló FFmpeg pluginok) hívásainak, használd a scriptet: `python3 skills/doc_updater.py --library <könyvtár> --query <keresés>`. Ezzel azonnal friss kontextust hozhatsz a promptodba, elkerülve, hogy az elavult LLM tudásbázisod miatt hibás (hallucinált) kódot írj.
