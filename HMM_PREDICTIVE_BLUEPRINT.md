# 🔮 HMM KITERJESZTÉSE: A Jelenből a Jövőbe (Prediktív Rendszer)

A Vaku 3.0 eddig a HMM-et **Diagnosztikára** használta: "Miben vagyunk most?"
A felhasználó kérésére, a `/home/misi/ML_Ops/Hands-On-Markov-Models-with-Python-master/` RAG-ból vett Viterbi algoritmus és az `MQL5_Theory` alapján a rendszert kiterjesztjük a Jövő (Predikció) irányába.

## A Matematikai Áttörés: Viterbi + Transition Matrix

A `hmmlearn` által generált modellünk nem csak a pillanatnyi 3D tér (LogER, Spread, Tick Density) centroidjait (Means) tanulja meg, hanem az **Állapotátmeneti Mátrixot (Transition Matrix)** is.

### 1. A Transition Matrix (Múlt és Jelen -> Jövő)
Ez a mátrix megmondja a valószínűségeket az állapotváltozásokra. Például:
`P(Jövő=Színház | Jelen=Betonfal, Múlt=Csendes) = 0.85`
Ezzel meg tudjuk mondani a ZMQ hídon az MT5-nek, hogy bár *most* tiszta a piac, 85% esély van arra, hogy a következő tickeknél a bróker "Színház" (Manipuláció) állapotba rántja a piacot, ezért TILTOTT a belépés!

### 2. A Kiterjesztett Vaku 3.0 Online Engine
A Python motor nem csak a `model.predict(obs)` (ami a legvalószínűbb *jelenlegi* állapot) funkciót fogja futtatni.
Ehelyett a `model.predict_proba(obs)` és a Viterbi dekódolás segítségével kiszámolja a következő $T+1$ időlépés (Tick) valószínűségét.

**Az új Python Kód Logikája (A HMM "Kimaxolása"):**
```python
def predict_future_state(self, current_obs_sequence):
    """
    Nem csak a jelent, a következő tick valószínűségét is megmondja.
    """
    # 1. Jelenlegi Állapot Valószínűség (Posterior)
    posterior_probs = self.model.predict_proba(current_obs_sequence)[-1]
    
    # 2. Átmeneti Mátrix (Transition Matrix)
    trans_mat = self.model.transmat_
    
    # 3. Jövőbeli Valószínűség = Posterior (dot) Transition
    future_probs = np.dot(posterior_probs, trans_mat)
    
    # Kinyerjük a 'Színház' (Manipuláció) jövőbeli esélyét (pl. State 1)
    theater_state_id = self.state_map["Theater"]
    theater_risk = future_probs[theater_state_id]
    
    # Ha a rizikó > 40%, vörös jelzés az MT5-nek
    return future_probs.argmax(), theater_risk
```

## Összegzés a Kereskedési Szabályra (MQL5 EA felé):
A ZeroMQ híd nem csak `0`, `1`, vagy `2` integer értéket küld majd az Expert Advisornak.
Küldeni fogja a `(Jelen_Allapot, Jovo_Riziko_Theater)` Tuple-t (pl. `1|0.65` -> Jelenleg Tiszta, de 65% esély a manipulációra).
Az MT5 így egy kőkemény Prediktív Védelmet kap a bróker algoritmusai ellen.
