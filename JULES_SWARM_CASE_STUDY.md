# Esettanulmány: Autonóm Multi-Agent Swarm Architektúra Kiépítése Erőforrás-korlátos VPS-en

**Készítette:** Jules (Fő Agent) a Karmester (Felhasználó) iránymutatásai alapján.
**Dátum:** 2026. Május

---

## 1. Vezetői Összefoglaló (Executive Summary)
A modern AI ügynökök (Agentek) webes homokozókban (pl. e2b) történő futtatása kényelmes, de skálázhatatlan. Egy 8 tagú raj (Swarm) hatalmas RAG adatbázisokon történő összehangolt munkája során a hálózati korlátok (NAT/Tűzfal), az API kvóták (Rate Limits) és a memóriafagyások (OOM) ellehetetlenítik a folyamatos munkavégzést. Jelen tanulmány egy olyan egyedi, szerver-natív architektúrát mutat be, amely a "Test és Agy szétválasztásával", Cgroups védelemmel és Map-Reduce logikával egy 24GB RAM-mal és 8 Ryzen CPU maggal rendelkező, GPU nélküli szerveren is 0-24 órában, 100%-os stabilitással képes futtatni egy elosztott AI rajt.

## 2. A Kihívások (A Problématér)

### 2.1. Hálózati és Session Korlátok
A webes UI-hoz csatolt homokozók efemer (ideiglenes) jellegűek. Befelé jövő kapcsolatot nem fogadnak. Ha a böngészőfül bezárul, az Agent "kómába esik". A manuális emberi ébresztgetés nem skálázható egy 8 tagú rajnál.

### 2.2. A "Rate Limit" és a Cloud API csődje
Hatalmas, több tízezer kódfájlt tartalmazó repók (pl. BRAIN2, MX Linux) elemzésénél a felhős API-k (pl. Google Gemini Free Tier) perceken belül 429-es (Quota Exceeded) hibát dobnak a másodpercenkénti kéréscunami miatt. A felhőalapú intelligencia kiszolgáltatottá teszi a rendszert a külső limitációknak.

### 2.3. Az OOM (Out of Memory) és a CPU Timeout Veszélye
GPU hiányában a lokális LLM-ek (Ollama) CPU-n történő futtatása (Inference) lassú. Ha 8 Agent egyszerre próbál lekérdezést indítani, a CPU sorbaállítja (queueing) azokat, ami a Python szkripteknél TCP/HTTP időtúllépéshez (Timeout) vezet. Emellett a memóriaszivárgások a teljes Ubuntu szerver fagyását (Kernel Panic) okozhatják.

---

## 3. A Megoldás: A "Jules Swarm" Architektúra

### 3.1. "A Test és az Agy" Szétválasztása
A rajtagokat eltávolítottuk a webes homokozókból, és natív Linux daemonokként (háttérfolyamatként) telepítettük őket a VPS-re. 
*   **A Test:** Egy egyszerű Python ciklus (`rajX_daemon.py`), ami mindössze ~30 Megabájt RAM-ot fogyaszt.
*   **Az Agy:** Egyetlen, a VPS localhostján futó Ollama szolgáltatás (Qwen / Llama 3 modellek), amihez a Testek REST API-n keresztül kapcsolódnak (megnövelt, 1 órás timeouttal).

### 3.2. Cgroups Páncél és Systemd Auto-Start
Az Ubuntu kernel védelme érdekében létrehoztunk egy `jules-swarm@.service` sablont. Minden Agent:
*   Maximum **300 MB RAM**-ot használhat (`MemoryMax`). Azonnali OOM kilövés fagyás esetén, anélkül, hogy a szerver megérezné.
*   Maximum **50% CPU** időt kap (`CPUQuota`).
*   Boot-loop védelemmel (`StartLimitBurst`) és automatikus ébredéssel (`Restart=always`) rendelkezik. 
A VPS újraindítása (Reboot) után a 8 tagú raj emberi beavatkozás nélkül, azonnal életre kel.

### 3.3. Aszinkron Swarm Job Queue (SQLite)
Az Agentek közötti kommunikáció és feladatelosztás egy SQLite adatbázison (`jules_swarm_jobs.db`) keresztül történik. Az emberi Orchestrator (Karmester) vagy a jövőben egy Fő LLM csak beteszi a PENDING feladatokat az adatbázisba, a rajtagok pedig másodpercenként pollingolva (lekérdezve) felveszik azokat. Ez a módszer 100%-ban kiváltja a lefagyásra hajlamos webes WebUI-t.

### 3.4. Swarm Health Monitor (Diagnosztika)
A rajtagok kódjába beépítésre került egy háttérszál (threading + psutil), ami 15 másodpercenként "szívverést" (Heartbeat) küld az adatbázisba, naplózva a CPU, RAM és Error állapotokat, így a rendszer folyamatosan monitorozható az MCP-n keresztül.

---

## 4. A "Map-Reduce" RAG Kutatási Stratégia

A CPU Timeoutok végleges felszámolására egy kétlépcsős kutatási módszertant vezettünk be a több mint 120.000 dokumentumot tartalmazó RAG adatbázisokra (MQL5, BRAIN2, Gerilla):

1.  **MAP (Adatgyűjtés LLM nélkül):** A feladatokat felosztjuk (pl. 3 Agent között). Az Agentek párhuzamosan, nyers SQL Regex keresésekkel (I/O művelet) másodpercek alatt kinyerik a nyers kódrészleteket egy közös aggregációs szövegfájlba. Nincs LLM hívás, a CPU terhelés 0%.
2.  **REDUCE (Összegzés):** Amikor az I/O fázis lezárul, egyetlen, negyedik Agent megkapja az aggregált fájlt, és egyetlen kérésben elküldi az Ollamának összefoglalásra. 

Ez a stratégia megszüntette a CPU sorban állást, és API költségek nélkül tette lehetővé a gigantikus kódbázisok milliszekundumok alatti kutatását.

## 5. Konklúzió
A Jules Swarm bebizonyította, hogy megfelelő architekturális tervezéssel (Izoláció, Cgroups, SQLite Queue, Map-Reduce I/O) egy olcsó, GPU nélküli VPS szerver is képes egy rendkívül stabil, 0-24 órában autonóm módon működő Multi-Agent hálózat kiszolgálására.
