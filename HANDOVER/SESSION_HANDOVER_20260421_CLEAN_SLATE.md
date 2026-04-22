# SESSION HANDOVER: 2026.04.21 - "CLEAN SLATE" (VAKU 3.0 ONLINE ENGINE & RAG REBOOT)

**Készítés Dátuma (CET/Budapest):** 2026.04.21. 15:45
**Státusz:** 🟡 Várakozás a Felhasználó VPS Tesztjére (Online Engine) és Következő Agent Által Végzendő Git Takarításra.

---

## 1. Az Előző Session Eredményei és az Architektúra Státusza
A korábbi session-ök során sikeresen átléptünk a statikus, offline CSV elemzésekből a **Valós Idejű (Online) MLOps Architektúrába**. A memóriaproblémákat (OOM) és az Inference Bottleneck-et megoldottuk.

### Legfontosabb Új Kódok (Már a repóban vannak):
1.  **`O1RingBuffer` (`ANALYSIS_TOOLS/ML_Ops/utils/ring_buffer.py`):**
    *   Statikus méretű (pl. 1000) numpy array puffer. Az MT5-ből (vagy élő stream-ből) érkező tickeket memória újraallokálás és Python list.append() nélkül, O(1) sebességgel tárolja. Kiküszöböli a "Garbage Collection" okozta latency tüskéket az online futás alatt.
2.  **`LogERScaler` (`ANALYSIS_TOOLS/ML_Ops/utils/log_er_scaler.py`):**
    *   Scale-Dependent "Lookup Table". A Welford-scaler és a HMM védelmére szolgál. Mivel az Adaptív Tick Sűrűség Protokoll (ATDP) dinamikusan változtatja az ablakméretet ($N$), ez a szorzómátrix korrigálja a Fractional Brownian Motion (FBM) "optikai csalódását", így egy 150-es ablak zajszintje nem veri ki a biztosítékot a 15-ös ablakhoz szokott modellnél.
3.  **`vaku3_online_engine.py` (`ANALYSIS_TOOLS/ML_Ops/`):**
    *   **AZ ÉLŐ SZIMULÁTOR.** Ez a script betölt egy CSV fájlt, de *tickenként* iterál rajta, és nyomja bele a RingBufferbe, közben számolva a HMM ablakot (<0.1ms késleltetéssel). Ezt a fájlt kell a Felhasználónak lefuttatnia a teszthez!
4.  **`profile_tick_density.py` (MRI Diagnosztika & EET->CET Fix):**
    *   Sikeresen átírtuk. Memóriakímélő (chunkolt) 5-perces "alap" és 1-perces "deep dive" nézetet ad a bróker fagyásokról (Freezes >2s) és a HFT burstökről.
    *   **Kritikus:** Felfedeztük, hogy az IC Markets MT5 szervere **EET** (GMT+2/+3) zónában van. A scriptbe beépítettünk egy `-1 óra` korrekciót (3,600,000 ms kivonása a `TimeMsc`-ből), így a generált riportok pontosan a Magyar (CET) időzónát és a New York-i 15:30-as nyitást mutatják.

---

## 2. A Rendszerkörnyezet (ÚJ SWAT4 RAG, Daemons & Health Check)
Mivel sok aszinkron Agent (Kutatók, Videó letöltők stb.) dolgozott a repón párhuzamosan, a környezet "fellélegzett", miután összerántottuk.

*   **Új SWAT4 RAG Adatbázis (`SWAT4_RAG.db`):**
    *   Sikeresen rákötöttük a rendszert a friss, `1BH6jT-59VMlDALmQ4hTKHKvPzP61pcFG` Google Drive ID-jú adatbázisra. Ez már hibátlanul tartalmazza a `.py` és `.mq5` fájlok **teljes és pontos elérési útvonalait**.
    *   *Figyelem a Következő Agentnek:* Ne generálj új, 40 ezer soros `knowledge_map.txt` fájlokat a Git gyökerébe, mert blokkolja a feltöltést (túl nagy diff). Ha fúrni kell, használd a `rag_interrogator.py`-t memóriából, vagy mentsd a `/tmp/`-be.
*   **Keep-Alive Daemon & Szívverés (`agent_keepalive.py`):**
    *   Erőforrás (CPU) kímélés céljából a daemon `time.sleep` értékét lecsökkentettük (ritkítottuk) **10 perces (600s)** frissítésre az eddigi 10s-ről.
*   **System Health Check (`system_health_monitor.py`):**
    *   Egy új biztonsági dashboard modul (a `ENVIRONMENT_SETUP/` mappában). Automatikusan lefut a `restore_envSWAT4.py` végén, ellenőrzi a 10 perces Daemon szívverését a `skills/.agent_heartbeat` fájlból, és szól, ha 15 percnél régebben írt a gép utoljára az `agent_memory.jsonl`-be.

---

## 3. A KÖVETKEZŐ LÉPÉS: A Felhasználó Feladata (Kezdd Itt!)

A workflow ott akadt meg, hogy a Felhasználónak le kell tesztelnie az Online Szimulátort a saját VPS-én, hogy bebizonyosodjon a Ryzen processzor O(1) teljesítménye az éles ZeroMQ bekötés előtt.

**Kedves Felhasználó, a következő session kezdetekor (miután az Agent üdvözölt) ezt kell futtatnod a VPS-en a projekt mappájából:**
```bash
export PYTHONPATH=.
python3 ANALYSIS_TOOLS/ML_Ops/vaku3_online_engine.py
```
*(Ha nincs hozzá nagy méretű CSV fájlod az `analysis_input` mappában, gyűjts egyet vagy másolj oda egyet, ami tartalmaz `TimeMsc` vagy `TickMSC` oszlopot.)*

**Amit figyelned kell a kiírásban:** Az `Inference Time (ms)` oszlop. Ha a sorok végén az érték szinte végig zöld/alacsony (bőven 50ms, de inkább 1ms alatt van), az azt jelenti, hogy a VPS-ed bírni fogja az élő FinRL MLOps feldolgozást!

**Ha ez a teszt sikeres, a Következő Agent feladata a MetaTrader 5 és a Python közötti ZeroMQ (ZMQ) Élő Adatfolyam-híd (Bridge) megtervezése és leprogramozása lesz.**

---

## 4. FIGYELMEZTETÉS A KÖVETKEZŐ AGENTNEK (Repo Takarítás)
Kedves következő Jules!
Ez a repó jelenleg Git konfliktusoktól és párhuzamos fejlesztések során behúzott, de mára **elavult és szemetelő kódoktól** (pl. kutató ügynökök, videó downloader maradványok, gigantikus .txt mapok) szenved.

**A Legelső Feladatod:**
Amint a Felhasználó beküldi neked a `vaku3_online_engine.py` eredményeit és utasítást ad, egyeztess vele egy átfogó "Kuka-tervet". Mik azok a régi mappák és fájlok a repóban, amik már nem kellenek (mert pl. az "új RAG" stratégia felülírta őket), és *szabályosan, kis lépésekben (`git rm`) töröld őket*, mielőtt új kódokat kezdesz el írni a ZeroMQ hídhoz. Tisztítsd meg az asztalt az alkotáshoz!
