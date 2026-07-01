import streamlit as st
import pandas as pd
import numpy as np
import time
import socket
import threading

# --- GLOBÁLIS ADATTÁR ---
LATEST_DOM_DATA = {
    'time': 0,
    'price': 0.0,
    'av1': 0, 'av2': 0, 'bv1': 0, 'bv2': 0,
    'ap1': 0.0, 'ap2': 0.0, 'bp1': 0.0, 'bp2': 0.0
}

# --- MT5 ZMQ/TCP BRIDGE (HÁTTÉRSZÁL) ---
class MT5DOMBridge(threading.Thread):
    def __init__(self, host='0.0.0.0', port=5555):
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
                LATEST_DOM_DATA['time'] = float(parts[1])
                LATEST_DOM_DATA['price'] = (float(parts[2]) + float(parts[3])) / 2.0

                LATEST_DOM_DATA['av1'] = int(parts[7])
                LATEST_DOM_DATA['av2'] = int(parts[8])
                LATEST_DOM_DATA['bv1'] = int(parts[9])
                LATEST_DOM_DATA['bv2'] = int(parts[10])

                LATEST_DOM_DATA['ap1'] = float(parts[11])
                LATEST_DOM_DATA['ap2'] = float(parts[12])
                LATEST_DOM_DATA['bp1'] = float(parts[13])
                LATEST_DOM_DATA['bp2'] = float(parts[14])
            except ValueError:
                pass


# Elindítjuk a háttérszálat (ha még nem fut)
if 'bridge_started' not in st.session_state:
    bridge = MT5DOMBridge(host='0.0.0.0', port=5555)
    bridge.start()
    st.session_state['bridge_started'] = True


# --- STREAMLIT UI ---
st.set_page_config(page_title="DOM Monitor Létra", layout="centered")
st.title("🧱 Tőzsdei DOM Monitor (Árlétra)")

refresh_rate = st.sidebar.slider("Frissítési gyakoriság (másodperc)", 0.2, 3.0, 0.5)
depth_level = st.sidebar.slider("Megjelenített árszintek száma", 5, 20, 10)

def get_dom_data(live_data, levels=10, tick_size=0.01):
    mid_price = live_data['price']
    if mid_price == 0.0:
        # Üres szimulált adat amíg nincs kapcsolat
        mid_rounded = 150.00
    else:
        mid_rounded = np.round(mid_price / tick_size) * tick_size

    prices = np.arange(mid_rounded + (levels * tick_size), mid_rounded - (levels * tick_size) - tick_size, -tick_size)
    prices = np.round(prices, 5) # 5 tizedesjegy a Forex/Crypto miatt

    bids = []
    asks = []

    # A legközelebbi Bid és Ask meghatározása a live_data alapján
    # Ha van élő adat, akkor a spreadet abból számoljuk, ha nincs, szimuláljuk
    if live_data['bp1'] > 0 and live_data['ap1'] > 0:
        best_bid = live_data['bp1']
        best_ask = live_data['ap1']
    else:
        best_bid = mid_rounded - tick_size
        best_ask = mid_rounded + tick_size

    for p in prices:
        # Ask Levels
        if abs(p - live_data['ap2']) < 0.00001 and live_data['av2'] > 0:
            bids.append(0)
            asks.append(live_data['av2'])
        elif abs(p - live_data['ap1']) < 0.00001 and live_data['av1'] > 0:
            bids.append(0)
            asks.append(live_data['av1'])

        # Bid Levels
        elif abs(p - live_data['bp1']) < 0.00001 and live_data['bv1'] > 0:
            bids.append(live_data['bv1'])
            asks.append(0)
        elif abs(p - live_data['bp2']) < 0.00001 and live_data['bv2'] > 0:
            bids.append(live_data['bv2'])
            asks.append(0)

        # Spread vagy üres szint
        else:
            bids.append(0)
            asks.append(0)

    df = pd.DataFrame({
        "Vétel (Bid)": bids,
        "Ár": prices,
        "Eladás (Ask)": asks
    })

    spread_value = best_ask - best_bid
    if spread_value < 0: spread_value = 0
    return df, best_bid, best_ask, spread_value


dom_placeholder = st.empty()

while True:
    # Élő adat lekérése a háttérszálból
    current_data = LATEST_DOM_DATA.copy()

    # 0.01 tick size szimuláció (ezt a te piacodhoz igazíthatod pl 0.00001 Forexre vagy 0.1 Goldra)
    # Beállítjuk egy átlagos tick size-ra
    tick_size_estimate = 0.01
    if current_data['bp1'] > 0 and current_data['ap1'] > 0:
        tick_size_estimate = current_data['ap1'] - current_data['bp1']
        if tick_size_estimate == 0: tick_size_estimate = 0.01
        # Ha a spread túl nagy, visszavesszük 1 tick-re
        if tick_size_estimate > 1.0: tick_size_estimate = 0.1

    df_dom, b_bid, b_ask, spread = get_dom_data(current_data, levels=depth_level, tick_size=tick_size_estimate)

    with dom_placeholder.container():
        kpi1, kpi2, kpi3 = st.columns(3)
        if b_bid > 0 and b_ask > 0:
            kpi1.metric("Legjobb Vétel", f"{b_bid:.5f}")
            kpi2.metric("Legjobb Eladás", f"{b_ask:.5f}")
            kpi3.metric("Spread", f"{spread:.5f}", delta=None, delta_color="off")
        else:
            kpi1.metric("Legjobb Vétel", "Várakozás MT5 adatra...")
            kpi2.metric("Legjobb Eladás", "-")
            kpi3.metric("Spread", "-")

        def style_dom(row):
            styles = [''] * len(row)
            price = row['Ár']

            # 1. Eladási oldal (Ask)
            if row['Eladás (Ask)'] > 0:
                styles[2] = 'background-color: rgba(255, 0, 0, 0.15); color: #ff4d4d; font-weight: bold; text-align: right;'
                styles[1] = 'color: #ff4d4d;'

            # 2. Vételi oldal (Bid)
            elif row['Vétel (Bid)'] > 0:
                styles[0] = 'background-color: rgba(0, 255, 0, 0.15); color: #00cc66; font-weight: bold; text-align: left;'
                styles[1] = 'color: #00cc66;'

            # 3. Spread sáv
            elif b_bid < price < b_ask:
                styles[0] = 'background-color: rgba(128, 128, 128, 0.05);'
                styles[1] = 'background-color: rgba(128, 128, 128, 0.1); color: #888888; font-weight: bold; text-align: center;'
                styles[2] = 'background-color: rgba(128, 128, 128, 0.05);'

            return styles

        df_display = df_dom.copy()
        df_display['Vétel (Bid)'] = df_display['Vétel (Bid)'].replace(0, '')
        df_display['Eladás (Ask)'] = df_display['Eladás (Ask)'].replace(0, '')

        # A stílus alkalmazása
        styled_df = df_display.style.apply(style_dom, axis=1)

        # Megjelenítés Streamlit natív dataframe segítségével
        st.dataframe(
            styled_df,
            use_container_width=True,
            hide_index=True,
            height=(depth_level * 2 + 1) * 36 + 40
        )

    time.sleep(refresh_rate)
