import sys
import time
import socket
import threading
import pandas as pd
import numpy as np
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QHBoxLayout, QLabel, QPushButton, QComboBox, QSplitter
from PyQt5.QtCore import QTimer, Qt
import pyqtgraph as pg

class TimeAxisItem(pg.AxisItem):
    def tickStrings(self, values, scale, spacing):
        return [pd.to_datetime(value, unit='ms').strftime('%H:%M:%S') for value in values]

# --- MT5 ONLINE SOCKET RECEIVER (ZMQ/RAW TCP BRIDGE) ---
class MT5SocketBridge(threading.Thread):
    def __init__(self, host='127.0.0.1', port=5555, dashboard=None):
        super().__init__()
        self.host = host
        self.port = port
        self.dashboard = dashboard
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        self.client_socket = None

    def run(self):
        print(f"[BRIDGE] Vaku 3.0 MT5 Bridge indul ezen: {self.host}:{self.port}")
        while self.running:
            try:
                self.server_socket.settimeout(2.0)
                try:
                    client, addr = self.server_socket.accept()
                    self.client_socket = client
                    print(f"[BRIDGE] EA Csatlakozott: {addr}")
                except socket.timeout:
                    continue

                buffer = ""
                while self.running and self.client_socket:
                    try:
                        data = self.client_socket.recv(4096).decode('utf-8')
                        if not data:
                            print("[BRIDGE] EA Kapcsolat megszakadt.")
                            break
                        buffer += data
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            self.process_message(line.strip())
                    except Exception as e:
                        print(f"[BRIDGE] Hiba: {e}")
                        break
            except Exception as e:
                print(f"[BRIDGE] Szerver Hiba: {e}")
            finally:
                if self.client_socket:
                    self.client_socket.close()
                    self.client_socket = None

    def process_message(self, message):
        if not message: return

        parts = message.split('|')
        cmd = parts[0]

        if cmd == "HISTORY_START":
            print(f"[BRIDGE] Történelmi adatok (HISTORY) letöltése indul... Várható darab: {parts[1]}")
            self.dashboard.history_times.clear()
            self.dashboard.history_prices.clear()
        elif cmd == "HISTORY_END":
            print(f"[BRIDGE] Történelmi adatok (HISTORY) vége. Betöltve: {len(self.dashboard.history_times)} tick.")
        elif cmd == "TICK":
            if len(parts) == 4:
                try:
                    time_msc = float(parts[1])
                    bid = float(parts[2])
                    ask = float(parts[3])
                    price = (bid + ask) / 2.0

                    if self.dashboard:
                        self.dashboard.add_live_tick(time_msc, price)
                except ValueError:
                    pass
        else:
            if len(parts) == 3:
                try:
                    time_msc = float(parts[0])
                    bid = float(parts[1])
                    ask = float(parts[2])
                    price = (bid + ask) / 2.0
                    if self.dashboard:
                        self.dashboard.history_times.append(time_msc)
                        self.dashboard.history_prices.append(price)
                except ValueError:
                    pass

    def stop(self):
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        self.server_socket.close()


