import sys
import os
import json
import zmq
import pandas as pd
from datetime import datetime

# RDP/VNC (xrdp) FEKETE KÉPERNYŐ JAVÍTÁSA
os.environ["QTWEBENGINE_DISABLE_GPU"] = "1"
os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = "--disable-gpu --disable-software-rasterizer"

sys.argv.append("--disable-gpu")
sys.argv.append("--no-sandbox")

from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QHBoxLayout, QLabel
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QTimer
from PyQt5.QtWebEngineWidgets import QWebEngineView

from lightweight_charts.widgets import QtChart

class ZMQReceiverThread(QThread):
    data_received = pyqtSignal(dict)

    def __init__(self, port=5557, host='127.0.0.1'):
        super().__init__()
        self.port = port
        self.host = host
        self.running = True

    def run(self):
        context = zmq.Context()
        socket = context.socket(zmq.SUB)
        socket.connect(f"tcp://{self.host}:{self.port}")
        socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

        self.msleep(2000)

        while self.running:
            # Buffer flush logic: read all available messages in the queue to catch up to real-time.
            # Only emit the LAST (freshest) message to the GUI to avoid rendering backlog (stuttering).
            latest_data = None
            while True:
                try:
                    msg = socket.recv_string(flags=zmq.NOBLOCK)
                    if msg.startswith("HUD "):
                        json_data = msg[4:]
                        latest_data = json.loads(json_data)
                except zmq.Again:
                    break
                except Exception as e:
                    print(f"ZMQ HUD Vételi Hiba: {e}", flush=True)
                    break

            if latest_data is not None:
                self.data_received.emit(latest_data)

            self.msleep(10)

    def stop(self):
        self.running = False
        self.wait()


class DualPaneHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules LGBM Copilot System")
        self.resize(1000, 800)
        self.setStyleSheet("background-color: #121212; color: #ffffff;")

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)

        # === INFO PANEL ===
        info_layout = QHBoxLayout()
        self.signal_label = QLabel("Waiting for Prediction...")
        self.signal_label.setStyleSheet("color: gray; font-size: 18px; font-weight: bold;")
        self.signal_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)

        self.prob_label = QLabel("P_Long: 0.00 | P_Short: 0.00 | P_Noise: 0.00")
        self.prob_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
        self.prob_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

        info_layout.addWidget(self.signal_label)
        info_layout.addWidget(self.prob_label)
        main_layout.addLayout(info_layout)

        # === CHART INIT (MAIN CHART = CANDLESTICKS) ===
        # The main chart will hold the candlesticks. We configure it normally.
        self.chart = QtChart(inner_width=1, inner_height=0.6)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.time_scale(visible=True, right_offset=15)
        self.chart.get_webview().setStyleSheet("background-color: #121212;")

        # Add the chart to the layout (Main Chart = Candlesticks)
        main_layout.addWidget(self.chart.get_webview(), stretch=3)

        # === PRICE LINES (ON MAIN CHART) ===
        # Use native horizontal lines to prevent historical path "zigzag" connecting lines.
        # These lines will move dynamically tick-by-tick.
        # By omitting the 'text' parameter, the library defaults to showing the numerical price on the Y-axis scale.
        self.bid_line = self.chart.horizontal_line(0.0, color='royalblue', width=1, style='dotted')
        self.ask_line = self.chart.horizontal_line(0.0, color='red', width=1, style='dotted')

        # Position lines dictionary to hold multiple arbitrary entries dynamically
        self.pos_lines = {}

        # === PIVOT (ZIGZAG) LINES (ON MAIN CHART) ===
        # Spawn off-screen to avoid freezing, update with real prices on tick
        self.res_mic_line = self.chart.horizontal_line(0.0001, color='gray', width=1, style='dashed', text='R1 (Mic)')
        self.sup_mic_line = self.chart.horizontal_line(0.0001, color='gray', width=1, style='dashed', text='S1 (Mic)')

        self.res_sec_line = self.chart.horizontal_line(0.0001, color='darkred', width=1, style='dashed', text='R2 (Sec)')
        self.sup_sec_line = self.chart.horizontal_line(0.0001, color='darkgreen', width=1, style='dashed', text='S2 (Sec)')

        self.res_ter_line = self.chart.horizontal_line(0.0001, color='maroon', width=2, style='solid', text='R3 (Ter)')
        self.sup_ter_line = self.chart.horizontal_line(0.0001, color='darkolivegreen', width=2, style='solid', text='S3 (Ter)')

        # === SUBCHART (PREDICTIONS) ===
        # Create a synchronized subchart (bottom pane by default).
        # We set sync=True so the crosshair and time scales move together perfectly.
        self.subchart = self.chart.create_subchart(width=1.0, height=0.4, sync=True)
        self.subchart.layout(background_color='#121212', text_color='#ffffff')
        self.subchart.grid(vert_enabled=False, horz_enabled=False)
        self.subchart.price_scale(auto_scale=True, scale_margin_top=0.0, scale_margin_bottom=0.0)
        self.subchart.run_script(f"{self.subchart.id}.chart.priceScale('right').applyOptions({{'visible': true, 'autoScale': true, 'scaleMargins': {{'top': 0, 'bottom': 0}}}})")
        self.subchart.time_scale(visible=True, seconds_visible=False, right_offset=15)

        # Hide candlesticks in the subchart because it's for probabilities
        self.subchart.candle_style(
            up_color='rgba(0,0,0,0)', down_color='rgba(0,0,0,0)',
            border_up_color='rgba(0,0,0,0)', border_down_color='rgba(0,0,0,0)',
            wick_up_color='rgba(0,0,0,0)', wick_down_color='rgba(0,0,0,0)'
        )

        # === PREDICTION LINES (ON SUBCHART) ===
        self.p_long_line = self.subchart.create_line('P_Long', color='forestgreen', width=2, price_line=False)
        self.p_short_line = self.subchart.create_line('P_Short', color='firebrick', width=2, price_line=False)
        self.p_noise_line = self.subchart.create_line('P_Noise', color='gray', width=1, style='dotted', price_line=False)

        # === THRESHOLD LINES (ON SUBCHART) ===
        self.thr_long = self.subchart.horizontal_line(0.35, color='forestgreen', width=1, style='dashed', text='Thr_Long_Min')
        self.thr_short = self.subchart.horizontal_line(0.36, color='firebrick', width=1, style='dashed', text='Thr_Short_Min')
        self.thr_noise = self.subchart.horizontal_line(0.47, color='gray', width=1, style='dashed', text='Thr_Noise_Max')

        # Dummy min-max lines to force 0 to 1 scaling natively on the subchart
        self.dummy_min = self.subchart.create_line('DummyMin', color='rgba(0,0,0,0)', width=1, price_label=True)
        self.dummy_max = self.subchart.create_line('DummyMax', color='rgba(0,0,0,0)', width=1, price_label=True)

        self.is_initialized = False
        self.last_ts = None

        # Candlestick aggregation state
        self.current_minute_ts = None
        self.current_open = 0.0
        self.current_high = 0.0
        self.current_low = float('inf')

        # --- LOAD HISTORICAL BARS FROM CSV BEFORE STARTING ZMQ ---
        import os
        csv_path = "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/history_init.csv"
        if os.path.exists(csv_path):
            try:
                import pandas as pd
                df_hist = pd.read_csv(csv_path)
                # MT5 sends unix timestamps, convert to formatted string for lightweight charts
                df_hist['time'] = pd.to_datetime(df_hist['time'], unit='s').dt.strftime('%Y-%m-%d %H:%M:%S')

                self.chart.set(df_hist)

                df_dummy = df_hist.copy()
                df_dummy['open'] = 0.0
                df_dummy['high'] = 1.0
                df_dummy['low'] = 0.0
                df_dummy['close'] = 0.5
                self.subchart.set(df_dummy)

                self.is_initialized = True
                print("Historical data loaded from CSV.")
            except Exception as e:
                print(f"Failed to load historical CSV: {e}")
        else:
            print("No historical CSV found at startup.")

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.chart.get_webview().loadFinished.connect(lambda: QTimer.singleShot(1000, self.zmq_thread.start))

    def on_data_received(self, data):
        # 1-MINUTE LOGIC:
        # The user specifically requested that both the chart and subchart sit on a standard 1-minute X-axis.
        # The candlestick builds (updates) tick-by-tick on the SAME minute coordinate.
        # The prediction curve also updates its position on the SAME minute coordinate until the minute closes.

        raw_ts = pd.to_datetime(data['timestamp'], unit='s')
        minute_ts_dt = raw_ts.floor('min')
        ts_str = minute_ts_dt.strftime('%Y-%m-%d %H:%M:%S')

        price = data['close']

        if self.current_minute_ts != ts_str:
            # New minute started
            self.current_minute_ts = ts_str
            self.current_open = data.get('open', price)
            self.current_high = data.get('high', price)
            self.current_low = data.get('low', price)
        else:
            # Update current minute bounds (tick-by-tick building)
            self.current_high = max(self.current_high, price)
            self.current_low = min(self.current_low, price)

        # Candlestick representation updating the CURRENT minute.
        # Lightweight-Charts will overwrite the existing point if the `time` is identical.
        # This will animate the candlestick building up tick-by-tick and the prediction
        # jumping up and down tick-by-tick on the exact same minute coordinate.
        candle_df = pd.DataFrame([{
            'time': ts_str,
            'open': self.current_open,
            'high': self.current_high,
            'low': self.current_low,
            'close': price
        }])

        # We also need a dummy update for the subchart to pull its time scale forward
        dummy_df = pd.DataFrame([{
            'time': ts_str,
            'open': 0.0,
            'high': 1.0,
            'low': 0.0,
            'close': 0.5
        }])

        p_long_df = pd.DataFrame([{'time': ts_str, 'P_Long': data.get('p_long', 0.0)}])
        p_short_df = pd.DataFrame([{'time': ts_str, 'P_Short': data.get('p_short', 0.0)}])
        p_noise_df = pd.DataFrame([{'time': ts_str, 'P_Noise': data.get('p_noise', 0.0)}])

        try:
            if not self.is_initialized:
                # Initialize Main Chart (Candles)
                self.chart.set(candle_df)

                self.bid_line.update(data.get('bid', price))
                self.ask_line.update(data.get('ask', price))

                # Update Pivot Lines
                self.res_mic_line.update(data.get('res_micro', 0.0001))
                self.sup_mic_line.update(data.get('sup_micro', 0.0001))
                self.res_sec_line.update(data.get('res_sec', 0.0001))
                self.sup_sec_line.update(data.get('sup_sec', 0.0001))
                self.res_ter_line.update(data.get('res_ter', 0.0001))
                self.sup_ter_line.update(data.get('sup_ter', 0.0001))

                # Dynamic Multiple Position Lines Management
                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])

                active_prices = []
                for pt, pp in zip(pos_types, pos_prices):
                    if pt != 0:
                        active_prices.append(pp)

                # Create or update lines for currently active prices
                for pp in active_prices:
                    if pp not in self.pos_lines:
                        self.pos_lines[pp] = self.chart.horizontal_line(pp, color='forestgreen', width=2, style='solid', text='Entry')
                    else:
                        self.pos_lines[pp].update(pp) # Ensure it stays in place just in case

                # Delete lines that are no longer active
                prices_to_delete = []
                for existing_pp in self.pos_lines.keys():
                    if existing_pp not in active_prices:
                        self.pos_lines[existing_pp].delete()
                        prices_to_delete.append(existing_pp)

                for pp in prices_to_delete:
                    del self.pos_lines[pp]

                # Initialize Subchart (Predictions + Time Scale Sync)
                self.subchart.set(dummy_df)
                self.p_long_line.set(p_long_df)
                self.p_short_line.set(p_short_df)
                self.p_noise_line.set(p_noise_df)

                d_min = pd.DataFrame([{'time': ts_str, 'DummyMin': 0.0}])
                d_max = pd.DataFrame([{'time': ts_str, 'DummyMax': 1.0}])
                self.dummy_min.set(d_min)
                self.dummy_max.set(d_max)

                self.is_initialized = True
            else:
                # Update Main Chart (Candles)
                s_c = candle_df.iloc[0].copy()
                s_c.name = None
                self.chart.update(s_c)

                # Update Main Chart Horizontal Lines
                self.bid_line.update(data.get('bid', price))
                self.ask_line.update(data.get('ask', price))

                # Update Pivot Lines
                self.res_mic_line.update(data.get('res_micro', 0.0001))
                self.sup_mic_line.update(data.get('sup_micro', 0.0001))
                self.res_sec_line.update(data.get('res_sec', 0.0001))
                self.sup_sec_line.update(data.get('sup_sec', 0.0001))
                self.res_ter_line.update(data.get('res_ter', 0.0001))
                self.sup_ter_line.update(data.get('sup_ter', 0.0001))

                # Dynamic Multiple Position Lines Management
                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])

                active_prices = []
                for pt, pp in zip(pos_types, pos_prices):
                    if pt != 0:
                        active_prices.append(pp)

                # Create or update lines for currently active prices
                for pp in active_prices:
                    if pp not in self.pos_lines:
                        self.pos_lines[pp] = self.chart.horizontal_line(pp, color='forestgreen', width=2, style='solid', text='Entry')
                    else:
                        self.pos_lines[pp].update(pp) # Ensure it stays in place

                # Delete lines that are no longer active
                prices_to_delete = []
                for existing_pp in self.pos_lines.keys():
                    if existing_pp not in active_prices:
                        self.pos_lines[existing_pp].delete()
                        prices_to_delete.append(existing_pp)

                for pp in prices_to_delete:
                    del self.pos_lines[pp]

                # Update Subchart Dummy to pull X-axis forward
                dummy_s = dummy_df.iloc[0].copy()
                dummy_s.name = None
                self.subchart.update(dummy_s)

                # Update Subchart Lines
                s_l = pd.Series({'time': ts_str, 'P_Long': data.get('p_long', 0.0)})
                s_l.name = 'P_Long'
                self.p_long_line.update(s_l)

                s_s = pd.Series({'time': ts_str, 'P_Short': data.get('p_short', 0.0)})
                s_s.name = 'P_Short'
                self.p_short_line.update(s_s)

                s_n = pd.Series({'time': ts_str, 'P_Noise': data.get('p_noise', 0.0)})
                s_n.name = 'P_Noise'
                self.p_noise_line.update(s_n)

                s_min = pd.Series({'time': ts_str, 'DummyMin': 0.0})
                s_min.name = 'DummyMin'
                self.dummy_min.update(s_min)

                s_max = pd.Series({'time': ts_str, 'DummyMax': 1.0})
                s_max.name = 'DummyMax'
                self.dummy_max.update(s_max)

        except Exception as e:
            print(f"Update error: {e}", flush=True)

        signal = data.get('signal', 0)
        is_stable = data.get('is_stable', False)

        if signal == 1:
            sig_text = "BUY (Long)"
            color = "#228B22"
        elif signal == -1:
            sig_text = "SELL (Short)"
            color = "#B22222"
        else:
            sig_text = "WAIT (Hold)"
            color = "gray"

        stability_text = " [STABLE]" if is_stable else " [UNSTABLE]"

        self.signal_label.setText(f"Signal: {sig_text}{stability_text}")
        self.signal_label.setStyleSheet(f"color: {color}; font-size: 18px; font-weight: bold;")
        self.prob_label.setText(f"P_Long: {data.get('p_long', 0.0):.2f} | P_Short: {data.get('p_short', 0.0):.2f} | P_Noise: {data.get('p_noise', 0.0):.2f}")

    def closeEvent(self, event):
        self.zmq_thread.stop()
        event.accept()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = DualPaneHUD()
    window.show()
    sys.exit(app.exec_())
