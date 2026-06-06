# 🌉 ZMQ BRIDGE BLUEPRINT: Vaku 3.0 ML Engine <-> MT5 Expert Advisor

## Cél:
A Python-ban futó HMM (Hidden Markov Model) állapotfelismerő motor és a MetaTrader 5 (MT5) Expert Advisor közötti valós idejű, mikromásodperces adatkapcsolat kiépítése.

## Architektúra:
**Protokoll:** ZeroMQ (ZMQ) TCP Sockets (Localhost port, pl. 5555)
**Minta:** REQ-REP (Request-Reply) szinkron kommunikáció

### Komponens 1: Az MT5 (Kliens - REQ)
Az MT5 minden ticknél (`OnTick()`) vagy trade szándék előtt küld egy mikroadat csomagot a Python szervernek.
- **Payload (MQL5 -> Python):** `TimeMsc|Ask|Bid` (Nyers szöveg vagy struct formátum).
- **Triggerek:**
  - *Heartbeat/Data feed:* Opcionálisan minden tick elküldhető a puffer frissítésére, ha az MT5 bírja (de ez blokkolhatja a szálat, így aszinkron PUB-SUB is szóba jöhet a nyers adatokra).
  - *Inference Request:* Csak akkor küldünk "Jósolj!" REQ kérést a Pythonnak, amikor az EA belépési szignált kapott, és engedélyre vár.

### Komponens 2: Vaku 3.0 Online Engine (Szerver - REP)
A Python szkript egy folyamatosan futó daemon (szerver).
- Fenntartja az O(1) komplexitású RingBuffer-eket.
- Ha megkapja az MT5 Inference kérését, kiszámolja a Z-score-okat és az HMM Predict-et (<0.2 ms alatt).
- **Válasz (Python -> MQL5):** Egy integer, ami a piaci állapotot jelöli:
  - `0`: Csendes Piac (Quiet)
  - `1`: Betonfal (Concrete - Tiszta Trend, Engedélyezett Belépés!)
  - `2`: Színház (Theater - Manipuláció, Tiltott Belépés / Fake Breakout)

## A Python Szerver (vaku3_zmq_server.py) Kódvázlata:
```python
import zmq
from utils import O1RingBuffer, LogERScaler
# ... HMM modell betöltése (pickle) ...

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://127.0.0.1:5555")

print("ZMQ Szerver Indítva...")
while True:
    message = socket.recv_string()
    # Puffer frissítése (message parsing)
    # HMM Inference futtatása
    state_id = model.predict(obs_scaled)[0]
    socket.send_string(str(state_id))
```

## Következő Lépés az Implementációhoz:
A felhasználónak gondoskodnia kell arról, hogy az `mql-zmq` könyvtár telepítve legyen az MT5 `Include` mappájában.
