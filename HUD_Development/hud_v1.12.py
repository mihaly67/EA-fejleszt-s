import sys
import json
import os
import zmq
import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QLabel, QHBoxLayout
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QTimer
from PyQt5.QtWebEngineWidgets import QWebEngineView
from lightweight_charts.widgets import QtChart
from datetime import datetime, timezone

# ==============================================================================
# ZMQ HÁLÓZATI SZÁL (Adatfogadó)
# ==============================================================================
class ZMQReceiverThread(QThread):
    data_received = pyqtSignal(dict)

    def run(self):
        context = zmq.Context()
        subscriber = context.socket(zmq.SUB)
        subscriber.connect("tcp://127.0.0.1:5557")
        subscriber.setsockopt_string(zmq.SUBSCRIBE, "PRED")

        print("[ZMQ] Csatlakoztunk az 5557-es PUB/SUB portra, várom a tickeket...", flush=True)

        while True:
            try:
                message = subscriber.recv_string()
                if message.startswith("PRED|"):
                    parts = message.split("|")
                    if len(parts) >= 5:
                        data = {
                            'signal': parts[1],
                            'p_long': float(parts[2]),
                            'p_short': float(parts[3]),
                            'p_noise': float(parts[4])
                        }
                        self.data_received.emit(data)
            except Exception as e:
                print(f"[ZMQ ERROR] {e}", flush=True)

# ==============================================================================
# FŐ ABLAK ÉS CHART LOGIKA
# ==============================================================================
class HUDMainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules HUD v1.12 - Advanced Sync")
        self.resize(1200, 800)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        self.info_label = QLabel("BETÖLTÉS ALATT...")
        self.info_label.setStyleSheet("background-color: #1e1e1e; color: #00ff00; font-family: monospace; font-size: 16px; padding: 10px;")
        self.info_label.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(self.info_label)

        # 1. Main Chart
        self.chart = QtChart(inner_width=1.0, inner_height=0.6)
        main_layout.addWidget(self.chart.get_webview(), stretch=3)
        self.chart.layout(background_color='#000000', text_color='#ffffff')
        self.chart.candle_style(up_color='#00ff00', down_color='#ff0000')
        self.chart.time_scale(right_offset=15) # Leave some space on the right

        # 2. Subchart
        self.subchart = QtChart(inner_width=1.0, inner_height=0.4)
        main_layout.addWidget(self.subchart.get_webview(), stretch=2)
        self.subchart.layout(background_color='#090909', text_color='#ffffff')
        self.subchart.time_scale(right_offset=15)

        self.line_long = self.subchart.create_line(name="P_Long", color="#00ff00", width=2)
        self.line_short = self.subchart.create_line(name="P_Short", color="#ff0000", width=2)

        QTimer.singleShot(1000, self.init_history_and_network)

        self.last_close = None
        self.tick_count = 0
        self.last_dt = None

    def init_history_and_network(self):
        csv_path = "/home/Jules/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/MQL5/Files/history_init.csv"

        try:
            if os.path.exists(csv_path):
                print(f"[HISTORY] CSV fájl megtalálva: {csv_path}", flush=True)
                df = pd.read_csv(csv_path)

                # datetime conversion - leave as pandas datetime objects, DO NOT convert to string,
                # as string passing causes "Value is null" in lightweight-charts JS core on the Jules Box
                df['time'] = pd.to_datetime(df['time'].astype(int), unit='s')

                if not df.empty:
                    self.last_dt = df.iloc[-1]['time']
                    self.last_close = float(df.iloc[-1]['close'])
                    print(f"[HISTORY] Last historical candle time: {self.last_dt}, close: {self.last_close}", flush=True)

                self.chart.set(df)

                df_long = pd.DataFrame({'time': df['time'], 'P_Long': 0.0})
                self.line_long.set(df_long)

                df_short = pd.DataFrame({'time': df['time'], 'P_Short': 0.0})
                self.line_short.set(df_short)

                print(f"[HISTORY] Fő chart és Subchart betöltve.", flush=True)
            else:
                print(f"[HISTORY WARNING] CSV nincs meg: {csv_path}", flush=True)
        except Exception as e:
            print(f"[HISTORY ERROR] Hiba: {e}", flush=True)

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_live_tick)
        self.zmq_thread.start()
        self.info_label.setText("ÉLŐ ADATKAPCSOLAT AKTÍV (WAITING FOR TICKS...)")

    def on_live_tick(self, data):
        self.tick_count += 1

        now = pd.Timestamp.now().floor('min')

        # Safe chronological checking, no artificial adding unless past!
        if self.last_dt:
            if now < self.last_dt:
                now = self.last_dt
            elif now > self.last_dt:
                 self.last_dt = now

        if self.last_close is None:
            self.last_close = 1.0

        signal = data['signal']
        p_l = data['p_long']
        p_s = data['p_short']

        if self.tick_count % 10 == 0:
            print(f"[LIVE] Tick {self.tick_count} | Time: {now} | L: {p_l:.2f} S: {p_s:.2f}", flush=True)

        try:
            # Pass Pandas Datetime objects, not strings.
            self.line_long.update(pd.Series({'time': now, 'P_Long': p_l}))
            self.line_short.update(pd.Series({'time': now, 'P_Short': p_s}))
            self.chart.update(pd.Series({'time': now, 'open': self.last_close, 'high': self.last_close, 'low': self.last_close, 'close': self.last_close}))
        except Exception as e:
            print(f"[UPDATE ERROR] {e}", flush=True)

        self.info_label.setText(f"TICK: {self.tick_count} | SIGNAL: {signal} | LONG: {p_l:.1%} | SHORT: {p_s:.1%} | TIME: {now.strftime('%H:%M:%S')}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = HUDMainWindow()
    window.show()
    sys.exit(app.exec_())
