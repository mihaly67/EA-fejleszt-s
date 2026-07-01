import sys
import time
import socket
import threading
from flask import Flask, render_template_string, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# In-memory adatbázis a HUD-hoz (legfrissebb tickek, szintek és árak)
LATEST_DOM_DATA = {
    'time': 0,
    'price': 0.0,
    'bids': [], # [{price: float, volume: int}]
    'asks': []
}

# --- ZMQ / RAW TCP BRIDGE A VAKU3 ALAPJÁN ---
class MT5DOMBridge(threading.Thread):
    def __init__(self, host='127.0.0.1', port=5555):
        super().__init__()
        self.host = host
        self.port = port
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        self.client_socket = None

    def run(self):
        print(f"[DOM-BRIDGE] DOM HUD Bridge indul ezen: {self.host}:{self.port}")
        while self.running:
            try:
                self.server_socket.settimeout(2.0)
                try:
                    client, addr = self.server_socket.accept()
                    self.client_socket = client
                    self.client_socket.settimeout(None)
                    print(f"[DOM-BRIDGE] EA Csatlakozott: {addr}")
                except socket.timeout:
                    continue

                buffer = ""
                while self.running and self.client_socket:
                    try:
                        data = self.client_socket.recv(1048576).decode('utf-8')
                        if not data:
                            print("[DOM-BRIDGE] EA Kapcsolat megszakadt.")
                            break
                        buffer += data
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            self.process_message(line.strip())
                    except Exception as e:
                        print(f"[DOM-BRIDGE] Hiba a hálózatban: {e}")
                        break
            except Exception as e:
                print(f"[DOM-BRIDGE] Fő ciklus hiba: {e}")

    def process_message(self, message):
        global LATEST_DOM_DATA
        if not message: return
        parts = message.split('|')
        cmd = parts[0]

        # Format: TICK|time|bid|ask|type|price|profit|av1|av2|bv1|bv2|ap1|ap2|bp1|bp2
        if cmd == "TICK" and len(parts) >= 15:
            try:
                time_msc = float(parts[1])
                bid = float(parts[2])
                ask = float(parts[3])

                av1 = int(parts[7])
                av2 = int(parts[8])
                bv1 = int(parts[9])
                bv2 = int(parts[10])
                ap1 = float(parts[11])
                ap2 = float(parts[12])
                bp1 = float(parts[13])
                bp2 = float(parts[14])

                LATEST_DOM_DATA['time'] = time_msc
                LATEST_DOM_DATA['price'] = (bid + ask) / 2.0

                # Mivel Level 1-es (esetleg Level 2-es demo), csak azt jelenítjük meg ami bejön.
                # Az OrderBook felépítése a Vaku3-ból örökölve
                LATEST_DOM_DATA['asks'] = []
                LATEST_DOM_DATA['bids'] = []

                if av2 > 0 and ap2 > 0:
                    LATEST_DOM_DATA['asks'].append({'price': ap2, 'volume': av2})
                if av1 > 0 and ap1 > 0:
                    LATEST_DOM_DATA['asks'].append({'price': ap1, 'volume': av1})

                if bv1 > 0 and bp1 > 0:
                    LATEST_DOM_DATA['bids'].append({'price': bp1, 'volume': bv1})
                if bv2 > 0 and bp2 > 0:
                    LATEST_DOM_DATA['bids'].append({'price': bp2, 'volume': bv2})

            except ValueError:
                pass


HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Level 2 DOM Heatmap HUD</title>
    <style>
        body { font-family: 'Courier New', Courier, monospace; background-color: #131722; color: white; margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; }
        h1 { color: #fcd535; }
        #dom-container { width: 400px; background-color: #1e222d; border: 2px solid #4a5056; display: flex; flex-direction: column; overflow: hidden; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.5); }
        .dom-header { display: flex; justify-content: space-between; padding: 10px; background: #2b3139; font-size: 14px; font-weight: bold; border-bottom: 2px solid #4a5056;}
        .dom-header div { width: 33%; text-align: center; }
        #dom-body { display: flex; flex-direction: column; font-size: 16px; font-weight: bold; }
        .dom-row { display: flex; width: 100%; height: 35px; line-height: 35px; border-bottom: 1px solid #2a2e39; position: relative;}
        .dom-row:hover { background-color: #3b4249; }
        .dom-bid, .dom-ask { width: 33%; position: relative; text-align: right; padding-right: 15px; z-index: 2;}
        .dom-price { width: 34%; text-align: center; background-color: #2a2e39; border-left: 1px solid #1e222d; border-right: 1px solid #1e222d; z-index: 2; color: #fff;}

        .bar-bg { position: absolute; top: 0; height: 100%; z-index: 1; opacity: 0.4; transition: width 0.1s ease-in-out; }
        .bar-bg.ask { right: 0; background-color: #ef5350; }
        .bar-bg.bid { left: 0; background-color: #26a69a; }

        .row-ask .dom-ask { color: #ef5350; }
        .row-bid .dom-bid { color: #26a69a; }
        .current-price-row { background-color: #fcd535; color: black !important; text-align: center; font-size: 18px; line-height: 40px; font-weight: 900;}
    </style>
</head>
<body>
    <h1>DOM HUD Monitor</h1>
    <div id="dom-container">
        <div class="dom-header">
            <div>BID VOL</div>
            <div>PRICE</div>
            <div>ASK VOL</div>
        </div>
        <div id="dom-body">
            <!-- Data will be injected here via JS -->
        </div>
    </div>

    <script>
        const MAX_VOLUME = 500; // skálázás bázisa

        async function fetchDOM() {
            try {
                const response = await fetch('/api/dom');
                const data = await response.json();
                renderDOM(data);
            } catch (error) {
                console.error('Error fetching DOM data:', error);
            }
        }

        function renderDOM(data) {
            const body = document.getElementById('dom-body');
            body.innerHTML = '';

            // Asks (fordított sorrend, legmagasabb ár legfelül)
            // A data.asks csökkenő, tehát index 0 a legjobb ask (legalacsonyabb ár)
            // Hogy a felületen a magasabb ár legyen felül, megfordítjuk
            const asksReversed = [...data.asks].reverse();

            asksReversed.forEach(ask => {
                const width = Math.min((ask.volume / MAX_VOLUME) * 100, 100);
                body.innerHTML += `
                    <div class="dom-row row-ask">
                        <div class="dom-bid"></div>
                        <div class="dom-price">${ask.price.toFixed(5)}</div>
                        <div class="dom-ask">${ask.volume}</div>
                        <div class="bar-bg ask" style="width: ${width}%;"></div>
                    </div>
                `;
            });

            // Mid price
            body.innerHTML += `
                <div class="current-price-row">
                    MID: ${data.price.toFixed(5)}
                </div>
            `;

            // Bids (legjobb bid felül)
            data.bids.forEach(bid => {
                const width = Math.min((bid.volume / MAX_VOLUME) * 100, 100);
                body.innerHTML += `
                    <div class="dom-row row-bid">
                        <div class="dom-bid">${bid.volume}</div>
                        <div class="dom-price">${bid.price.toFixed(5)}</div>
                        <div class="dom-ask"></div>
                        <div class="bar-bg bid" style="width: ${width}%;"></div>
                    </div>
                `;
            });
        }

        setInterval(fetchDOM, 250); // 4 FPS frissítés
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/dom')
def api_dom():
    return jsonify(LATEST_DOM_DATA)

if __name__ == '__main__':
    # Start MT5 ZMQ Socket Listener
    bridge = MT5DOMBridge(host='127.0.0.1', port=5556) # Használjunk 5556-ot, ha 5555 a Vakué
    bridge.start()

    # Start Web HUD
    print("[FLASK] Starting Web DOM HUD on http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
