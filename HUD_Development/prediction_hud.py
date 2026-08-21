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
            try:
                msg = socket.recv_string(flags=zmq.NOBLOCK)
                if msg.startswith("HUD "):
                    json_data = msg[4:]
                    data = json.loads(json_data)
                    self.data_received.emit(data)
            except zmq.Again:
                self.msleep(10)
            except Exception as e:
                print(f"ZMQ HUD Vételi Hiba: {e}", flush=True)

    def stop(self):
        self.running = False
        self.wait()


class PredictionHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("LGBM Copilot - Prediction Chart")
        self.resize(1000, 600)
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

        # === CHART INIT ===
        self.chart = QtChart(inner_width=1, inner_height=1)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.time_scale(visible=True)
        self.chart.get_webview().setStyleSheet("background-color: #121212;")

        # Hide candles completely to leave only lines
        self.chart.candle_style(
            up_color='rgba(0,0,0,0)', down_color='rgba(0,0,0,0)',
            border_up_color='rgba(0,0,0,0)', border_down_color='rgba(0,0,0,0)',
            wick_up_color='rgba(0,0,0,0)', wick_down_color='rgba(0,0,0,0)'
        )

        main_layout.addWidget(self.chart.get_webview(), stretch=1)

        # === PREDICTION LINES ===
        self.p_long_line = self.chart.create_line('P_Long', color='forestgreen', width=2)
        self.p_short_line = self.chart.create_line('P_Short', color='firebrick', width=2)
        self.p_noise_line = self.chart.create_line('P_Noise', color='gray', width=1, style='dotted')

        # === THRESHOLD LINES ===
        self.thr_long = self.chart.create_line('Thr_Long', color='forestgreen', width=1, style='dashed')
        self.thr_short = self.chart.create_line('Thr_Short', color='firebrick', width=1, style='dashed')
        self.thr_noise = self.chart.create_line('Thr_Noise', color='gray', width=1, style='dashed')

        # Dummy min-max lines to force 0 to 1 scaling natively.
        self.dummy_min = self.chart.create_line('DummyMin', color='rgba(0,0,0,0)', width=1, price_label=False)
        self.dummy_max = self.chart.create_line('DummyMax', color='rgba(0,0,0,0)', width=1, price_label=False)

        self.is_initialized = False

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.chart.get_webview().loadFinished.connect(lambda: QTimer.singleShot(1000, self.zmq_thread.start))

    def on_data_received(self, data):
        # Use exact timestamp for tick-by-tick continuous rolling
        raw_ts = pd.to_datetime(data['timestamp'], unit='s')
        ts_str = raw_ts.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3] # ms precision

        # Provide a dummy candlestick to advance the chart's inner time scale
        # If we don't provide this, lightweight-charts-python will NOT advance the line points
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

        # Define thresholds (Can be parameterized later based on Optuna 4D thresholds)
        TH_LONG = 0.45
        TH_SHORT = 0.40
        TH_NOISE = 0.35

        try:
            if not self.is_initialized:
                self.chart.set(dummy_df)

                self.p_long_line.set(p_long_df)
                self.p_short_line.set(p_short_df)
                self.p_noise_line.set(p_noise_df)

                t_l_df = pd.DataFrame([{'time': ts_str, 'Thr_Long': TH_LONG}])
                t_s_df = pd.DataFrame([{'time': ts_str, 'Thr_Short': TH_SHORT}])
                t_n_df = pd.DataFrame([{'time': ts_str, 'Thr_Noise': TH_NOISE}])
                self.thr_long.set(t_l_df)
                self.thr_short.set(t_s_df)
                self.thr_noise.set(t_n_df)

                d_min = pd.DataFrame([{'time': ts_str, 'DummyMin': 0.0}])
                d_max = pd.DataFrame([{'time': ts_str, 'DummyMax': 1.0}])
                self.dummy_min.set(d_min)
                self.dummy_max.set(d_max)

                self.is_initialized = True
            else:
                dummy_s = pd.Series({'time': ts_str, 'open': 0.0, 'high': 1.0, 'low': 0.0, 'close': 0.5})
                self.chart.update(dummy_s)

                s_l = pd.Series({'time': ts_str, 'P_Long': data.get('p_long', 0.0)})
                s_l.name = 'P_Long'
                self.p_long_line.update(s_l)

                s_s = pd.Series({'time': ts_str, 'P_Short': data.get('p_short', 0.0)})
                s_s.name = 'P_Short'
                self.p_short_line.update(s_s)

                s_n = pd.Series({'time': ts_str, 'P_Noise': data.get('p_noise', 0.0)})
                s_n.name = 'P_Noise'
                self.p_noise_line.update(s_n)

                s_tl = pd.Series({'time': ts_str, 'Thr_Long': TH_LONG})
                s_tl.name = 'Thr_Long'
                self.thr_long.update(s_tl)

                s_ts = pd.Series({'time': ts_str, 'Thr_Short': TH_SHORT})
                s_ts.name = 'Thr_Short'
                self.thr_short.update(s_ts)

                s_tn = pd.Series({'time': ts_str, 'Thr_Noise': TH_NOISE})
                s_tn.name = 'Thr_Noise'
                self.thr_noise.update(s_tn)

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
    window = PredictionHUD()
    window.show()
    sys.exit(app.exec_())
