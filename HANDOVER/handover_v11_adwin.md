# HANDOVER REPORT: VAKU 3.0 ADWIN ADAPTIVE MOTOR (V11)

## Készült: 2026-06-16

A HMM motor önszabályozása egy magasabb szintre lépett (V11), elvetve a korábbi manuális "Tick-Ablak" (micro/med/macro) beállításokat. Az igazi adaptáció kulcsa a beépített `FastADWIN` (Adaptive Windowing) algoritmus.

### Kiemelt fejlesztések (V11):
1. **O(1) ADWIN Drift Detektor:**
   - Készült egy `fast_adwin.py` modul tiszta Python/Numpy alapon, amely list-slicing helyett iteratív szummákkal és varianciával számol (Babcock formula), így extrém gyors.
   - A modul folyamatosan (O(1)) figyeli az utolsó N tick hozamát, és amint statisztikailag szignifikáns "Driftet" (irány- vagy karakterváltást) érzékel, automatikusan csonkolja az emlékezetét (a régi adatokat levágja).
2. **Automata Ablakméret a HMM-nek:**
   - A HMM motor `macro_window_ticks` bemenete többé nem egy fix 1000-es szám. A `hmmlearn` minden 100. tickben kizárólag a `FastADWIN` által meghagyott dinamikus ablakméreten futtatja le a betanítást.
   - Ha a piac gyors (kitörés), az ablak pillanatok alatt összeszűkül 50-100 tickre (reaktív).
   - Ha a piac lassú (oldalazás), az ablak kitágul több ezer tickre (zajszűrt).
3. **Volatilitás és Hysteresis integráció (Finomítás):**
   - A volatilitás mérés (és ezáltal az érzékenység dinamikus növelése - `vol_mult`) továbbra is aktív.
   - A be- és kikapcsolási küszöbök (Hysteresis) továbbra is felelősek a "villogás" (flickering) fizikai megszüntetéséért.
4. **V11 Online Hibrid (ZMQ):**
   - Az ADWIN motor rákötve az élő `MT5SocketBridge` ZMQ hálózatra a `vaku3_online_hybrid_v11.py` fájlon keresztül.
