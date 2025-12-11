# Colombo Trading System v5.0 - Dokumentáció

## 1. Rendszer Áttekintés
A **Colombo v5.0** egy hibrid kereskedési rendszer, amely ötvözi a MetaTrader 5 (MQL5) sebességét és a Python (SciPy) matematikai erejét.
A cél: **Késésmentes (Zero-Phase) Trendkövetés** a piaci zaj kiszűrésével.

## 2. Architektúra
*   **MQL5 Expert Advisor (`WPR_Analyst_v5_Colombo.mq5`):** A rendszer agya és végrehajtója. Kezeli a kockázatot, a panelen keresztüli interakciót és a kereskedést.
*   **MQL5 Indikátor (`Colombo_MACD_MTF.mq5`):** A híd. Nyers adatokat (MACD) exportál CSV-be, és beolvassa a Python által feldolgozott (szűrt) jeleket.
*   **Python DSP Engine (`colombo_filter.py`):** A háttérfolyamat. Figyeli a CSV fájlt, és Savitzky-Golay szűrővel + extrapolációval eltünteti a fáziskésést (Lag).

## 3. Működési Logika
1.  **Adatgyűjtés:** Az EA minden tickben (vagy új gyertyánál) frissíti a nyers MACD adatokat a `colombo_macd_data.csv`-be.
2.  **Jelfeldolgozás (Python):**
    *   A script érzékeli a fájl változását.
    *   **Extrapoláció:** Megjósolja a következő 5-10 gyertyát (hogy a szűrőnek legyen kifutása).
    *   **Zero-Phase Szűrés:** `scipy.signal` segítségével kisimítja a görbét úgy, hogy a csúcsok/völgyek nem tolódnak el időben.
    *   **Visszaírás:** Az eredményt a `colombo_processed.csv`-be menti.
3.  **Végrehajtás (EA):**
    *   Az EA beolvassa a szűrt jelet.
    *   **Signal:** Ha a szűrt MACD keresztezi a szűrt Signal vonalat -> VÉTEL/ELADÁS.
    *   **Kockázatkezelés:** ATR alapú Stop Loss, Margin ellenőrzés, Automatikus Lot méretezés.

## 4. Képességek
*   **Zajmentes Scalping:** A Python szűrő képes kiszedni a piaci "rángatózást" (noise) anélkül, hogy késést vinne a rendszerbe (mint a sima EMA).
*   **Vizuális Panel:** Gombok (BUY/SELL/CLOSE), Egyenleg és P/L kijelzés a charton.
*   **ATR Menedzsment:** Dinamikus SL/TP és Csúszó Stop (Trailing Stop) a piaci volatilitás (ATR) alapján.
*   **Hibrid Üzemmód:** Félautomata (gombokkal) vagy Teljesen Automata mód.

## 5. Telepítés & Indítás
1.  **MQL5:** Fordítsd le a `Colombo_MACD_MTF.mq5` és `WPR_Analyst_v5_Colombo.mq5` fájlokat.
2.  **Chart:** Húzd az EA-t a chartra (M1 vagy M5).
3.  **Python:** Indítsd el a háttérben: `python3 colombo_filter.py`.
4.  **Engedélyezés:** MQL5-ben engedélyezd a DLL-t (ha szükséges, bár itt CSV-t használunk) és a Fájl műveleteket.
