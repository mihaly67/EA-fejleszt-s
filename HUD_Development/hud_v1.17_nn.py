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

        # Connect to NN Meta-Advisor for the verdict
        meta_sub = context.socket(zmq.SUB)
        meta_sub.connect("tcp://127.0.0.1:5558")
        meta_sub.setsockopt_string(zmq.SUBSCRIBE, "META ")

        poller = zmq.Poller()
        poller.register(subscriber, zmq.POLLIN)
        poller.register(meta_sub, zmq.POLLIN)

        print("[ZMQ] Csatlakoztunk az 5557-es (HUD) és 5558-as (META) PUB/SUB portokra...", flush=True)

        # Global dict to merge payloads before emitting
        self.merged_data = {}

        while True:
            try:
                socks = dict(poller.poll(10)) # 10ms timeout

                if subscriber in socks:
                    message = subscriber.recv_string()
                    if message.startswith("HUD "):
                        json_data = message[4:]
                        data = json.loads(json_data)
                        self.merged_data.update(data)
                        self.data_received.emit(self.merged_data)

                if meta_sub in socks:
                    meta_msg = meta_sub.recv_string()
                    if meta_msg.startswith("META "):
                        meta_json = meta_msg[5:]
                        meta_data = json.loads(meta_json)
                        self.merged_data.update(meta_data)
                        # We don't necessarily emit just on meta updates to avoid UI stutter,
                        # it will be appended to the next HUD tick via self.merged_data.
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
        self.setWindowTitle("Jules HUD - v1.16 (2-Line Info & Custom Colors)")
        self.resize(1100, 750)
        self.setStyleSheet("background-color: #000000;") # Teljes ablak fekete

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(5, 5, 5, 5)

        # --- Kétsoros Információs Sáv ---
        info_container = QWidget()
        info_container.setStyleSheet("background-color: #000000; border-bottom: 1px solid #333333;")
        info_layout = QVBoxLayout(info_container)
        info_layout.setContentsMargins(5, 5, 5, 5)
        info_layout.setSpacing(2)

        # Első sor: Ár és Idő
        self.price_time_label = QLabel("Waiting for live data...")
        self.price_time_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
        self.price_time_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        info_layout.addWidget(self.price_time_label)

        # Második sor: Predikció Értékelés és Százalékok
        self.prediction_label = QLabel("Prediction: N/A")
        self.prediction_label.setStyleSheet("color: #AAAAAA; font-size: 14px;")
        self.prediction_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        info_layout.addWidget(self.prediction_label)

        main_layout.addWidget(info_container)

        # --- Chart Inicializálása (70% main, 30% sub) ---
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

        js_code = f"""
        {self.subchart.id}.chart.priceScale('right').applyOptions({{
            autoScale: false,
            scaleMargins: {{ top: 0.1, bottom: 0.1 }},
        }});
        """
        self.subchart.run_script(js_code)

        # Dinamikus görbék (forestgreen és firebrick színekkel)
        self.long_line = self.subchart.create_line(color='forestgreen', width=2)
        self.short_line = self.subchart.create_line(color='firebrick', width=2)
        self.noise_line = self.subchart.create_line(color='rgba(169, 169, 169, 1)', width=2)

        # Horgonyok (Anchor) a 0.0 és 1.0 értékhez, hogy rögzítsék a Y skálát
        self.anchor_top = self.subchart.horizontal_line(1.0, color='rgba(255, 255, 255, 0.1)', width=1, style='dashed', text='1.0', axis_label_visible=True)
        self.anchor_bottom = self.subchart.horizontal_line(0.0, color='rgba(255, 255, 255, 0.1)', width=1, style='dashed', text='0.0', axis_label_visible=True)

        # 4D Optuna Aszimmetrikus Küszöbök (Vékony 1px vonalak)
        self.thresh_long_line = self.subchart.create_line(color='rgba(34, 139, 34, 0.5)', width=1) # forestgreen 50%
        self.thresh_short_line = self.subchart.create_line(color='rgba(178, 34, 34, 0.5)', width=1) # firebrick 50%
        self.thresh_noise_line = self.subchart.create_line(color='rgba(169, 169, 169, 0.5)', width=1)

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

    def get_prediction_eval(self, p_long, p_short, p_noise):
        # 4D Thresholdok
        T_LONG = 0.35
        T_SHORT = 0.36
        T_NOISE = 0.47

        if p_noise > T_NOISE:
            return "HOLD (Magas Zaj)", "gray"
        elif p_long > T_LONG and p_long > p_short:
            if p_noise > 0.30:
                return "BUY (Zajos)", "lightgreen"
            else:
                return "BUY (Tiszta)", "forestgreen"
        elif p_short > T_SHORT and p_short > p_long:
            if p_noise > 0.30:
                return "SELL (Zajos)", "lightcoral"
            else:
                return "SELL (Tiszta)", "firebrick"
        else:
            return "HOLD (Nincs szignál)", "gray"

    def on_data_received(self, data):
        raw_ts = pd.to_datetime(data['timestamp'], unit='s')
        minute_ts_dt = raw_ts.floor('min')
        ts_str = minute_ts_dt.strftime('%Y-%m-%d %H:%M:%S')

        price = data['close']
        # Tizedesjegyek formázása a felesleges nullák elkerülése végett (max 2 tizedes, de ha .0 akkor kiveszi)
        formatted_price = f"{price:g}"

        if self.current_minute_ts != ts_str:
            self.current_minute_ts = ts_str
            self.current_open = data.get('open', price)
            self.current_high = data.get('high', price)
            self.current_low = data.get('low', price)
        else:
            if price > self.current_high: self.current_high = price
            if price < self.current_low: self.current_low = price

        self.price_time_label.setText(f"Live Price: {formatted_price} | Time: {ts_str}")

        p_long = data.get('p_long', 0.0)
        p_short = data.get('p_short', 0.0)
        p_noise = data.get('p_noise', 0.0)

        eval_text, eval_color = self.get_prediction_eval(p_long, p_short, p_noise)

        meta_decision = data.get('meta_verdict', '')
        if meta_decision:
            pred_str = f'Prediction: <span style="color:{eval_color}; font-weight:bold;">{eval_text}</span> | Meta-LSTM: {meta_decision} | Long: {p_long*100:.1f}% | Short: {p_short*100:.1f}% | Noise: {p_noise*100:.1f}%'
        else:
            pred_str = f'Prediction: <span style="color:{eval_color}; font-weight:bold;">{eval_text}</span> | Long: {p_long*100:.1f}% | Short: {p_short*100:.1f}% | Noise: {p_noise*100:.1f}%'

        self.prediction_label.setText(pred_str)

        candle_data = {
            'time': ts_str,
            'open': self.current_open,
            'high': self.current_high,
            'low': self.current_low,
            'close': price
        }

        try:
            if not self.is_initialized:
                initial_df = pd.DataFrame([candle_data])
                self.chart.set(initial_df)

                self.long_line.set(pd.DataFrame([{'time': ts_str, 'value': p_long}]))
                self.short_line.set(pd.DataFrame([{'time': ts_str, 'value': p_short}]))
                self.noise_line.set(pd.DataFrame([{'time': ts_str, 'value': p_noise}]))

                self.thresh_long_line.set(pd.DataFrame([{'time': ts_str, 'value': 0.35}]))
                self.thresh_short_line.set(pd.DataFrame([{'time': ts_str, 'value': 0.36}]))
                self.thresh_noise_line.set(pd.DataFrame([{'time': ts_str, 'value': 0.47}]))

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

                self.thresh_long_line.update(pd.Series({'time': ts_str, 'value': 0.35}))
                self.thresh_short_line.update(pd.Series({'time': ts_str, 'value': 0.36}))
                self.thresh_noise_line.update(pd.Series({'time': ts_str, 'value': 0.47}))

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
