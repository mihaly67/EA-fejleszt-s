import sys
import time
import socket
import threading
import pandas as pd
import numpy as np
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QHBoxLayout, QLabel, QPushButton, QComboBox, QSplitter, QLineEdit, QFormLayout, QGroupBox
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
                    self.client_socket.settimeout(None) # Prevents dropping connection during slow tick periods
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
            if len(parts) >= 4:
                try:
                    time_msc = float(parts[1])
                    bid = float(parts[2])
                    ask = float(parts[3])
                    price = (bid + ask) / 2.0

                    pos_type = 0
                    pos_price = 0.0
                    if len(parts) == 6:
                        pos_type = int(parts[4])
                        pos_price = float(parts[5])

                    if self.dashboard:
                        self.dashboard.add_live_tick(time_msc, price, pos_type, pos_price)
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
        self.pos_type = 0
        self.pos_price = 0.0

        # Windows
        # Settings variables managed by UI inputs now

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

                # --- PARAMETER SETTINGS PANEL ---
        settings_group = QGroupBox("HMM & Piaci Rezsim Paraméterek (Élőben szerkeszthető)")
        settings_group.setStyleSheet("QGroupBox { font-weight: bold; border: 1px solid #555; margin-top: 10px; } QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 3px 0 3px; }")
        settings_layout = QHBoxLayout()

        # Left side: Windows
        form_windows = QFormLayout()
        self.inp_micro_win = QLineEdit("30")
        self.inp_med_win = QLineEdit("0")
        self.inp_macro_win = QLineEdit("60")
        form_windows.addRow("Mikro Ablak (mp):", self.inp_micro_win)
        form_windows.addRow("Közép Ablak (mp):", self.inp_med_win)
        form_windows.addRow("Makro Ablak (mp):", self.inp_macro_win)
        settings_layout.addLayout(form_windows)

        # Middle: Sensitivities
        form_sens = QFormLayout()
        self.inp_micro_sens = QLineEdit("0.02")
        self.inp_med_sens = QLineEdit("0.03")
        self.inp_macro_sens = QLineEdit("0.05")
        form_sens.addRow("Mikro Érzékeny (%):", self.inp_micro_sens)
        form_sens.addRow("Közép Érzékeny (%):", self.inp_med_sens)
        form_sens.addRow("Makro Érzékeny (%):", self.inp_macro_sens)
        settings_layout.addLayout(form_sens)

        # Right 1: Chaos (ER Limit)
        form_chaos = QFormLayout()
        self.inp_micro_chaos = QLineEdit("0.02")
        self.inp_med_chaos = QLineEdit("0.03")
        self.inp_macro_chaos = QLineEdit("0.05")
        form_chaos.addRow("Mikro Káosz (ER <):", self.inp_micro_chaos)
        form_chaos.addRow("Közép Káosz (ER <):", self.inp_med_chaos)
        form_chaos.addRow("Makro Káosz (ER <):", self.inp_macro_chaos)
        settings_layout.addLayout(form_chaos)

        # Right 2: Whipsaw (Risk Limit)
        form_risk = QFormLayout()
        self.inp_micro_risk = QLineEdit("40.0")
        self.inp_med_risk = QLineEdit("50.0")
        self.inp_macro_risk = QLineEdit("60.0")
        form_risk.addRow("Mikro Whipsaw (% >):", self.inp_micro_risk)
        form_risk.addRow("Közép Whipsaw (% >):", self.inp_med_risk)
        form_risk.addRow("Makro Whipsaw (% >):", self.inp_macro_risk)
        settings_layout.addLayout(form_risk)

        settings_group.setLayout(settings_layout)
        layout.addWidget(settings_group)

        # Top Panel (Clock)
        top_panel = QHBoxLayout()
        self.lbl_clock = QLabel("MT5 TICK IDŐ: VÁRAKOZÁS...")
        self.lbl_clock.setStyleSheet("font-size: 18px; font-weight: bold; color: #000000; padding-bottom: 5px;")
        top_panel.addWidget(self.lbl_clock)
        layout.addLayout(top_panel)

        # Status Panel (Moved to TOP, Fixed Heights)
        status_panel = QHBoxLayout()

        self.lbl_regime = QLabel("PIACI REZSIM: VÁRAKOZÁS")
        self.lbl_regime.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")
        self.lbl_regime.setWordWrap(True)
        self.lbl_regime.setFixedHeight(120)
        status_panel.addWidget(self.lbl_regime, stretch=2)

        self.lbl_predict = QLabel("PREDIKCIÓ: VÁRAKOZÁS")
        self.lbl_predict.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")
        self.lbl_predict.setWordWrap(True)
        self.lbl_predict.setFixedHeight(120)
        status_panel.addWidget(self.lbl_predict, stretch=2)

        self.lbl_reason = QLabel("INDIKÁCIÓ:")
        self.lbl_reason.setStyleSheet("background-color: #222; border: 1px solid #555; padding: 5px; color: #AAA;")
        self.lbl_reason.setWordWrap(True)
        self.lbl_reason.setFixedHeight(120)
        status_panel.addWidget(self.lbl_reason, stretch=3)

        self.lbl_status = QLabel("🔴 OFFLINE")
        self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        self.lbl_status.setAlignment(Qt.AlignCenter)
        self.lbl_status.setWordWrap(True)
        self.lbl_status.setFixedHeight(120)
        status_panel.addWidget(self.lbl_status, stretch=2)

        layout.addLayout(status_panel, stretch=0)

        # Graph (Moved below the status panel)
        self.graph_widget = pg.GraphicsLayoutWidget()
        layout.addWidget(self.graph_widget, stretch=3)

        self.p1 = self.graph_widget.addPlot(title="ÉLŐ TICK ÁRFOLYAM", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p1.showGrid(x=True, y=True, alpha=0.3)
        self.p1.setMenuEnabled(True)
        self.curve_price = self.p1.plot(pen=pg.mkPen('w', width=2))

        # Infinite line for open position
        self.pos_line = pg.InfiniteLine(angle=0, movable=False)
        self.pos_line.setVisible(False)
        self.p1.addItem(self.pos_line)

        self.graph_widget.nextRow()
        self.p2 = self.graph_widget.addPlot(title="PIACI REZSIM (Makro ER & HMM Kockázat)", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p2.showGrid(x=True, y=True, alpha=0.3)
        self.p2.setMenuEnabled(True)
        self.p2.setYRange(0, 100)
        self.curve_macro = self.p2.plot(pen=pg.mkPen('c', width=2), name="Makro ER")
        self.curve_risk = self.p2.plot(pen=pg.mkPen('r', width=2), name="HMM Rizikó")
        self.p1.setXLink(self.p2)

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

    def get_safe_float(self, qlineedit, default_val):
        try:
            return float(qlineedit.text())
        except ValueError:
            return default_val

    def analyze_time_based_trend(self, current_time, current_price):
        micro_window_ms = self.get_safe_float(self.inp_micro_win, 30.0) * 1000.0
        med_window_ms = self.get_safe_float(self.inp_med_win, 0.0) * 1000.0
        macro_window_ms = self.get_safe_float(self.inp_macro_win, 60.0) * 1000.0

        micro_sens = self.get_safe_float(self.inp_micro_sens, 0.02)
        med_sens = self.get_safe_float(self.inp_med_sens, 0.03)
        macro_sens = self.get_safe_float(self.inp_macro_sens, 0.05)

        micro_start_price = self.get_price_at_time(current_time, micro_window_ms)
        mac_start_price = self.get_price_at_time(current_time, macro_window_ms)

        if mac_start_price is None:
            return "Adatgyűjtés...<br>(Várakozás)", "#333", "NINCS JELZÉS", "#333"

        micro_slope = current_price - micro_start_price
        mac_slope = current_price - mac_start_price

        regime_str = ""
        overall_color = "#333"
        mac_pct = (mac_slope / mac_start_price) * 100
        mic_pct = (micro_slope / micro_start_price) * 100

        # Makro
        if mac_pct > macro_sens:
            regime_str += "Makro: UP<br>"
            overall_color = "#004400"
        elif mac_pct < -macro_sens:
            regime_str += "Makro: DOWN<br>"
            overall_color = "#440000"
        else:
            regime_str += "Makro: FLAT<br>"
            overall_color = "#444444"

        # Medium (Optional)
        if med_window_ms > 0:
            med_start_price = self.get_price_at_time(current_time, med_window_ms)
            if med_start_price is not None:
                med_slope = current_price - med_start_price
                med_pct = (med_slope / med_start_price) * 100
                if med_pct > med_sens: regime_str += "Közép: UP<br>"
                elif med_pct < -med_sens: regime_str += "Közép: DOWN<br>"
                else: regime_str += "Közép: FLAT<br>"

        # Mikro
        if mic_pct > micro_sens: regime_str += "Mikro: UP"
        elif mic_pct < -micro_sens: regime_str += "Mikro: DOWN"
        else: regime_str += "Mikro: FLAT"

        # Predikció logikája marad a végleteken (Makro vs Mikro)
        predict_str = "NINCS JELZÉS"
        predict_color = "#333"

        if mac_pct > macro_sens and mic_pct < -micro_sens:
            predict_str = "MEDVE FORDULÓ VÁRHATÓ!<br>(A mikro trend divergál lefelé)"
            predict_color = "#880000"
        elif mac_pct < -macro_sens and mic_pct > micro_sens:
            predict_str = "BIKA FORDULÓ VÁRHATÓ!<br>(A mikro trend divergál felfelé)"
            predict_color = "#008800"
        elif (mac_pct > 0 and mic_pct < 0) or (mac_pct < 0 and mic_pct > 0):
            predict_str = "WHIPSAW VESZÉLY!<br>(Konfliktus az idősíkok között)"
            predict_color = "#888800"
        else:
            predict_str = "TREND STABIL<br>(Az idősíkok egyetértenek)"
            predict_color = "#1a1a2e"

        return regime_str, overall_color, predict_str, predict_color

    def get_reason(self, decision, state_str):
        if decision == 'GREEN': return "OK:<br>Kiszámítható Piaci Trend.<br>Nincs Jelentős Manipuláció."
        if decision == 'YELLOW': return f"FIGYELEM:<br>{state_str}<br>Whipsaw (Manipuláció) Veszély!<br>Várj a belépéssel!"
        if decision == 'RED': return f"TILTVA (KÁOSZ):<br>{state_str}<br>A piac zajos, iránytalan (Oldalazás).<br>Belépés szigorúan tilos."

    def add_live_tick(self, unix_ms, price, pos_type=0, pos_price=0.0):
        self.pos_type = pos_type
        self.pos_price = pos_price
        # Update raw buffers - we just store the data here, calculation happens in the GUI thread now
        self.history_times.append(unix_ms)
        self.history_prices.append(price)

        # Keep window reasonable (max 1 hour history)
        cutoff = unix_ms - (3600 * 1000)
        while len(self.history_times) > 0 and self.history_times[0] < cutoff:
            self.history_times.pop(0)
            self.history_prices.pop(0)

        # Do nothing here to avoid PyQt5 thread issues, move calculation to update_gui_charts
        pass

    def update_gui_charts(self):
        if len(self.history_times) < 10: return

        unix_ms = self.history_times[-1]
        price = self.history_prices[-1]

        # Calculations moved to GUI thread to be safe with QLineEdit reads
        micro_window_ms = self.get_safe_float(self.inp_micro_win, 30.0) * 1000.0
        med_window_ms = self.get_safe_float(self.inp_med_win, 0.0) * 1000.0
        macro_window_ms = self.get_safe_float(self.inp_macro_win, 60.0) * 1000.0

        def calc_er_risk(window_ms):
            if window_ms <= 0 or len(self.history_times) < 10: return 0.0, 0.0
            target_time = unix_ms - window_ms
            import bisect
            idx = bisect.bisect_left(self.history_times, target_time)
            if idx >= len(self.history_times): idx = len(self.history_times) - 1

            slice_prices = self.history_prices[idx:]
            if len(slice_prices) < 5: return 0.0, 0.0

            net_move = abs(slice_prices[-1] - slice_prices[0])
            gross_move = sum(abs(np.diff(slice_prices)))
            er = net_move / gross_move if gross_move > 0 else 0.0

            recent_vol = np.std(slice_prices[-min(10, len(slice_prices)):])
            step = max(5, len(slice_prices) // 10)
            vols = []
            for i in range(step, len(slice_prices), step):
                vols.append(np.std(slice_prices[max(0, i-step):i]))

            max_vol = np.max(vols) if len(vols) > 0 else 0.001
            if max_vol == 0: max_vol = 0.001

            risk = (recent_vol / max_vol) * 100.0
            return er, min(100.0, risk)

        mic_er, mic_risk = calc_er_risk(micro_window_ms)
        med_er, med_risk = calc_er_risk(med_window_ms)
        mac_er, mac_risk = calc_er_risk(macro_window_ms)

        self.current_mic_er = mic_er
        self.current_mic_risk = mic_risk
        self.current_med_er = med_er
        self.current_med_risk = med_risk

        alpha_er = 0.05
        alpha_risk = 0.1

        if self.ptr == 0:
            self.smoothed_er = mac_er
            self.smoothed_risk = mac_risk
        else:
            self.smoothed_er = (alpha_er * mac_er) + ((1 - alpha_er) * self.smoothed_er)
            self.smoothed_risk = (alpha_risk * mac_risk) + ((1 - alpha_risk) * self.smoothed_risk)

        if self.x_data[-1] != unix_ms:
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

        if self.ptr < 5: return

        mac_chaos_lim = self.get_safe_float(self.inp_macro_chaos, 0.05)
        med_chaos_lim = self.get_safe_float(self.inp_med_chaos, 0.03)
        mic_chaos_lim = self.get_safe_float(self.inp_micro_chaos, 0.02)

        mac_risk_lim = self.get_safe_float(self.inp_macro_risk, 60.0)
        med_risk_lim = self.get_safe_float(self.inp_med_risk, 50.0)
        mic_risk_lim = self.get_safe_float(self.inp_micro_risk, 40.0)

        med_win = self.get_safe_float(self.inp_med_win, 0.0)

        draw_len = min(self.ptr, self.max_points)
        x_draw = self.x_data[-draw_len:]

        self.curve_price.setData(x_draw, self.price_data[-draw_len:])
        self.curve_macro.setData(x_draw, self.macro_data[-draw_len:])
        self.curve_risk.setData(x_draw, self.risk_data[-draw_len:])

        # SMART PANNING: Smooth scroll while retaining user zoom
        view_rect = self.p1.viewRect()
        current_view_width = view_rect.width()
        latest_time = x_draw[-1]

        ideal_max_x = latest_time + (current_view_width * 0.15)
        ideal_min_x = ideal_max_x - current_view_width

        # Only pan if we are tracking the live edge (not browsing the past)
        if view_rect.right() < latest_time or view_rect.right() > (latest_time + current_view_width):
             self.p1.setXRange(ideal_min_x, ideal_max_x, padding=0)

        if self.pos_type != 0:
            if self.pos_type == 1:
                self.pos_line.setPen(pg.mkPen('#00FF00', width=2, style=Qt.DashLine))
            else:
                self.pos_line.setPen(pg.mkPen('#FF0000', width=2, style=Qt.DashLine))
            self.pos_line.setValue(self.pos_price)
            self.pos_line.setVisible(True)
        else:
            self.pos_line.setVisible(False)

        latest_time = x_draw[-1]
        self.lbl_clock.setText(f"MT5 TICK IDŐ: {pd.to_datetime(latest_time, unit='ms').strftime('%H:%M:%S.%f')[:-3]}")

        # New Decision Logic: Evaluate all active layers
        macro_er = self.macro_data[-1] / 100.0
        macro_risk = self.risk_data[-1]

        decision = 'GREEN'
        state_str = ""

        # Macro Level Check
        if macro_er < mac_chaos_lim:
            decision = 'RED'
            state_str = f"Makro ER ({macro_er:.2f}) < Küszöb ({mac_chaos_lim})"
        elif macro_risk >= mac_risk_lim:
            decision = 'YELLOW' if decision != 'RED' else 'RED'
            if state_str == "": state_str = f"Makro Kockázat ({macro_risk:.1f}%) > Küszöb"

        # Medium Level Check (If active)
        if med_win > 0:
            med_er = getattr(self, 'current_med_er', 0.0)
            med_risk = getattr(self, 'current_med_risk', 0.0)
            if med_er < med_chaos_lim:
                decision = 'RED'
                state_str = f"Közép ER ({med_er:.2f}) < Küszöb ({med_chaos_lim})"
            elif med_risk >= med_risk_lim:
                decision = 'YELLOW' if decision != 'RED' else 'RED'
                if state_str == "": state_str = f"Közép Kockázat ({med_risk:.1f}%) > Küszöb"

        # Micro Level Check
        mic_er = getattr(self, 'current_mic_er', 0.0)
        mic_risk = getattr(self, 'current_mic_risk', 0.0)
        if mic_er < mic_chaos_lim:
            decision = 'RED'
            state_str = f"Mikro ER ({mic_er:.2f}) < Küszöb ({mic_chaos_lim})"
        elif mic_risk >= mic_risk_lim:
            decision = 'YELLOW' if decision != 'RED' else 'RED'
            if state_str == "": state_str = f"Mikro Kockázat ({mic_risk:.1f}%) > Küszöb"

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
        reason_text = self.get_reason(decision, state_str)

        # HTML formatting for Regime
        regime_html = f"<div style='text-align: center;'><strong style='font-size: 14px;'>PIACI REZSIM</strong><br><br><span style='font-size: 15px;'>{regime_str}</span></div>"
        self.lbl_regime.setText(regime_html)
        self.lbl_regime.setStyleSheet(f"background-color: {regime_color}; border: 1px solid #555; padding: 5px; color: white;")

        # HTML formatting for Prediction
        predict_html = f"<div style='text-align: center;'><strong style='font-size: 14px;'>PREDIKCIÓ</strong><br><br><span style='font-size: 15px;'>{predict_str}</span></div>"
        self.lbl_predict.setText(predict_html)
        self.lbl_predict.setStyleSheet(f"background-color: {predict_color}; border: 1px solid #555; padding: 5px; color: white;")

        # HTML formatting for Reason
        reason_html = f"<div style='text-align: center;'><strong style='font-size: 14px;'>INDIKÁCIÓ</strong><br><br><span style='font-size: 15px;'>{reason_text}</span></div>"
        self.lbl_reason.setText(reason_html)


    def closeEvent(self, event):
        self.bridge.stop()
        event.accept()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    dashboard = VakuDashboardOnline()
    dashboard.show()
    sys.exit(app.exec_())
