# Vektorizált és Klónozott Repozitóriumok (TradingView & MT5)

A Felhasználó kérésére (és a Gemini javaslata alapján) az alábbi külső (External) repozitóriumok kerültek fel a VPS-re és bekerültek a RAG adatbázisba (`gui_rag.db`) a jövőbeli TradingView integrációk megkönnyítése érdekében:

## 1. DarwinexLabs
- **Forrás:** `https://github.com/darwinex/DarwinexLabs.git`
- **Típus:** MT5 Python integráció, ZeroMQ bridge megoldások, MLOps példák.
- **RAG Állapot:** Klónozva és Vektorizálva (2026.08.27)

## 2. Freqtrade
- **Forrás:** `https://github.com/freqtrade/freqtrade.git`
- **Típus:** Kripto kereskedő bot framework lokális adatvizualizációkkal és masszív adatkezelési logikákkal.
- **RAG Állapot:** Klónozva és Vektorizálva (2026.08.27)

## 3. TradingView Charting Library ("Unlocked")
- **Forrás:** `https://github.com/goldcrown8/tradingview-charting-library.git`
- **Típus:** A hivatalos (Advanced) TradingView grafikonrajzoló motor, amely HTML+JS alapú és natívan tud WebSockets adatfolyamot fogadni saját backendtől.
- **RAG Állapot:** Klónozva és Vektorizálva (2026.08.27)

## 4. MQL-CopyTrade
- **Forrás:** `https://github.com/anlv/MQL-CopyTrade.git`
- **Típus:** MT5 kódpéldák aszinkron kommunikációra.
- **RAG Állapot:** Klónozva és Vektorizálva (2026.08.27)

---

**Technikai Részletek:**
A RAG adatbázis (`gui_rag.db`) mérete a frissítés után eléri a ~2.2 GB-ot. Több mint 9 millió sornyi új forráskód indexelődött a FAISS-hez.
Jövőbeli TV-Python-MT5 architektúra kérdésekhez a `rag_interrogator.py` segítségével azonnal lekérdezhető az összes fenti repó tudása.
