import sys
import os
import json
import zmq
import pandas as pd
from datetime import datetime

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

        while self.running:
            try:
                msg = socket.recv_string(flags=zmq.NOBLOCK)
                if msg.startswith("HUD "):
                    data_str = msg[4:]
                    data = json.loads(data_str)
                    self.data_received.emit(data)
            except zmq.Again:
                self.msleep(20)
            except Exception as e:
                print(f"ZMQ Error: {e}")
                self.msleep(500)

    def stop(self):
        self.running = False
        self.wait()


class AdvancedHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Merkava Copilot - Live Micro HUD")
        self.resize(1200, 800)

        self.setStyleSheet("""
            QMainWindow { background-color: #121212; }
            QLabel { color: #ffffff; font-size: 16px; font-weight: bold; }
        """)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Header
        info_layout = QHBoxLayout()
        self.signal_label = QLabel("Signal: WAIT")
        self.prob_label = QLabel("P_Long: 0.00 | P_Short: 0.00 | P_Noise: 0.00")
        info_layout.addWidget(self.signal_label)
        info_layout.addStretch()
        info_layout.addWidget(self.prob_label)
        main_layout.addLayout(info_layout)

        # Chart
        self.chart = QtChart(inner_width=1, inner_height=0.65)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.candle_style(up_color='#228B22', down_color='#B22222', border_up_color='#228B22', border_down_color='#B22222', wick_up_color='#228B22', wick_down_color='#B22222')
        self.chart.get_webview().setStyleSheet("background-color: #121212;")
        main_layout.addWidget(self.chart.get_webview(), stretch=3)

        self.bid_line = None
        self.ask_line = None

        # Subchart
        self.subchart = self.chart.create_subchart(width=1, height=0.35, sync=True)
        self.subchart.layout(background_color='#121212', text_color='#ffffff')
        self.subchart.grid(vert_enabled=False, horz_enabled=False)

        self.p_long_line = self.subchart.create_line('P_Long', color='forestgreen', width=2)
        self.p_short_line = self.subchart.create_line('P_Short', color='firebrick', width=2)
        self.p_noise_line = self.subchart.create_line('P_Noise', color='gray', width=1, style='dotted')
        self.subchart.horizontal_line(0.40, color='forestgreen', width=1, style='dashed')
        self.subchart.horizontal_line(0.40, color='firebrick', width=1, style='dashed')

        self.is_initialized = False

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.chart.get_webview().loadFinished.connect(self.on_webview_loaded)

    def on_webview_loaded(self):
        print("Webview loaded, starting ZMQ thread in 1.5s")
        QTimer.singleShot(1500, self.zmq_thread.start)

    def on_data_received(self, data):
        dt = pd.to_datetime(data['timestamp'], unit='s')
        m1_ts = dt.floor('min').strftime('%Y-%m-%d %H:%M:%S')

        price = data.get('price', data['close'])
        bid = data.get('bid', price)
        ask = data.get('ask', price)

        tick_series = pd.Series({'time': m1_ts, 'price': price})

        p_long_df = pd.DataFrame([{'time': m1_ts, 'P_Long': data.get('p_long', 0.0)}])
        p_short_df = pd.DataFrame([{'time': m1_ts, 'P_Short': data.get('p_short', 0.0)}])
        p_noise_df = pd.DataFrame([{'time': m1_ts, 'P_Noise': data.get('p_noise', 0.0)}])

        try:
            if not self.is_initialized:
                initial_df = pd.DataFrame([{
                    'time': m1_ts,
                    'open': data['open'],
                    'high': data['high'],
                    'low': data['low'],
                    'close': price
                }])
                self.chart.set(initial_df)

                self.p_long_line.set(p_long_df)
                self.p_short_line.set(p_short_df)
                self.p_noise_line.set(p_noise_df)

                self.bid_line = self.chart.horizontal_line(bid, color='gray', width=1, style='dashed', text='BID')
                self.ask_line = self.chart.horizontal_line(ask, color='lightgray', width=1, style='dashed', text='ASK')

                self.is_initialized = True
            else:
                self.chart.update_from_tick(tick_series)

                self.p_long_line.update(p_long_df.iloc[0])
                self.p_short_line.update(p_short_df.iloc[0])
                self.p_noise_line.update(p_noise_df.iloc[0])

                if self.bid_line:
                    self.bid_line.update(bid)
                if self.ask_line:
                    self.ask_line.update(ask)

        except Exception as e:
            print(f"Update error: {e}")

        # Update Header
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
    window = AdvancedHUD()
    window.show()
    sys.exit(app.exec_())
