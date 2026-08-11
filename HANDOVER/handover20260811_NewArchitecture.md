# MILESTONE HANDOVER & ARCHITECTURE REPORT
**Date:** 2026-08-11
**Target:** Transition to Dual-Socket Memory-Based Feature Fusion (Removing CSV dependency)

## 1. Jelenlegi Állapot és a Probléma
A LightGBM Feature Fusion modell (`lgbm_model_fusion_v5_tuned.pkl`) rendkívül sikeres az algoritmikus scalpolásban (Prado Dollar Bars), mert egyesíti az aszinkron tick szintű sebességet a kronologikus M1 makro geometriával (ZigZag, AMA, Stochastic).
A jelenlegi **ÉLŐ (Live MT5)** architektúra azonban egy hibrid öszvér:
- **Mikro/Tick adat (5556-os port):** Az MT5 `OnTick()` függvénye folyamatosan küldi a TCP/Socket csatornán a tickeket. Ez tökéletesen működik, a Python `TickReceiver` felépíti belőle a Dollar Bar-okat.
- **Makro/M1 adat (CSV Fájl):** A Python `MacroReceiver` osztálya egy *fájlrendszeri* figyelő (`glob`), ami megpróbálja elkapni az MT5 által írt `Merkava_MGCV26_v1.10_*.csv` fájlt.
**A Probléma:** Ez a CSV-alapú kommunikáció I/O intenzív, lassú, de a legnagyobb baj, hogy instabil. Minden EA induláskor (vagy szimbólum/szerződés váltáskor, pl. MGCZ26-ról MGCV26-ra) a CSV neve megváltozik, a Python kód nem találja, a szinkronizáció felborul, és a `merge_asof` logika helyett a rendszer összeomlik vagy dummy adatokat gyárt.

## 2. A Célarchitektúra: Dual-Socket Memory Fusion
A CSV-kommunikációt végleg ki kell irtani az élő kereskedési láncból. A jövőbeli architektúra teljesen a memóriában zajlik, csővezetéken (socketeken) keresztül.
- **MT5 EA Oldal (Sender):** Két TCP konnekciót tart fenn a Pythonnal.
  1. `Port 5556`: Tick/DOM sebesség és nyersár küldése (folyamatosan).
  2. `Port 5555`: M1 Makro állapot (Stochastic, AMA, Zigzag) küldése másodpercenként vagy a perces gyertya zárásakor JSON formátumban.
- **Python Copilot Oldal (Receiver & Fusion):**
  1. `MacroReceiver (Port 5555)`: Háttérszál, amely folyamatosan hallgatja az 5555-ös portot, és az utolsó kapott makroállapotot beteszi egy globális, szálbiztos (O(1)) memóriaváltozóba (`GLOBAL_MACRO_STATE`).
  2. `TickReceiver (Port 5556)`: Építi a Dollar Bar-t. Amikor a küszöböt eléri és lezárul a Bar, **azonnal kiolvassa** a `GLOBAL_MACRO_STATE`-et, egyesíti a mikro paraméterekkel, és beküldi a LightGBM modellbe.

## 3. A Feature Vektor (Pontosan 10 Feature)
A `v5_tuned` LightGBM modell szigorúan 10 elemből álló bemenetet vár (Shape Mismatch hiba elkerülése végett!). A feature-ök bontása a következő:

### Mikro Feature-ök (Dollar Bar alapján a Pythonban generálódnak)
1. `Tick_Speed`: Az idő (másodperc), ami alatt a Dollar Bar felépült a tickekből.
2. `Upper_Wick_ATR`: A gyertya felső kanócának (High - Max(Open,Close)) hossza, ATR-rel normalizálva (Whipsaw detektor).
3. `Lower_Wick_ATR`: A gyertya alsó kanócának hossza, ATR-rel normalizálva.

### Makro Feature-ök (Az 5555-ös portról, az MQL5 `CZigZagEngine`-ből kell jönniük)
4. `Dist_Micro_R`: (Close - Micro Resistance Pivot) / ATR
5. `Dist_Micro_S`: (Close - Micro Support Pivot) / ATR
6. `Dist_Sec_R`: (Close - Secondary Resistance Pivot) / ATR
7. `Dist_Sec_S`: (Close - Secondary Support Pivot) / ATR
8. `Dist_Ter_R`: (Close - Tertiary Resistance Pivot) / ATR
9. `Dist_Ter_S`: (Close - Tertiary Support Pivot) / ATR
10. `Stoch_State_M1`: Ultra gyors M1 Stochastic (2,3,3) normalizált állapota [-1, 1] között.

*(Megjegyzés: Minden távolság az MQL5 oldalon kerül kiszámításra a `CZigZagEngine` által, és ATR-rel normalizálva kerül beküldésre.)*

## 4. Rendszer Elemek és Szkriptek Funkciói
- **`Micro_LGBM/src/mt5_live_copilot.py`**: A fő Python szerver. Itt fut a betanított modell. Kezeli a két portot (5556, 5555). Kiszámolja a predikciót (Long, Short, Noise valószínűségek 4D Aszimmetrikus küszöbökkel), visszaküldi a jelet az MT5-nek, és publikálja a HUD számára az 5557-es ZMQ porton. (Továbbfejlesztendő a következő sessionben CSV mentesre).
- **`Micro_LGBM/src/copilot_hud.py`**: A PyQt5/pyqtgraph grafikus felület a VPS-en ( LXQt ). Az 5557-es porton hallgat, kirajzolja a P_Long/P_Short vonalakat és az aktuális hold/buy/sell ajánlást. (Tökéletesen működik).
- **`Micro_LGBM/src/pipeline_master.py`**: A betanítási csővezeték automatizáló szkriptje. Ha valaha is újra kell tanítani a modellt (mert jön egy új Master_csv történelmi adathalmaz), ez a script csinálja végig a Dollar Bar építést -> Feature Fusiont -> Labelinget -> Traininget.
- **`MQL5/Experts/Merkava_Behavioral_Profiler_v1.7_Online.mq5` (vagy jövőbeni verziója)**: Az MT5 robot, amelynek a feladata (1) a `CZigZagEngine` futtatása, (2) adatok küldése a két portra, (3) a Python predikciójának fogadása és végrehajtása/naplózása. (Ezt a következő sessionben kell módosítani a makro adatok socketes küldésére).

## 5. Elvárások a Következő Sessionhöz
A következő AI iteráció feladata **kizárólag** a fenti architektúra implementálása lesz:
1. `mt5_live_copilot.py` átírása úgy, hogy az `5555`-ös portra Socket Servert nyisson a `MacroReceiver`, és egy globális dictionary-be tegye be a JSON-ként érkező Makro adatokat.
2. Az MQL5 EA (amely jelenleg fájlba írja a makrót) módosítása úgy, hogy az `OnTimer()` vagy `OnTick()` ciklusban, amikor frissül a makro, nyisson rá a `127.0.0.1:5555`-re, és lője át a fent említett 7 db Makro változót egy stringben/JSON-ban.