# --- VAKU 3.0 ONLINE DASHBOARD ---
class VakuDashboardOnline(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Vaku 3.0 ONLINE MT5 Bridge (HMM Scalping Dashboard)")
        self.setGeometry(100, 100, 1200, 800)
        self.setMinimumSize(800, 600)

        # Core data buffers
        self.max_points = 1800 # ~30 perc M1
        self.history_times = []
        self.history_prices = []

        self.x_data = np.zeros(self.max_points)
        self.price_data = np.zeros(self.max_points)
        self.macro_data = np.zeros(self.max_points)
        self.risk_data = np.zeros(self.max_points)
        self.ptr = 0

        # Windows
        self.micro_window_ms = 30 * 1000
        self.macro_window_ms = 60 * 1000

        # Stats Smoothing
        self.smoothed_er = 0.0
        self.smoothed_risk = 0.0

        self.setup_ui()

        # GUI Updater (100ms)
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self.update_gui_charts)
        self.update_timer.start(100)

        # Start Bridge
        self.bridge = MT5SocketBridge(dashboard=self)
        self.bridge.start()

    def setup_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)

        # Top Panel
        top_panel = QHBoxLayout()
        self.lbl_clock = QLabel("MT5 TICK IDŐ: VÁRAKOZÁS...")
        self.lbl_clock.setStyleSheet("font-size: 16px; font-weight: bold; color: #E0E0E0;")
        top_panel.addWidget(self.lbl_clock)
        layout.addLayout(top_panel)

        # Graph
        self.graph_widget = pg.GraphicsLayoutWidget()
        layout.addWidget(self.graph_widget, stretch=3)

        self.p1 = self.graph_widget.addPlot(title="ÉLŐ TICK ÁRFOLYAM", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p1.showGrid(x=True, y=True, alpha=0.3)
        self.curve_price = self.p1.plot(pen=pg.mkPen('w', width=2))

        self.graph_widget.nextRow()
        self.p2 = self.graph_widget.addPlot(title="PIACI REZSIM (Makro ER & HMM Kockázat)", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p2.showGrid(x=True, y=True, alpha=0.3)
        self.p2.setYRange(0, 100)
        self.curve_macro = self.p2.plot(pen=pg.mkPen('c', width=2), name="Makro ER")
        self.curve_risk = self.p2.plot(pen=pg.mkPen('r', width=2), name="HMM Rizikó")
        self.p1.setXLink(self.p2)

        # Status Panel
        status_panel = QHBoxLayout()

        self.lbl_regime = QLabel("PIACI REZSIM: VÁRAKOZÁS")
        self.lbl_regime.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")
        self.lbl_regime.setWordWrap(True)
        self.lbl_regime.setMinimumHeight(60)
        status_panel.addWidget(self.lbl_regime, stretch=2)

        self.lbl_predict = QLabel("PREDIKCIÓ: VÁRAKOZÁS")
        self.lbl_predict.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")
        self.lbl_predict.setWordWrap(True)
        self.lbl_predict.setMinimumHeight(60)
        status_panel.addWidget(self.lbl_predict, stretch=2)

        self.lbl_reason = QLabel("INDIKÁCIÓ:")
        self.lbl_reason.setStyleSheet("background-color: #222; border: 1px solid #555; padding: 5px; color: #AAA;")
        self.lbl_reason.setWordWrap(True)
        self.lbl_reason.setMinimumHeight(60)
        status_panel.addWidget(self.lbl_reason, stretch=3)

        self.lbl_status = QLabel("🔴 OFFLINE")
        self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        self.lbl_status.setAlignment(Qt.AlignCenter)
        self.lbl_status.setWordWrap(True)
        self.lbl_status.setMinimumHeight(60)
        status_panel.addWidget(self.lbl_status, stretch=2)

        layout.addLayout(status_panel, stretch=0)

    def get_price_at_time(self, current_time, window_ms):
        target_time = current_time - window_ms
        if len(self.history_times) == 0:
            return None
        if target_time < self.history_times[0]:
            return self.history_prices[0]
        import bisect
        idx = bisect.bisect_left(self.history_times, target_time)
        if idx >= len(self.history_times):
            idx = len(self.history_times) - 1
        return self.history_prices[idx]

    def analyze_time_based_trend(self, current_time, current_price):
        micro_start_price = self.get_price_at_time(current_time, self.micro_window_ms)
        mac_start_price = self.get_price_at_time(current_time, self.macro_window_ms)

        if mac_start_price is None:
            return "Adatgyűjtés...\\n(Várakozás)", "#333", "NINCS JELZÉS", "#333"

        micro_slope = current_price - micro_start_price
        mac_slope = current_price - mac_start_price

        regime_str = ""
        overall_color = "#333"
        mac_pct = (mac_slope / mac_start_price) * 100
        mic_pct = (micro_slope / micro_start_price) * 100

        if mac_pct > 0.05:
            regime_str += "M1 (Makro): UP\\n"
            overall_color = "#004400"
        elif mac_pct < -0.05:
            regime_str += "M1 (Makro): DOWN\\n"
            overall_color = "#440000"
        else:
            regime_str += "M1 (Makro): FLAT\\n"
            overall_color = "#444444"

        if mic_pct > 0.02: regime_str += "S30 (Mikro): UP"
        elif mic_pct < -0.02: regime_str += "S30 (Mikro): DOWN"
        else: regime_str += "S30 (Mikro): FLAT"

        predict_str = "NINCS JELZÉS"
        predict_color = "#333"

        if mac_pct > 0.05 and mic_pct < -0.02:
            predict_str = "MEDVE FORDULÓ VÁRHATÓ!\\n(A mikro trend divergál lefelé)"
            predict_color = "#880000"
        elif mac_pct < -0.05 and mic_pct > 0.02:
            predict_str = "BIKA FORDULÓ VÁRHATÓ!\\n(A mikro trend divergál felfelé)"
            predict_color = "#008800"
        elif (mac_pct > 0 and mic_pct < 0) or (mac_pct < 0 and mic_pct > 0):
            predict_str = "WHIPSAW VESZÉLY!\\n(Konfliktus az idősíkok között)"
            predict_color = "#888800"
        else:
            predict_str = "TREND STABIL\\n(Az idősíkok egyetértenek)"
            predict_color = "#1a1a2e"

        return regime_str, overall_color, predict_str, predict_color

    def get_reason(self, decision, macro_er, risk):
        if decision == 'GREEN': return "OK:\\nKiszámítható Makro Trend.\\nNincs Brókeri Manipuláció."
        if decision == 'YELLOW': return f"OK:\\nA Makro Trend Erős (ER={macro_er:.2f}), DE a HMM\\nvalószínűsít egy Whipsaw-t (Kockázat={risk:.1f}%).\\nVárj a belépéssel!"
        if decision == 'RED':
            if macro_er < 0.05: return f"OK (KÁOSZ / OLDALAZÁS):\\nA Makro ER nagyon alacsony ({macro_er:.2f}).\\nA piac zajos, iránytalan (Oldalazás).\\nA robottal ilyenkor belépni orosz rulett."
            else: return f"OK (TÖKÉLETES VIHAR):\\nExtrém magas Brókeri Kockázat ({risk:.1f}%).\\nSpread tágítás vagy azonnali fordulat várható."

    def add_live_tick(self, unix_ms, price):
        # Update raw buffers
        self.history_times.append(unix_ms)
        self.history_prices.append(price)

        # Keep window reasonable (max 1 hour history)
        cutoff = unix_ms - (3600 * 1000)
        while len(self.history_times) > 0 and self.history_times[0] < cutoff:
            self.history_times.pop(0)
            self.history_prices.pop(0)

        # Stats Calc (Same as Offline V8.03)
        if len(self.history_prices) > 100:
            net_move = abs(self.history_prices[-1] - self.history_prices[-100])
            gross_move = sum(abs(np.diff(self.history_prices[-100:])))
            macro_er = net_move / gross_move if gross_move > 0 else 0.0

            recent_volatility = np.std(self.history_prices[-10:])
            max_volatility = np.max([np.std(self.history_prices[max(0, i-10):i]) for i in range(10, len(self.history_prices), 5)])
            if max_volatility == 0: max_volatility = 0.001
            risk = (recent_volatility / max_volatility) * 100.0
            risk = min(100.0, risk)
        else:
            macro_er = 0.0
            risk = 0.0

        alpha_er = 0.05
        alpha_risk = 0.1

        if self.ptr == 0:
            self.smoothed_er = macro_er
            self.smoothed_risk = risk
        else:
            self.smoothed_er = (alpha_er * macro_er) + ((1 - alpha_er) * self.smoothed_er)
            self.smoothed_risk = (alpha_risk * risk) + ((1 - alpha_risk) * self.smoothed_risk)

        # Push to plot arrays
        self.x_data[:-1] = self.x_data[1:]
        self.x_data[-1] = unix_ms

        self.price_data[:-1] = self.price_data[1:]
        self.price_data[-1] = price

        self.macro_data[:-1] = self.macro_data[1:]
        self.macro_data[-1] = self.smoothed_er * 100

        self.risk_data[:-1] = self.risk_data[1:]
        self.risk_data[-1] = self.smoothed_risk

        if self.ptr < self.max_points:
            self.ptr += 1

    def update_gui_charts(self):
        if self.ptr < 5: return

        draw_len = min(self.ptr, self.max_points)
        x_draw = self.x_data[-draw_len:]

        self.curve_price.setData(x_draw, self.price_data[-draw_len:])
        self.curve_macro.setData(x_draw, self.macro_data[-draw_len:])
        self.curve_risk.setData(x_draw, self.risk_data[-draw_len:])

        latest_time = x_draw[-1]
        self.lbl_clock.setText(f"MT5 TICK IDŐ: {pd.to_datetime(latest_time, unit='ms').strftime('%H:%M:%S.%f')[:-3]}")

        macro_er = self.macro_data[-1] / 100.0
        risk = self.risk_data[-1]
        decision = 'RED' if macro_er < 0.05 else ('YELLOW' if risk >= 60 else 'GREEN')

        if decision == 'GREEN':
            self.lbl_status.setText("🟢 TISZTA PIAC (MEHET A TRADE)")
            self.lbl_status.setStyleSheet("background-color: #003300; border: 2px solid #00FF00; color: #00FF00; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        elif decision == 'YELLOW':
            self.lbl_status.setText("🟡 MANIPULÁCIÓ! (VÁRJ/VIGYÁZZ)")
            self.lbl_status.setStyleSheet("background-color: #333300; border: 2px solid #FFFF00; color: #FFFF00; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        else:
            self.lbl_status.setText("🔴 KÁOSZ / OLDALAZÁS (TILTVA)")
            self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")

        regime_str, regime_color, predict_str, predict_color = self.analyze_time_based_trend(latest_time, self.price_data[-1])
        reason_text = self.get_reason(decision, macro_er, risk)

        self.lbl_regime.setText("PIACI REZSIM (IDŐ ALAPÚ):\\n" + regime_str)
        self.lbl_regime.setStyleSheet(f"background-color: {regime_color}; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_predict.setText("PREDIKCIÓ:\\n" + predict_str)
        self.lbl_predict.setStyleSheet(f"background-color: {predict_color}; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_reason.setText(reason_text)

    def closeEvent(self, event):
        self.bridge.stop()
        event.accept()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    dashboard = VakuDashboardOnline()
    dashboard.show()
    sys.exit(app.exec_())
