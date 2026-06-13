# HANDOVER: Vaku 3.0 MT5 Online Integráció

## Jelenlegi Állapot (Mit értünk el?)
A Vaku 3.0 (HMM alapú scalping elemző) grafikus Műszerfala (Dashboard) sikeresen stabilizálva lett **V8.03 Offline** verzió néven (`vaku3_dashboard_v803_offline.py`).
Ez az offline verzió tökéletesen, alacsony CPU használattal működik egy 2-napos történelmi XAUUSD CSV fájlon, szigorúan csak két idősíkot (S30 és M1) használva, optimalizált Káosz/Rizikó (Volatility) küszöbökkel.

## A Következő Feladat (Mit kell csinálnod?)
A felhasználó a rendszert most már **ÉLŐBEN (Online)** szeretné használni a MetaTrader 5-tel (MT5), BTCUSD charton.

A te feladatod az **MT5 ZMQ Bridge és a Historikus Tick Betöltés** hibátlan integrációja:

1. **A ZMQ Híd Kiépítése:**
   - Jelenleg van egy `vaku3_dashboard_v8.py`, amiben elkezdtük a ZMQ (ZeroMQ) socketek implementálását, de még nem működik tökéletesen (MT5 oldalról is hiányozhat a küldő logika, vagy a Python oldal nem jól fogadja).
   - A RAG tudásbázisban (vagy a GitHubon, ha kell, PAT-al keresve) meg kell találnod a megfelelő MQL5 <-> Python ZMQ híd protokollját és alkalmaznod kell.

2. **Historikus Tickek (Múlt) Beolvasása Induláskor:**
   - Amikor a Dashboard elindul, **nem várhat perceket** a buffer feltöltésére (HMM pre-warm).
   - Képessé kell tenned a Python kódot arra, hogy közvetlenül az MT5 mappájából (`/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/`) kiolvassa a legutolsó 600 ticket, *mielőtt* rácsatlakozik az élő ZMQ streamre!
   - (A korábbi megoldásunk, ahol a `Merkava_*_MINER.csv`-ből tail-eltünk, nem volt megfelelő, a felhasználó valamilyen MQL5/DLL vagy direkt fájl alapú "múlt-lekérést" szeretne, ami azonnal feltölti az O(1) RingBuffereket).

3. **Baseline (Alap):**
   - Minden online fejlesztésedhez a stabil `vaku3_dashboard_v803_offline.py` fájlból kell kiindulnod, mivel annak a vizualizációs és matematikai logikája már elfogadott és hibátlan! Ne használj Streamlit-et, maradj a PyQt5-nél!

## Környezet és Paraméterek
- **VPS Elérhetőség:** `misi@5.189.163.88` (Jelszó biztonságosan tárolva az Agent memóriában - *Szigorúan tilos Gitbe vagy fájlba kiírni!*)
- **MT5 Útvonal:** `/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/`
- **Munkakönyvtár:** `/home/misi/Merkava_ML_Ops/`
- **Python Venv:** `source /home/misi/ML_Ops/venv/bin/activate`
