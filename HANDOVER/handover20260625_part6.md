# HANDOVER JELENTÉS - 2026.06.25. (Phase 6: On-Demand Tanácsadó Rendszer)

## Vezetői Összefoglaló
A 24/7 futó autotrading robot paradigma helyett sikeresen leprogramoztuk az "On-Demand Advisor" (Döntéstámogató Tanácsadó) rendszert. A kifejlesztett architektúra (`advisor_inference.py`) egyetlen "Single-Shot Inference" hívással képes valós időben elemezni a jelenlegi piacot (anélkül, hogy hetek óta futnia kellett volna), és egy azonnali, százalékos valószínűség-alapú kereskedési tanácsot generálni.

## Az Új "Ensemble" Tanácsadó Rendszer Működése:
1. **Hidegindítás (Cold Start):**
   Amikor a felhasználó megnyitja a chartot és elindítja a szimulátort, az letölti a legutolsó történelmi adatablakot.
2. **Környezet Felismerés (HMM):**
   A rendszer azonosítja, hogy az éppen aktuális percben a piac Milyen Fázisban (Regime) tartózkodik (Trendelő vs Oldalazó).
3. **Dinamikus Modellválasztás:**
   - Ha a piac *Oldalazó*, betölti a kis célra (0.2x ATR) optimalizált, defenzív XGBoost modellt.
   - Ha a piac *Trendelő*, betölti a nagy célra (1.0x ATR) optimalizált, agresszív XGBoost modellt.
4. **Biztonsági Küszöb (Threshold):**
   A döntés nem bináris. A rendszer egy Valószínűségi Eloszlást (`predict_proba`) számol. A végső tanács ("ERŐS VÉTEL" vagy "ERŐS ELADÁS") csak akkor születik meg, ha a modell egy bizonyos szint feletti (Trendben >60%, Oldalazásban >50%) magabiztossággal jósolja a megfelelő elmozdulást. Ha nem, javasolja a "KIVÁRÁS"-t.

## Példa egy Élő Jelentésre:
```
📈 JULES ON-DEMAND ADVISOR: JELENIDEJŰ PIACI ELEMZÉS
Időpont: 2026.06.12 23:56:00
Árfolyam: 4218.50
ATR (Volatilitás): 1.42 USD
PIACI REZSIM (HMM): OLDALAZÓ (Zajos, Range-Bound)
🤖 Betöltött ML Engine: MIKRO-TREND SIDEWAYS MODELL (Cél: 0.2x ATR)
🔮 XGBOOST VALÓSZÍNŰSÉGI ELOSZLÁS:
   - HOLD: 15.9% | BUY: 53.9% | SELL: 30.3%
🎯 VÉGSŐ TANÁCS (ADVISOR JAVASLAT): >>> ERŐS VÉTEL (BUY) JELZÉS! <<<
```

## A Következő Session Terve
A szimulátor tökéletesen bizonyította a koncepciót. A következő nagy feladat ennek a Python scriptnek a szerves összekötése az **MT5 Vaku 3.0 Dashboarddal**. A felhasználónak az MT5 Charton kell látnia ezt a jelentést egy gombnyomásra (akár ZMQ fájl átadással, akár REST API hívással, akár ONNX modellen keresztül).
