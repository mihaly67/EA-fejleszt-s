import sys
import json
import os
import zmq
import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QLabel, QHBoxLayout
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QTimer
from PyQt5.QtWebEngineWidgets import QWebEngineView
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
        self.setWindowTitle("Jules HUD v1.11 - Historical + Live Fusion")
        self.resize(1200, 800)

        # Fő widget és layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # Felső Info Sáv
        self.info_label = QLabel("BETÖLTÉS ALATT...")
        self.info_label.setStyleSheet("background-color: #1e1e1e; color: #00ff00; font-family: monospace; font-size: 16px; padding: 10px;")
        self.info_label.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(self.info_label)

        # 1. Main Chart (Árfolyam)
        self.chart = QtChart(inner_width=1.0, inner_height=0.6)
        main_layout.addWidget(self.chart.get_webview(), stretch=3)
        self.chart.layout(background_color='#000000', text_color='#ffffff')
        self.chart.candle_style(up_color='#00ff00', down_color='#ff0000')

        # 2. Subchart (Predikciók)
        self.subchart = QtChart(inner_width=1.0, inner_height=0.4)
        main_layout.addWidget(self.subchart.get_webview(), stretch=2)
        self.subchart.layout(background_color='#090909', text_color='#ffffff')

        # Predikciós vonalak (Subchart)
        self.line_long = self.subchart.create_line(name="P_Long", color="#00ff00", width=2)
        self.line_short = self.subchart.create_line(name="P_Short", color="#ff0000", width=2)

        # Hálózat indítása egy kis késleltetéssel (hogy a chart betöltsön)
        QTimer.singleShot(1000, self.init_history_and_network)

        self.last_close = None
        self.current_minute = None

    def init_history_and_network(self):
        # 1. Történelmi (CSV) adatok beolvasása az EA exportjából
        csv_path = "/home/Jules/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/MQL5/Files/history_init.csv"

        try:
            if os.path.exists(csv_path):
                print(f"[HISTORY] CSV fájl megtalálva: {csv_path}")
                df = pd.read_csv(csv_path)

                # A time oszlopnak datetime-nak kell lennie a lightweight-charts-hoz!
                # MT5 Unix timestamp-et ad (másodperc).
                df['time'] = pd.to_datetime(df['time'].astype(int), unit='s')

                # A dataframe utolsó értékeit elmentjük a későbbi élő frissítéshez
                if not df.empty:
                    self.current_minute = df.iloc[-1]['time']
                    self.last_close = df.iloc[-1]['close']

                # Betöltés a fő chartba
                self.chart.set(df)
                print(f"[HISTORY] Fő chart inicializálva {len(df)} gyertyával.")

                # DUMMY INITIALIZATION a Subchartok számára!
                # Ahhoz, hogy elkerüljük a lightweight-charts-python NameError-ját (No column named "P_Long")
                # pontosan a vonal nevének megfelelő oszlopot kell létrehozni!

                df_long = pd.DataFrame({'time': df['time'], 'P_Long': 0.0})
                self.line_long.set(df_long)

                df_short = pd.DataFrame({'time': df['time'], 'P_Short': 0.0})
                self.line_short.set(df_short)

                print(f"[HISTORY] Subchart dummy szinkronizáció megtörtént.")

            else:
                print(f"[HISTORY WARNING] Nem található a {csv_path} fájl. Történelmi gyertyák nélkül indulunk.")
        except Exception as e:
            print(f"[HISTORY ERROR] Hiba a CSV betöltésekor: {e}")

        # 2. ZMQ Szál indítása (Élő adatok)
        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_live_tick)
        self.zmq_thread.start()
        self.info_label.setText("ÉLŐ ADATKAPCSOLAT AKTÍV (WAITING FOR TICKS...)")


    def on_live_tick(self, data):
        # Élő adatok másodperces/tick pontosságúak.
        # A lightweight charts-nak pontos time update kell, ha percet akarunk építeni,
        # akkor floor-oljuk a mostani időt percre.
        now = pd.Timestamp.now()
        minute_floored = now.floor('min')

        if self.last_close is None:
            self.last_close = 1.0 # Fallback

        if self.current_minute is None:
            self.current_minute = minute_floored

        signal = data['signal']
        p_l = data['p_long']
        p_s = data['p_short']

        tick_time = minute_floored

        # Subchart update (Predikciós vonalak)
        # Az update pd.Series formátumot vár, ahol a time mellett a line name-je az oszlop.
        self.line_long.update(pd.Series({'time': tick_time, 'P_Long': p_l}))
        self.line_short.update(pd.Series({'time': tick_time, 'P_Short': p_s}))

        # Main chart update
        self.chart.update(pd.Series({'time': tick_time, 'open': self.last_close, 'high': self.last_close, 'low': self.last_close, 'close': self.last_close}))

        self.current_minute = minute_floored

        # Info sáv frissítése
        self.info_label.setText(f"SIGNAL: {signal} | LONG: {p_l:.1%} | SHORT: {p_s:.1%}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = HUDMainWindow()
    window.show()
    sys.exit(app.exec_())
