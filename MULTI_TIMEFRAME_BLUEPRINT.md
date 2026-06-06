# 📊 MULTI-TIMEFRAME (TÖBB ABLAKOS) STATISZTIKAI VALIDÁCIÓ

A MQL5 és ML_Ops RAG kutatás (pl. a `CSignal` logikák és az `ALGLIB` idősíkok) alapján bebizonyosodott, hogy egyetlen időablak (Tick Window) önmagában vak. Hiába tudjuk, hogy az utolsó 15 tick mi volt (Mikro ablak), ha nem tudjuk, hogy egy nagy H1 gyertya közepén vagyunk-e egy hírverésben (Makro ablak).

A Vaku 3.0 rendszert kibővítjük a **Cascading Window (Lépcsőzetes Ablak)** vagy Multi-Timeframe megerősítéssel. Mivel nincsenek hagyományos gyertyáink, hanem "Tick" folyamunk van a RingBufferben, az időablakokat (Timeframes) a tick számok (N) skálázásával érjük el.

## 1. A Kettős O(1) RingBuffer Struktúra
Az MT5 EA nem 1, hanem **2 párhuzamos adatfolyamot (vagy ablakot)** tart fenn (vagy küld a Pythonnak):
1. **Mikro Ablak (Végrehajtó):** `N = 15 - 30` tick (Kb. 1-2 másodperc/perc a piactól függően). Ezt használja a HMM Viterbi predikció a közvetlen "Színház" (Manipuláció, Spread ugrás) kiszűrésére belépés előtt.
2. **Makro Ablak (Kontextus):** `N = 500 - 2000` tick (Kb. 30-60 perc). Ez a statisztikai Trend / Volatilitás szűrő. Ezen a távon fut az `ALGLIB SSA` (Singular Spectrum Analysis) vagy egy lassú HMM, ami megadja a *Környezetet*.

## 2. A "Faggatás" és Döntési Mátrix (A Szinergia)
Amikor az EA jelet kap a belépésre, *mindkét* ablakot "kifaggatja". A végső belépés engedélyezése egy logikai ÉS/VAGY mátrix:

| Makro Ablak (Kontextus) | Mikro Ablak (Viterbi Predict) | EA Döntés (Ació) | Magyarázat |
| :--- | :--- | :--- | :--- |
| **Betonfal** (Tiszta Trend) | **Betonfal** (Nincs Manipuláció) | ✅ ENGEDÉLYEZVE | Teljes egyetértés, a piac tiszta makro és mikro szinten is. |
| **Betonfal** (Tiszta Trend) | **Színház** (> 40% Kockázat) | ⏸ VÁRAKOZÁS | A trend jó, de a bróker épp most rántott egyet. Várjuk meg a Viterbi lecsengését. |
| **Zajos/Oldalazó** | **Betonfal** | ❌ TILTVA | Bár most épp csend van (1-2 másodpercre), a nagy kép zavaros. Felesleges kockázat. |
| **Zajos/Oldalazó** | **Színház** | ❌ TILTVA | Totális káosz. |

## 3. Implementáció a Vaku 3.0-ban
A Python API (ZMQ Szerver) vagy a kigenerált ONNX mostantól két bemenetet (Input Shape) kér:
- `obs_micro`: `[LogER_15, Spread_15, Density_15]`
- `obs_macro`: `[LogER_1000, Spread_1000, Density_1000]`

A Python (vagy ONNX) mindkét vektorra lefuttatja a `StandardScaler`-t és a predikciót.
- `macro_state = model_macro.predict(obs_macro)`
- `micro_risk = predict_future_risk(obs_micro)`

Az EA a visszakapott Tuple `(macro_state, micro_risk)` alapján hoz autonóm (Advisory) döntést a fenti mátrix alapján.
