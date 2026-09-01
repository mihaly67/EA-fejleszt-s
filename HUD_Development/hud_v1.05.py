import sys
import json
import zmq
import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QLabel, QHBoxLayout
from PyQt5.QtCore import QThread, pyqtSignal, Qt
from lightweight_charts.widgets import QtChart

# ==============================================================================
# ZMQ HÁLÓZATI SZÁL (Adatfogadó)
# ==============================================================================
class ZMQReceiverThread(QThread):
    data_received = pyqtSignal(dict)

    def run(self):
        context = zmq.Context()
        subscriber = context.socket(zmq.SUB)
        subscriber.connect("tcp://127.0.0.1:5557")
        subscriber.setsockopt_string(zmq.SUBSCRIBE, "HUD ")

        print("[ZMQ] Csatlakoztunk az 5557-es PUB/SUB portra, várom a tickeket...", flush=True)

        while True:
            try:
                message = subscriber.recv_string()
                if message.startswith("HUD "):
                    json_data = message[4:]
                    data = json.loads(json_data)
                    self.data_received.emit(data)
            except Exception as e:
                print(f"[ZMQ Hiba] {e}", flush=True)

# ==============================================================================
# FŐ ABLAK ÉS CHART (HUD V1.00 - Tiszta lap)
# ==============================================================================

class PositionManager:
    def __init__(self, chart):
        self.chart = chart
        self.live_lines = []
        self.pending_lines = []
        self.max_lines = 10

        for _ in range(self.max_lines):
            line = self.chart.horizontal_line(0.0001, color='forestgreen', width=2, style='solid', text='Entry', axis_label_visible=False)
            self.live_lines.append(line)
        for _ in range(self.max_lines):
            line = self.chart.horizontal_line(0.0001, color='forestgreen', width=2, style='dashed', text='Pending', axis_label_visible=False)
            self.pending_lines.append(line)

    def update_positions(self, pos_types, pos_prices):
        num_positions = len(pos_types) if pos_types and pos_prices and len(pos_types) == len(pos_prices) else 0

        live_idx = 0
        pending_idx = 0

        for i in range(num_positions):
            p_type = pos_types[i]
            p_price = pos_prices[i]
            if p_type == 0 or p_price == 0.0:
                continue

            if p_type in [1, -1]: # Live
                if live_idx < self.max_lines:
                    self.live_lines[live_idx].update(p_price)
                    live_idx += 1
            elif p_type in [2, 3]: # Pending
                if pending_idx < self.max_lines:
                    self.pending_lines[pending_idx].update(p_price)
                    pending_idx += 1

        # A maradék elrejtése
        while live_idx < self.max_lines:
            self.live_lines[live_idx].update(0.0001)
            live_idx += 1
        while pending_idx < self.max_lines:
            self.pending_lines[pending_idx].update(0.0001)
            pending_idx += 1

class BasicHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules HUD - v1.05 (Live Tick Only)")
        self.resize(1100, 700)

        # --- UI Elrendezés ---
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)

        # Felső információs sáv
        info_layout = QHBoxLayout()
        self.status_label = QLabel("Waiting for live data...")
        self.status_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
        self.status_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        info_layout.addWidget(self.status_label)
        main_layout.addLayout(info_layout)

        # --- Chart Inicializálása ---
        self.chart = QtChart(inner_width=1, inner_height=1)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.time_scale(visible=True, right_offset=0)
        # 15% right offset in JS
        self.chart.run_script(f"{self.chart.id}.chart.timeScale().applyOptions({{ rightOffset: 15 }})")
        self.chart.get_webview().setStyleSheet("background-color: #121212;")

        # --- Dinamikus vonalak (Price Lines) ---
        self.position_manager = PositionManager(self.chart)
        self.bid_line = self.chart.horizontal_line(0.0, color='royalblue', width=1, style='solid', text='Bid')
        self.ask_line = self.chart.horizontal_line(0.0, color='firebrick', width=1, style='solid', text='Ask')
        self.last_price_line = self.chart.horizontal_line(0.0, color='gray', width=1, style='dashed', text='Last')

        # --- Pivot Vonalak ---
        self.res_micro = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='dotted', text='Res Micro', axis_label_visible=False)
        self.sup_micro = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='dotted', text='Sup Micro', axis_label_visible=False)
        self.res_sec = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='dashed', text='Res Sec', axis_label_visible=False)
        self.sup_sec = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='dashed', text='Sup Sec', axis_label_visible=False)
        self.res_ter = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='solid', text='Res Ter', axis_label_visible=False)
        self.sup_ter = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='solid', text='Sup Ter', axis_label_visible=False)


        main_layout.addWidget(self.chart.get_webview(), stretch=1)

        # --- Állapotváltozók az aggregációhoz ---
        self.is_initialized = False
        self.current_minute_ts = None
        self.current_open = 0.0
        self.current_high = 0.0
        self.current_low = float('inf')

        # Indítjuk a hálózati szálat
        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.zmq_thread.start()

    def on_data_received(self, data):
        # 1 perces (M1) aggregáció: A bejövő tick UNIX másodpercét lekererekítjük percre
        raw_ts = pd.to_datetime(data['timestamp'], unit='s')
        minute_ts_dt = raw_ts.floor('min')
        ts_str = minute_ts_dt.strftime('%Y-%m-%d %H:%M:%S')

        price = data['close']

        # Aggregációs logika
        if self.current_minute_ts != ts_str:
            # Új perc indult
            self.current_minute_ts = ts_str
            self.current_open = data.get('open', price)
            self.current_high = data.get('high', price)
            self.current_low = data.get('low', price)
        else:
            # Ugyanabban a percben vagyunk, frissítjük a maximumokat/minimumokat
            if price > self.current_high: self.current_high = price
            if price < self.current_low: self.current_low = price

        # UI frissítés
        self.status_label.setText(f"Live Price: {price} | Time: {ts_str}")

        # Adatszerkezet a chart frissítéséhez (kizárólag tiszta dictionary a JS hibák elkerülése végett)
        candle_data = {
            'time': ts_str,
            'open': self.current_open,
            'high': self.current_high,
            'low': self.current_low,
            'close': price
        }

        try:
            if not self.is_initialized:
                # Az legelső beérkező adatnál .set() kell (dataframe listában) az inicializáláshoz!
                initial_df = pd.DataFrame([candle_data])
                self.chart.set(initial_df)

                bid = data.get('bid', price)
                ask = data.get('ask', price)
                self.bid_line.update(bid)
                self.ask_line.update(ask)
                self.last_price_line.update(price)

                self.res_micro.update(data.get('res_micro', 0.0001))
                self.sup_micro.update(data.get('sup_micro', 0.0001))
                self.res_sec.update(data.get('res_sec', 0.0001))
                self.sup_sec.update(data.get('sup_sec', 0.0001))
                self.res_ter.update(data.get('res_ter', 0.0001))
                self.sup_ter.update(data.get('sup_ter', 0.0001))

                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])
                self.position_manager.update_positions(pos_types, pos_prices)
                self.is_initialized = True
            else:
                # A további tickeknél az .update() írja felül vagy fűzi hozzá a gyertyát
                self.chart.update(pd.Series(candle_data))

                bid = data.get('bid', price)
                ask = data.get('ask', price)
                self.bid_line.update(bid)
                self.ask_line.update(ask)
                self.last_price_line.update(price)

                self.res_micro.update(data.get('res_micro', 0.0001))
                self.sup_micro.update(data.get('sup_micro', 0.0001))
                self.res_sec.update(data.get('res_sec', 0.0001))
                self.sup_sec.update(data.get('sup_sec', 0.0001))
                self.res_ter.update(data.get('res_ter', 0.0001))
                self.sup_ter.update(data.get('sup_ter', 0.0001))

                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])
                self.position_manager.update_positions(pos_types, pos_prices)

        except Exception as e:
            print(f"[Chart Error] {e}", flush=True)


if __name__ == '__main__':
    app = QApplication(sys.argv)

    hud = BasicHUD()
    hud.show()

    sys.exit(app.exec_())
