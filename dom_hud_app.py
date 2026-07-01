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
        if cmd == "TICK":
            if len(parts) < 15:
                print(f"[DOM-BRIDGE] HIBÁS TICK PAYLOAD HOSSZ ({len(parts)} részes): {message}")
                return
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
    <title>Professional DOM Ladder HUD</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0b0e14; color: #d1d4dc; margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; }
        h1 { color: #e2e8f0; font-size: 24px; font-weight: 300; letter-spacing: 2px;}

        #dom-container {
            width: 700px;
            background-color: #131722;
            border: 1px solid #2B2B43;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            border-radius: 4px;
            box-shadow: 0 10px 20px rgba(0,0,0,0.5);
        }

        .dom-header {
            display: flex;
            padding: 10px 0;
            background: #1e222d;
            font-size: 13px;
            font-weight: 600;
            border-bottom: 1px solid #2B2B43;
            color: #787b86;
        }
        .dom-header div { flex: 1; text-align: center; letter-spacing: 1px;}
        .dom-header .price-col { flex: 0 0 120px; } /* Fix szélesség a középső árnak */

        #dom-body {
            display: flex;
            flex-direction: column;
            font-size: 15px;
            font-weight: bold;
            font-family: 'Courier New', Courier, monospace;
            background-color: #0b0e14;
        }

        .dom-row {
            display: flex;
            width: 100%;
            height: 36px;
            line-height: 36px;
            position: relative;
            border-bottom: 1px solid #141822;
        }
        .dom-row:hover { background-color: #1a202c; }

        .col-bid-vol { flex: 1; position: relative; text-align: right; padding-right: 20px; color: #00e676; z-index: 2; font-size: 16px;}
        .col-price {
            flex: 0 0 140px;
            text-align: center;
            background-color: #131722;
            border-left: 2px solid #2B2B43;
            border-right: 2px solid #2B2B43;
            z-index: 3;
            color: #ffffff;
            letter-spacing: 2px;
            font-size: 16px;
        }
        .col-ask-vol { flex: 1; position: relative; text-align: left; padding-left: 20px; color: #ff5252; z-index: 2; font-size: 16px;}

        /* Modern Flowsurface/Orderbook Style Depth Bars */
        .bar-bid {
            position: absolute;
            right: 0;
            top: 4px;
            height: 28px;
            background: linear-gradient(90deg, rgba(0,230,118,0.1) 0%, rgba(0,230,118,0.4) 100%);
            z-index: 1;
            transition: width 0.15s cubic-bezier(0.4, 0, 0.2, 1);
            border-right: none;
        }
        .bar-ask {
            position: absolute;
            left: 0;
            top: 4px;
            height: 28px;
            background: linear-gradient(270deg, rgba(255,82,82,0.1) 0%, rgba(255,82,82,0.4) 100%);
            z-index: 1;
            transition: width 0.15s cubic-bezier(0.4, 0, 0.2, 1);
            border-left: none;
        }

        .spread-row {
            background-color: #1e222d;
            color: #787b86;
            text-align: center;
            font-size: 12px;
            font-weight: normal;
            border-bottom: 1px solid #2B2B43;
            border-top: 1px solid #2B2B43;
            height: 24px;
            line-height: 24px;
            letter-spacing: 1px;
            display: flex;
            justify-content: center;
        }
        .spread-row span {
            background-color: #2a2e39;
            padding: 0 15px;
            border-radius: 12px;
            color: #d1d4dc;
        }
    </style>
</head>
<body>
    <h1>ORDER BOOK PROFILE</h1>
    <div id="dom-container">
        <div class="dom-header">
            <div>BID VOLUME</div>
            <div class="price-col">PRICE</div>
            <div>ASK VOLUME</div>
        </div>
        <div id="dom-body">
            <!-- Data will be injected here via JS -->
        </div>
    </div>

    <script>
        let MAX_VOLUME = 1;

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

            let currentMax = 0;
            data.asks.forEach(a => { if (a.volume > currentMax) currentMax = a.volume; });
            data.bids.forEach(b => { if (b.volume > currentMax) currentMax = b.volume; });
            if (currentMax > 0) MAX_VOLUME = currentMax;

            // Asks (Piros oszlopok a jobboldalon, balra fésülve az ár széléről)
            const asksReversed = [...data.asks].reverse();

            asksReversed.forEach(ask => {
                const width = Math.min((ask.volume / MAX_VOLUME) * 100, 100);
                body.innerHTML += `
                    <div class="dom-row">
                        <div class="col-bid-vol"></div>
                        <div class="col-price">${ask.price.toFixed(5)}</div>
                        <div class="col-ask-vol">
                            ${ask.volume}
                            <div class="bar-ask" style="width: ${width}%;"></div>
                        </div>
                    </div>
                `;
            });

            // Spread Display
            let spreadDisplay = "SPREAD N/A";
            if (data.asks.length > 0 && data.bids.length > 0) {
                // Determine best Ask and Bid (since array could be unsorted, we take the closest ones based on the index order given by the Python server)
                // In Python we add ap2 then ap1 (ap1 is closer to mid), so asks is [ap2, ap1]. Reversed it is [ap1, ap2]. Best ask is index 0.
                const bestAsk = asksReversed[0].price;
                // In Python we add bp1 then bp2. Best bid is index 0.
                const bestBid = data.bids[0].price;
                const spread = Math.abs(bestAsk - bestBid);
                spreadDisplay = `SPREAD: ${spread.toFixed(5)}`;
            }

            body.innerHTML += `
                <div class="spread-row">
                    <span>${spreadDisplay}</span>
                </div>
            `;

            // Bids (Zöld oszlopok a baloldalon, jobbra fésülve az ár széléig)
            data.bids.forEach(bid => {
                const width = Math.min((bid.volume / MAX_VOLUME) * 100, 100);
                body.innerHTML += `
                    <div class="dom-row">
                        <div class="col-bid-vol">
                            ${bid.volume}
                            <div class="bar-bid" style="width: ${width}%;"></div>
                        </div>
                        <div class="col-price">${bid.price.toFixed(5)}</div>
                        <div class="col-ask-vol"></div>
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
    bridge = MT5DOMBridge(host='0.0.0.0', port=5555) # Szinkronizálva az MT5 InpBridgePort alapértelmezett értékével (5555)
    bridge.start()

    # Start Web HUD
    print("[FLASK] Starting Web DOM HUD on http://127.0.0.1:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
