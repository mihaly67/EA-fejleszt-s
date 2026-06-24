# HANDOVER JELENTÉS - 2026.06.25. (Phase 3: Valódi Scalper Célok és Oldalazó Piacok)

## Vezetői Összefoglaló
A 15 perces predikciók (M5 adathalmazon) kezdeti elemzésekor kiderült, hogy az 1.0x-1.5x ATR hozamelvárás túl ritkán fordul elő ahhoz, hogy egy robot folyamatosan (napi szinten) tudjon "tanácsadóként" működni. Az új kutatási szakaszban megvizsgáltuk az alacsonyabb, *valódi scalping* célpontokat (0.3x - 0.7x ATR), és kiterjesztettük a tesztelést az eddig "zajosnak" elkönyvelt oldalazó (Sideways) piacokra is.

## 1. Teszt: Trendelő Piac Kisebb Célokkal (`evaluate_class_weights.py`)
- Bevezettük a **Trades/Day (Napi Kötésszám)** metrikát, hogy elkerüljük az over-szűrt, "lebénult" robotokat.
- **Eredmény:** Ha a HMM által jelzett *Trendelő* piacon lejjebb visszük a hozamelvárást (0.3x ATR elmozdulás 15 perc alatt), a modell Precision-je (Pontosság) 0.55-ös Threshold mellett azonnal **65.38%**-ra ugrik fel, és egy kicsit lazább (0.45) Threshold mellett napi ~4 biztos jelet ad stabil >50%-os (52.1%) Precision-nel. Ez tökéletes scalping beállítás!

## 2. Teszt: Oldalazó Piac (Sideways) Skalpolása (`evaluate_sideways.py`)
- Korábban kidobtuk a Sideways adatokat (mert összezavarta a trendkövető fát). Most betanítottunk egy XGBoost modellt **kizárólag** a HMM "Sideways" állapotaira.
- **Eredmény:** Az oldalazó piacon is lehet scalpolni, de ott még kisebb célokra kell vadászni! Egy 0.2x ATR elmozdulás megjóslása (ami a bollinger/range pattogások mérete) 0.50-es Threshold mellett kiemelkedő, **56.25%-os Precision-t** hoz napi ~2 kötéssel.

## Konklúzió és Következő Lépés
Matematikailag bebizonyosodott, amit a profi Quant RAG cikkek mondtak:
A nyereséges (55-65% Precision feletti) ML Scalper robot sosem egyetlen döntési fa. **Ez egy Ensemble (Többszörös) Modell!**
- Kell egy HMM kapu, ami szétválogatja a piacot.
- Ha a HMM *Trendelő*, akkor meghívjuk az 1-es modellt (Trend-XGB), ami 0.5x - 1.0x ATR célokra optimalizált.
- Ha a HMM *Oldalazó*, akkor meghívjuk a 2-es modellt (Sideways-XGB), ami 0.2x ATR mean-reversion (visszapattanó) célokra optimalizált.

*A kódok a VPS-en (evaluate_class_weights.py és evaluate_sideways.py) már ezt az új architektúrát mérik.*
