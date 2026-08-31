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
class BasicHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules HUD - v1.00 (Live Tick Only)")
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
        self.bid_line = self.chart.horizontal_line(0.0, color='royalblue', width=1, style='solid', text='Bid')
        self.ask_line = self.chart.horizontal_line(0.0, color='firebrick', width=1, style='solid', text='Ask')
        self.last_price_line = self.chart.horizontal_line(0.0, color='gray', width=1, style='dashed', text='Last')


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
                self.is_initialized = True
            else:
                # A további tickeknél az .update() írja felül vagy fűzi hozzá a gyertyát
                self.chart.update(pd.Series(candle_data))

                bid = data.get('bid', price)
                ask = data.get('ask', price)
                self.bid_line.update(bid)
                self.ask_line.update(ask)
                self.last_price_line.update(price)

        except Exception as e:
            print(f"[Chart Error] {e}", flush=True)


if __name__ == '__main__':
    app = QApplication(sys.argv)

    hud = BasicHUD()
    hud.show()

    sys.exit(app.exec_())
