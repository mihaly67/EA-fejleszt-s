# 🔮 HMM KITERJESZTÉSE V2: A Jelenből a Jövőbe (Statisztikai Prediktív Rendszer)

A VPS repóinak (pl. `Hands-On-Markov-Models-with-Python-master`, `hidden_markov_model_temporal_graphs-main`) és az `MQL5_Theory_RAG` (különösen az ALGLIB SSA forecast és ONNX Inference cikkek) áttekintése után a Vaku 3.0 rendszert kibővítjük.
Mivel GPU nincs, a hangsúly a memóriakímélő, O(1)-es statisztikai és gráf-alapú predikciókon van a nehéz Deep Learning (LSTM, RL) helyett.

## A Matematikai Áttörés: HMM4G (Temporal Graphs) + Viterbi Mátrix
Az eddigi Vaku 3.0 csak a "Jelent" látta (egy egyszerű GaussianHMM pillanatnyi centroid klaszterezésével). Most ezt két kőkemény statisztikai modullal bővítjük.

### 1. A Viterbi Átmeneti Mátrix (Helyi Python Predikció)
A klasszikus `hmmlearn` modellünk a betanulás után megalkot egy `transmat_` (Transition Matrix) valószínűségi hálót.
- A modell a Viterbi dekódolással (amit a `Hands-On` repó `viterbi.py` implementációjában is láttunk) visszaköveti a múltbeli rejtett állapotok ösvényét (Path).
- Ebből az ösvényből és a pillanatnyi Posteriori valószínűségből (jelenlegi állapot) **megszorozva a Transmat-tal** kiszámoljuk a $T+1$ (következő tick) valószínűségeloszlását.
- *Logika:* `P(Jövő=Színház) = P(Jelen) * Transmat[Jelen, Színház]`

### 2. Singular Spectrum Analysis (SSA) Forecast - Az ALGLIB minta alapján
Az MQL5 oldalán talált `ALGLIB.SSAAnalyzeSequence` (és incremental realtime) kód alapján bevonjuk az SSA (Singular Spectrum Analysis) idősoros predikciót a Python oldalra.
- Az SSA dekomponálja a nyers árat Trend, Oszcilláció és Zaj komponensekre.
- Mivel a HMM csak a zaj/statisztika alapján dolgozik, az SSA "trend" komponense (amit pl. az MQL5 `ssaforecastlast()` csinál) egy megbízható **Iránymutató Vektor** (Vector Direction) lesz.

### 3. Az ONNX Inference Export (Az "Időgép" áthozása MT5-be)
A cikkekből (pl. CSignalIL_Stochastic_FrAMA) láttuk, hogy az MQL5 profi szinten támogatja az ONNX formátumot (`OnnxRun()`). 
Ahelyett, hogy egy lassú (esetleg lefagyó) ZMQ hálózaton küldenénk a tickeket a Pythonnak, a HMM és az SSA normalizáló pipeline-unkat **ONNX formátumba exportáljuk** (Scikit-learn ONNX exporttal, vagy egyszerű mátrix formában).
- Így az MT5 EA lokálisan, C++ sebességgel (mikromásodpercek alatt) hívja meg az `Infer()` metódust minden tickre: beleteszi a 6 statisztikai feature-t, és az ONNX visszaadja az Állapot ID-t (0,1,2).

## Tervezett Architektúra (System 2 Blueprint)

**A. Képzési Fázis (Python - VPS Offline)**
1. `label_broker_reaction.py`: Címkézi a manipulációkat az éles CSV-ken.
2. `vaku3_offline_validator.py`: StandardScaler + Covar=Full GaussianHMM tanulás.
3. *ÚJ:* HMM Transition Mátrix és Centroidok exportálása `.json` vagy ONNX formátumba az MT5 számára.

**B. Éles Kereskedési Fázis (MQL5 EA - ZMQ VAGY ONNX)**
- Az EA a betöltött Mátrix/ONNX segítségével minden OnTick()-ben maga számolja ki a Viterbi $T+1$ predikciót.
- Ha a Jövőbeli Kockázat (Risk_Theater) > 60%, a kereskedés tiltva van.
