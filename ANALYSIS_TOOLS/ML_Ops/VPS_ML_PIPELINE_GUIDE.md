# ML-Ops Pipeline & Valós Idejű Streaming Útmutató (VPS)

Ez a dokumentum a megújult, **Önadaptív Látótér** architektúrára épülő Machine Learning pipeline használatát írja le. Az új rendszer képes a MetaTrader 5 (MT5) tick-adatait szimulált valós időben (streaming) feldolgozni, és a piaci volatilitáshoz (Kaufman Efficiency Ratio) igazítani a saját LSTM memóriáját (szekvenciahosszát) és a detektálási küszöböt (Page-Hinkley drift teszt).

## 1. Függőségek és Telepítés (VPS Környezet)
A rendszer egy memóriakorlátos (8GB RAM), CPU-only környezetre lett optimalizálva (pl. Ubuntu VPS).
Győződj meg róla, hogy az alábbi könyvtárak telepítve vannak a Python 3 virtuális környezetedben:

```bash
pip install pandas numpy scikit-learn tensorflow scipy dtaianomaly
```

*Megjegyzés: A `scipy` a spektrális zajszűréshez (Savitzky-Golay Denoising), a `tensorflow` a Keras LSTM modellhez, a `dtaianomaly` pedig az idősoros funkciókhoz szükséges.*

## 2. A Valós Idejű Szimulátor Futtatása (Streaming)

A rendszer lelke a `run_streaming_simulation.py`. Ez a script fogja a `data/` mappában lévő nyers (DataMiner) CSV fájlokat, és tickenként (milliszekundumos időzítéssel) "beadagolja" a hálózatnak, pontosan úgy, mintha egy élő MT5 kapcsolat lenne.

### Adatok előkészítése
Másold be a MetaTrader 5-ből exportált CSV fájlt pontosan az eredeti fájlnevével (pl. `Merkava_XAUUSD_v1.10_*.csv`) a VPS-en található `Merkava_ML_Ops/data/` könyvtárba. Semmilyen átnevezésre vagy szerkesztésre nincs szükség, a script automatikusan felismeri és beolvassa a nyers DataMiner logokat!

### A Szimuláció Indítása
Lépj be a VPS munkakönyvtárába (`Merkava_ML_Ops/`), állítsd be a Python útvonalat a jelenlegi mappára (`.`), és indítsd el a scriptet:

```bash
cd ~/Merkava_ML_Ops/
export PYTHONPATH=.
python3 run_streaming_simulation.py
```

### Mit fogsz látni futás közben?
A konzolon a következő eseményeket követheted nyomon:
*   **[Virtual Streamer]**: Betölti a fájlt és elindítja a virtuális időzítőt. Alkalmazza a Savitzky-Golay mikro-zajszűrést a Bid árfolyamon.
*   **[KALIBRÁCIÓ]**: Az induláskor (Warm-up fázis) és minden 5. virtuális percben a rendszer megvizsgálja a Kaufman Efficiency Ratio-t (ER). Ha a piac "döglött" (ER ~ 0), megnöveli az LSTM ablakot (pl. 150 tick). Ha a piac pörög (ER ~ 1), lecsökkenti az ablakot (pl. 40 tick). Ekkor a modell betanulja az eddigi "normál" mozgásokat.
*   **⚠️ [DRIFT DETEKTÁLVA]**: Ha a bróker elkezdi masszívan manipulálni az árat (a normális hibaeloszlás hirtelen és tartósan megváltozik), a Page-Hinkley teszt riaszt, és a rendszer a súlyok újratanítása nélkül újra-kalkulálja a hiba-küszöböt (Threshold).
*   **🚨 [BRÓKERI MANŐVER]**: Amikor a `RollingLSTM` által mért visszaépítési hiba (Reconstruction Error) túllépi a dinamikusan számított küszöböt, a rendszer anomáliát (színész beavatkozást) jelez.

## 3. Modellek és Modulok Működése

*   **`pipeline/adaptive_windowing.py`**: Itt található a Kaufman ER matematika, amely a piaci zaj/trend arányt fordítja le optimális szekvenciahosszra a Gemini kutatás alapján.
*   **`pipeline/page_hinkley.py`**: A matematikai drift-detektor, ami megvédi a hálózatot a "Katasztrofális Felejtéstől" (amikor a gép elkezdené "normálisnak" tekinteni az elhúzódó brókeri rángatást).
*   **`models/rolling_lstm.py`**: A Keras LSTM Autoencoder stateful, csúszóablakos (deque) megvalósítása. Numpy és Tensor szintű optimalizációkkal lett felgyorsítva, hogy a Keras ne terhelje túl a VPS processzorát.
*   **`pipeline/virtual_streamer.py`**: A Time-Bucketing motor, ami a valós időt szimulálja a CSV időbélyegek alapján.

## 4. Tesztelés (Fejlesztőknek)

A kód stabilitásának megőrzéséhez egy komplett `pytest` tesztcsomag is rendelkezésre áll, ami leellenőrzi a Streaming logikát, az idő szivárgást (Target Leak) és az $O(1)$ optimalizált Keras hívásokat. A tesztek futtatása a VPS munkakönyvtárából (`Merkava_ML_Ops/`):

```bash
cd ~/Merkava_ML_Ops/
export PYTHONPATH=.
python3 -m pytest tests/
```

