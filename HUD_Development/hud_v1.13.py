import sys
import json
import time
import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QLabel
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from lightweight_charts.widgets import QtChart
import zmq

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

class PositionManager:
    def __init__(self, chart):
        self.chart = chart
        self.live_lines = []
        self.pending_lines = []
        self.max_lines = 10

        for _ in range(self.max_lines):
            line = self.chart.horizontal_line(0.0001, color='forestgreen', width=2, style='solid', text='E', axis_label_visible=True)
            self.live_lines.append(line)
        for _ in range(self.max_lines):
            line = self.chart.horizontal_line(0.0001, color='forestgreen', width=2, style='dashed', text='P', axis_label_visible=True)
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

        while live_idx < self.max_lines:
            self.live_lines[live_idx].update(0.0001)
            live_idx += 1
        while pending_idx < self.max_lines:
            self.pending_lines[pending_idx].update(0.0001)
            pending_idx += 1

class BasicHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules HUD - v1.13 (Static Subchart + Noise + Thresholds)")
        self.resize(1100, 700)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)

        info_layout = QHBoxLayout()
        self.status_label = QLabel("Waiting for live data...")
        self.status_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
        self.status_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        info_layout.addWidget(self.status_label)
        main_layout.addLayout(info_layout)

        self.chart = QtChart(inner_width=1, inner_height=0.7)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.time_scale(visible=True, right_offset=0)

        self.chart.run_script(f"{self.chart.id}.chart.timeScale().applyOptions({{ rightOffset: 15 }})")
        self.chart.run_script(f"{self.chart.id}.chart.priceScale('right').applyOptions({{ minimumWidth: 80 }})")
        self.chart.get_webview().setStyleSheet("background-color: #121212;")

        # --- Predikciós Subchart (30%) ---
        self.subchart = self.chart.create_subchart(width=1, height=0.3, sync=True)
        self.subchart.layout(background_color='#121212', text_color='#ffffff')
        self.subchart.grid(vert_enabled=False, horz_enabled=False)
        self.subchart.time_scale(visible=True, right_offset=0)
        self.subchart.run_script(f"{self.subchart.id}.chart.timeScale().applyOptions({{ rightOffset: 15 }})")
        self.subchart.run_script(f"{self.subchart.id}.chart.priceScale('right').applyOptions({{ minimumWidth: 80 }})")

        # Statikus skála margin növelése a levágott 1.0 cimke miatt (top: 0.2)
        js_code = f"""
        {self.subchart.id}.chart.priceScale('right').applyOptions({{
            autoScale: false,
            scaleMargins: {{ top: 0.2, bottom: 0.1 }},
        }});
        """
        self.subchart.run_script(js_code)

        # Dinamikus görbék
        self.long_line = self.subchart.create_line(color='rgba(0, 255, 0, 1)', width=2)
        self.short_line = self.subchart.create_line(color='rgba(255, 0, 0, 1)', width=2)
        self.noise_line = self.subchart.create_line(color='rgba(169, 169, 169, 1)', width=2) # Szürke zajszint görbe

        # Horgonyok (Anchor) a 0.0 és 1.0 értékhez, hogy rögzítsék a Y skálát
        self.anchor_top = self.subchart.horizontal_line(1.0, color='rgba(255, 255, 255, 0.1)', width=1, style='dashed', text='1.0', axis_label_visible=True)
        self.anchor_bottom = self.subchart.horizontal_line(0.0, color='rgba(255, 255, 255, 0.1)', width=1, style='dashed', text='0.0', axis_label_visible=True)

        # Optuna Küszöbök
        self.thresh_long = self.subchart.horizontal_line(0.55, color='rgba(0, 255, 0, 0.4)', width=1, style='dotted', text='Opt-L (0.55)', axis_label_visible=True)
        self.thresh_short = self.subchart.horizontal_line(0.45, color='rgba(255, 0, 0, 0.4)', width=1, style='dotted', text='Opt-S (0.45)', axis_label_visible=True)
        self.thresh_noise = self.subchart.horizontal_line(0.35, color='rgba(169, 169, 169, 0.4)', width=1, style='dotted', text='Opt-N (0.35)', axis_label_visible=True)


        # --- Dinamikus vonalak (Price Lines) ---
        self.position_manager = PositionManager(self.chart)
        self.bid_line = self.chart.horizontal_line(0.0, color='royalblue', width=1, style='solid', text='Bid')
        self.ask_line = self.chart.horizontal_line(0.0, color='firebrick', width=1, style='solid', text='Ask')
        self.last_price_line = self.chart.horizontal_line(0.0, color='gray', width=1, style='dashed', text='Last')

        # --- Pivot Vonalak ---
        self.res_micro = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='dotted', text='R-M', axis_label_visible=True)
        self.sup_micro = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='dotted', text='S-M', axis_label_visible=True)
        self.res_sec = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='dashed', text='R-S', axis_label_visible=True)
        self.sup_sec = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='dashed', text='S-S', axis_label_visible=True)
        self.res_ter = self.chart.horizontal_line(0.0001, color='rgba(255, 0, 0, 0.5)', width=1, style='solid', text='R-T', axis_label_visible=True)
        self.sup_ter = self.chart.horizontal_line(0.0001, color='rgba(0, 255, 0, 0.5)', width=1, style='solid', text='S-T', axis_label_visible=True)

        main_layout.addWidget(self.chart.get_webview(), stretch=1)

        self.is_initialized = False
        self.current_minute_ts = None
        self.current_open = 0.0
        self.current_high = 0.0
        self.current_low = float('inf')

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.zmq_thread.start()

    def on_data_received(self, data):
        raw_ts = pd.to_datetime(data['timestamp'], unit='s')
        minute_ts_dt = raw_ts.floor('min')
        ts_str = minute_ts_dt.strftime('%Y-%m-%d %H:%M:%S')

        price = data['close']

        if self.current_minute_ts != ts_str:
            self.current_minute_ts = ts_str
            self.current_open = data.get('open', price)
            self.current_high = data.get('high', price)
            self.current_low = data.get('low', price)
        else:
            if price > self.current_high: self.current_high = price
            if price < self.current_low: self.current_low = price

        self.status_label.setText(f"Live Price: {price} | Time: {ts_str} (Prediction curves will appear after the second minute)")

        candle_data = {
            'time': ts_str,
            'open': self.current_open,
            'high': self.current_high,
            'low': self.current_low,
            'close': price
        }

        p_long = data.get('p_long', 0.0)
        p_short = data.get('p_short', 0.0)
        p_noise = data.get('p_noise', 0.0)

        try:
            if not self.is_initialized:
                initial_df = pd.DataFrame([candle_data])
                self.chart.set(initial_df)

                self.long_line.set(pd.DataFrame([{'time': ts_str, 'value': p_long}]))
                self.short_line.set(pd.DataFrame([{'time': ts_str, 'value': p_short}]))
                self.noise_line.set(pd.DataFrame([{'time': ts_str, 'value': p_noise}]))

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
                self.chart.update(pd.Series(candle_data))

                self.long_line.update(pd.Series({'time': ts_str, 'value': p_long}))
                self.short_line.update(pd.Series({'time': ts_str, 'value': p_short}))
                self.noise_line.update(pd.Series({'time': ts_str, 'value': p_noise}))

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
