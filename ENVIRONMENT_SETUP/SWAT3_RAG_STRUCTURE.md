# SWAT3 RAG KÖRNYEZET & REPO STRUKTÚRA

**Dátum:** 2026.03.14 (Néma Színház Operáció, ML-Ops Fázis)
**Database ID (Google Drive):** `1-t8kjijjg7cf4gXp9_z8GffGq_fTa_Uk`

Ez a dokumentum a `SWAT3_RAG` környezetbe integrált adatbázisok és nyílt forráskódú repositoryk tartalmát és szerepét foglalja össze. A SWAT3 a HMM (Hidden Markov Model), az Autoencoderek, és a mély megerősítéses tanulás (RL) felé fókuszál az összegyűjtött MT5 tick/indikátor adatok normalizálása és tisztítása céljából.

---

## 1. ML_Ops (Gépi Tanulás, HMM és Adatkezelés)
Ezek a repók alkotják a gerincét a Data Miner által kinyert CSV adatok feldolgozásának, az idősoros anomáliák szűrésének és a modellek betanításának. Fókuszban a HMM és az RL.

*   **HMM & Idősoros Modellek:** `hidden-markov-model`, `hmmlearn`, `LSTM-AutoEncoder-Unsupervised-Anomaly-Detection`, `LSTM-Autoencoders`
*   **Megerősítéses Tanulás (RL):** `FinRL`, `FinRL-Trading`, `FinRL-Meta`, `MARLlib`, `TradingAgents`, `rl-baselines3-zoo`, `stable-baselines3`
*   **Adattudomány és Szűrés:** `Technical-Analysis-Indicators---Pandas`, `dtaianomaly`, `stumpy`, `vectorbt`
*   **Környezet & Ops:** `airflow`, `mlflow`, `optuna`, `ray`, `streamlit`, `zenml`, `ArcticDB`, `Qwen`
*   **MT5 Python Híd:** `mt5linux`, `pymt5linux`

## 2. Black_Ops (Alacsony szintű Monitorozás és Evasions)
Rendszermag szintű betekintést és bypass lehetőségeket kínáló eszközök (BCC, eBPF, Frida, Syscalls), amelyek elsősorban az MX Linuxos hoszt megfigyelést támogatják WINE környezet felett.

*   **eBPF / Telemetria:** `bcc`, `ebpf`, `telemetry`, `wireshark`
*   **Injection / Syscalls:** `SysWhispers2`, `SysWhispers4`, `InlineWhispers3`, `SyscallInjector`, `ReflectiveDLLInjection`, `Process-Herpaderping`
*   **Evasion / Anti-Detect:** `ScyllaHide`, `TitanHide`, `amiunique`, `al-khaser`, `fingerprintjs`
*   **DPI & Hooking:** `frida-core`, `frida-main`, `Interception`, `mitmproxy`

## 3. Colombo (Vizsgálat & Detektálás)
Csalások, anomáliák felderítésére és a gépi tanulás ok-okozati (causal) értelmezésére fókuszáló eszközök.

*   **Detektálás:** `alibi-detect`, `pyod`
*   **Okozati Elemzés:** `causalml`, `dowhy`
*   **Környezet Tesztelés:** `chaosmonkey`
*   **Algoritmikus Eszközök:** `mlfinlab`, `quantstats`, `PettingZoo`

## 4. Thief (Adatgyűjtés & Protokollok)
Kereskedési protokollok, API kapcsolatok és automatizált adatgyűjtési technikák (scraping, stealth).

*   **API / Bróker Kapcsolatok:** `ccxt`, `freqtrade`, `nautilus_trader`, `quickfix`, `QuantLib-SWIG`
*   **Stealth & Interakció:** `selenium-stealth`, `pyautogui`, `pafish`
*   **Matematikai Eszközök:** `stochastic`, `vectorbt` (also in ML)
*   **MQL5 Library:** `RoffildLibrary`

---

## Elemzési Cél (HMM & Data Cleaning)
Az itt található repók (különösen a `hmmlearn`, `LSTM-Autoencoders`, és a `FinRL`) adják meg a választ arra, hogy a `Merkava_Data_Miner_v1.0.mq5` által másodpercenként exportált több millió ticknyi "zajos" adatot **hogyan normalizáljuk, tisztítsuk meg, és hogyan építsünk belőle rejtett állapotokat**. A HMM (Hidden Markov Model) pont a "tick-burstökben" (zajban) elrejtett brókeri manipulációt és spread-tágítást fogja klaszterezni felügyelet nélküli (unsupervised) módon.
