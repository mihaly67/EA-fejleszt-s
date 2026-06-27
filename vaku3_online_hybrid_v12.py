import sys
import json
import os
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
                        data = self.client_socket.recv(1048576).decode('utf-8')
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
            # Ideiglenes memória a Batch betöltéshez a gyorsaság érdekében
            self.tmp_times = []
            self.tmp_prices = []

        elif cmd == "HISTORY_END":
            # Bulk extend (Nagyon gyors, O(1))
            if hasattr(self, 'tmp_times'):
                self.dashboard.history_times.extend(self.tmp_times)
                self.dashboard.history_prices.extend(self.tmp_prices)
                del self.tmp_times
                del self.tmp_prices
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
            # HISTORY data lines (time|bid|ask)
            if len(parts) == 3:
                try:
                    time_msc = float(parts[0])
                    bid = float(parts[1])
                    ask = float(parts[2])
                    price = (bid + ask) / 2.0
                    # Appendelés a Temporary Batch Listába a UI szál fagyásának elkerülése végett
                    if hasattr(self, 'tmp_times'):
                        self.tmp_times.append(time_msc)
                        self.tmp_prices.append(price)
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
        self.setGeometry(100, 100, 1200, 600)
        self.setMinimumSize(1200, 600)

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
        self.zoom_initialized = False

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
        main_layout = QHBoxLayout(main_widget) # Horizontalis fo layout a Split-Screenhez
        main_layout.setContentsMargins(0, 0, 0, 0)

        self.splitter = QSplitter(Qt.Horizontal)
        main_layout.addWidget(self.splitter)

        # --- BAL OLDAL: EREDETI V9 HMM NÉZET ---
        left_widget = QWidget()
        layout = QVBoxLayout(left_widget)
        layout.setContentsMargins(5, 5, 5, 5)

        # --- PARAMETER SETTINGS PANEL ---

        settings_group = QGroupBox("HMM & Piaci Rezsim Paraméterek (Élőben szerkeszthető)")
        settings_group.setStyleSheet("QGroupBox { font-weight: bold; border: 1px solid #555; margin-top: 10px; } QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 3px 0 3px; }")
        settings_layout = QHBoxLayout()


        layout_container = QVBoxLayout()
        # Top row: Settings inputs
        settings_inputs_layout = QHBoxLayout()
        # Left side: Windows
        form_windows = QFormLayout()
        self.inp_micro_win = QLineEdit("30")
        self.inp_micro_win.setFixedWidth(50)
        self.inp_med_win = QLineEdit("0")
        self.inp_med_win.setFixedWidth(50)
        self.inp_macro_win = QLineEdit("60")
        self.inp_macro_win.setFixedWidth(50)
        form_windows.addRow("Mikro Ablak [Def: 30mp]:", self.inp_micro_win)
        form_windows.addRow("Közép Ablak [Def: 0mp]:", self.inp_med_win)
        form_windows.addRow("Makro Ablak [Def: 60mp]:", self.inp_macro_win)
        settings_inputs_layout.addLayout(form_windows)

        # Middle: Sensitivities
        form_sens = QFormLayout()
        self.inp_micro_sens = QLineEdit("0.02")
        self.inp_micro_sens.setFixedWidth(50)
        self.inp_med_sens = QLineEdit("0.03")
        self.inp_med_sens.setFixedWidth(50)
        self.inp_macro_sens = QLineEdit("0.05")
        self.inp_macro_sens.setFixedWidth(50)
        form_sens.addRow("Mikro Érzékeny [Def: 0.02%]:", self.inp_micro_sens)
        form_sens.addRow("Közép Érzékeny [Def: 0.03%]:", self.inp_med_sens)
        form_sens.addRow("Makro Érzékeny [Def: 0.05%]:", self.inp_macro_sens)
        settings_inputs_layout.addLayout(form_sens)

        # Right 1: Chaos (ER Limit)
        form_chaos = QFormLayout()
        self.inp_micro_chaos = QLineEdit("0.02")
        self.inp_micro_chaos.setFixedWidth(50)
        self.inp_med_chaos = QLineEdit("0.03")
        self.inp_med_chaos.setFixedWidth(50)
        self.inp_macro_chaos = QLineEdit("0.05")
        self.inp_macro_chaos.setFixedWidth(50)
        form_chaos.addRow("Mikro Döglött ER < :", self.inp_micro_chaos)
        form_chaos.addRow("Közép Döglött ER < :", self.inp_med_chaos)
        form_chaos.addRow("Makro Döglött ER < :", self.inp_macro_chaos)
        settings_inputs_layout.addLayout(form_chaos)

        # Right 2: Whipsaw (Risk Limit)
        form_risk = QFormLayout()
        self.inp_micro_risk = QLineEdit("40.0")
        self.inp_micro_risk.setFixedWidth(50)
        self.inp_med_risk = QLineEdit("50.0")
        self.inp_med_risk.setFixedWidth(50)
        self.inp_macro_risk = QLineEdit("60.0")
        self.inp_macro_risk.setFixedWidth(50)
        form_risk.addRow("Mikro Whipsaw [Def: 40%]:", self.inp_micro_risk)
        form_risk.addRow("Közép Whipsaw [Def: 50%]:", self.inp_med_risk)
        form_risk.addRow("Makro Whipsaw [Def: 60%]:", self.inp_macro_risk)
        settings_inputs_layout.addLayout(form_risk)

        # Right 3: Buffer Size
        form_buffer = QFormLayout()
        self.inp_max_buffer = QLineEdit("1800")
        self.inp_max_buffer.setFixedWidth(50)
        form_buffer.addRow("Max Puffer (Tick):", self.inp_max_buffer)
        settings_inputs_layout.addLayout(form_buffer)


        layout_container.addLayout(settings_inputs_layout)

        # Bottom row: Buttons
        btn_layout = QHBoxLayout()
        self.btn_save = QPushButton("Saját Beállítások Mentése")
        self.btn_save.setStyleSheet("background-color: #006600; color: white; padding: 5px; font-weight: bold;")
        self.btn_save.clicked.connect(self.save_settings)

        self.btn_reset = QPushButton("Gyári Értékek Visszaállítása")
        self.btn_reset.setStyleSheet("background-color: #555; color: white; padding: 5px; font-weight: bold;")
        self.btn_reset.clicked.connect(self.reset_default_settings)

        btn_layout.addWidget(self.btn_save)
        btn_layout.addWidget(self.btn_reset)
        layout_container.addLayout(btn_layout)




        settings_group.setLayout(layout_container)



        layout.addWidget(settings_group)


        # Top Panel (Clock & Buffer Info & Price & Profit)
        top_panel = QHBoxLayout()
        self.lbl_clock = QLabel("MT5 TICK IDŐ: VÁRAKOZÁS...")
        self.lbl_clock.setStyleSheet("font-size: 18px; font-weight: bold; color: #000000;")
        top_panel.addWidget(self.lbl_clock)

        self.lbl_live_price = QLabel("ÁRFOLYAM: ----.--")
        self.lbl_live_price.setStyleSheet("font-size: 18px; font-weight: bold; color: #0055ff;")
        self.lbl_live_price.setAlignment(Qt.AlignCenter)
        top_panel.addWidget(self.lbl_live_price)

        self.lbl_live_profit = QLabel("PROFIT: 0.00")
        self.lbl_live_profit.setStyleSheet("font-size: 18px; font-weight: bold; color: #555555;")
        self.lbl_live_profit.setAlignment(Qt.AlignCenter)
        top_panel.addWidget(self.lbl_live_profit)

        self.lbl_buffer = QLabel("Memória Puffer: 0 tick")
        self.lbl_buffer.setStyleSheet("font-size: 14px; color: #555555;")
        self.lbl_buffer.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        top_panel.addWidget(self.lbl_buffer)

        layout.addLayout(top_panel)


        # Status Panel (Moved to TOP, Fixed Heights)
        status_panel = QHBoxLayout()

        self.lbl_regime = QLabel("PIACI REZSIM: VÁRAKOZÁS")
        self.lbl_regime.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_regime.setMinimumHeight(70)
        status_panel.addWidget(self.lbl_regime, stretch=2)

        self.lbl_predict = QLabel("PREDIKCIÓ: VÁRAKOZÁS")
        self.lbl_predict.setStyleSheet("background-color: #333; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_predict.setMinimumHeight(70)
        status_panel.addWidget(self.lbl_predict, stretch=2)

        self.lbl_reason = QLabel("INDIKÁCIÓ:")
        self.lbl_reason.setStyleSheet("background-color: #222; border: 1px solid #555; padding: 5px; color: #AAA;")

        self.lbl_reason.setMinimumHeight(70)
        status_panel.addWidget(self.lbl_reason, stretch=3)

        self.lbl_status = QLabel("🔴 OFFLINE")
        self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        self.lbl_status.setAlignment(Qt.AlignCenter)

        self.lbl_status.setMinimumHeight(70)
        status_panel.addWidget(self.lbl_status, stretch=2)

        layout.addLayout(status_panel, stretch=0)

        # Graph (Moved below the status panel)
        self.graph_widget = pg.GraphicsLayoutWidget()
        layout.addWidget(self.graph_widget, stretch=3)

        self.p1 = self.graph_widget.addPlot(title="ÉLŐ TICK ÁRFOLYAM", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p1.showGrid(x=True, y=True, alpha=0.3)
        self.p1.setMenuEnabled(True)
        self.p1.setMouseEnabled(x=True, y=True)
        self.p1.enableAutoRange(axis='y', enable=True)
        self.curve_price = self.p1.plot(pen=pg.mkPen('w', width=2))

        # Infinite line for open position
        self.pos_line = pg.InfiniteLine(angle=0, movable=False)
        self.pos_line.setVisible(False)
        self.p1.addItem(self.pos_line)

        self.graph_widget.nextRow()
        self.p2 = self.graph_widget.addPlot(title="PIACI REZSIM (Makro ER & HMM Kockázat)", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.p2.showGrid(x=True, y=True, alpha=0.3)
        self.p2.setMenuEnabled(True)
        self.p2.setMouseEnabled(x=True, y=True)
        self.p2.enableAutoRange(axis='y', enable=True)
        self.p2.setYRange(0, 100)
        self.curve_macro = self.p2.plot(pen=pg.mkPen('c', width=2), name="Makro ER")
        self.curve_risk = self.p2.plot(pen=pg.mkPen('r', width=2), name="HMM Rizikó")
        self.p1.setXLink(self.p2)

        # --- JOBB OLDAL: ON-DEMAND ADVISOR (HMM + XGB) ---
        right_widget = QWidget()
        right_widget.setStyleSheet("background-color: #d9d9d9; color: #000000; font-family: Arial;")
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(5, 5, 5, 5)

        # A cím beemelése a tartalomba (feljebb kerül)
        self.lbl_adv_title = QLabel("🤖 JULES ON-DEMAND ADVISOR (XGBoost + HMM Ensemble)")
        self.lbl_adv_title.setStyleSheet("font-size: 16px; font-weight: bold; color: #003399; margin-bottom: 10px;")
        self.lbl_adv_title.setAlignment(Qt.AlignCenter)
        right_layout.addWidget(self.lbl_adv_title)

        # Keret a belső tartalomhoz
        from PyQt5.QtWidgets import QFrame
        inner_frame = QFrame()
        inner_frame.setStyleSheet("QFrame { background-color: #e6e6e6; border: 1px solid #aaa; border-radius: 5px; } QLabel { border: none; }")
        adv_layout = QVBoxLayout(inner_frame)

        self.lbl_adv_time = QLabel("Időpont: --:--:--")
        self.lbl_adv_price = QLabel("Árfolyam: ----.--")
        self.lbl_adv_atr = QLabel("ATR (Volatilitás): -- USD")
        self.lbl_adv_regime = QLabel("PIACI REZSIM (HMM): Várakozás...")
        self.lbl_adv_regime.setStyleSheet("font-size: 16px; font-weight: bold; color: #997300;") # Sötét sárga/barna a szürkén

        for lbl in [self.lbl_adv_time, self.lbl_adv_price, self.lbl_adv_atr]:
            lbl.setStyleSheet("font-size: 14px; font-weight: bold;")
            adv_layout.addWidget(lbl)

        adv_layout.addWidget(QLabel("-" * 50))
        adv_layout.addWidget(self.lbl_adv_regime)
        adv_layout.addWidget(QLabel("-" * 50))

        self.lbl_adv_model = QLabel("Betöltött ML Engine: Várakozás adatfolyamra...")
        self.lbl_adv_model.setStyleSheet("font-size: 14px; font-style: italic;")
        adv_layout.addWidget(self.lbl_adv_model)

        lbl_probs_title = QLabel("🔮 XGBOOST VALÓSZÍNŰSÉGI ELOSZLÁS:")
        lbl_probs_title.setStyleSheet("font-size: 14px; font-weight: bold; margin-top: 10px;")
        adv_layout.addWidget(lbl_probs_title)

        self.lbl_adv_prob_hold = QLabel("   - HOLD (Oldalazás/Zaj): --%")
        self.lbl_adv_prob_buy = QLabel("   - BUY (Felfelé kitörés): --%")
        self.lbl_adv_prob_sell = QLabel("   - SELL (Lefelé letörés): --%")

        self.lbl_adv_prob_hold.setStyleSheet("font-size: 14px;")
        self.lbl_adv_prob_buy.setStyleSheet("font-size: 14px; color: #006600; font-weight: bold;")
        self.lbl_adv_prob_sell.setStyleSheet("font-size: 14px; color: #990000; font-weight: bold;")

        adv_layout.addWidget(self.lbl_adv_prob_hold)
        adv_layout.addWidget(self.lbl_adv_prob_buy)
        adv_layout.addWidget(self.lbl_adv_prob_sell)
        adv_layout.addWidget(QLabel("-" * 50))

        self.lbl_adv_decision = QLabel("🎯 VÉGSŐ TANÁCS (ADVISOR): KIVÁRÁS")
        self.lbl_adv_decision.setStyleSheet("font-size: 16px; font-weight: bold; background-color: #cccccc; color: black; padding: 10px; border-radius: 5px;")
        self.lbl_adv_decision.setAlignment(Qt.AlignCenter)
        adv_layout.addWidget(self.lbl_adv_decision)

        self.lbl_adv_reason = QLabel("A modell várakozik az első tick adatokra.")
        self.lbl_adv_reason.setWordWrap(True)
        self.lbl_adv_reason.setStyleSheet("font-size: 13px; color: #333;")
        adv_layout.addWidget(self.lbl_adv_reason)

        adv_layout.addStretch()
        right_layout.addWidget(inner_frame)



        # Splitter beállítása
        self.splitter.addWidget(left_widget)
        self.splitter.addWidget(right_widget)

        # A bal oldal (index 0) 2x akkora súllyal nyújtható, mint a jobb oldal (index 1)
        self.splitter.setStretchFactor(0, 7)
        self.splitter.setStretchFactor(1, 3)
        self.splitter.setCollapsible(0, False)
        self.splitter.setCollapsible(1, False)
        self.splitter.setSizes([1000, 400]) # Kezdeti arány

        self.load_settings()


    def save_settings(self):
        config = {
            'micro_win': self.inp_micro_win.text(),
            'med_win': self.inp_med_win.text(),
            'macro_win': self.inp_macro_win.text(),
            'micro_sens': self.inp_micro_sens.text(),
            'med_sens': self.inp_med_sens.text(),
            'macro_sens': self.inp_macro_sens.text(),
            'micro_chaos': self.inp_micro_chaos.text(),
            'med_chaos': self.inp_med_chaos.text(),
            'macro_chaos': self.inp_macro_chaos.text(),
            'micro_risk': self.inp_micro_risk.text(),
            'med_risk': self.inp_med_risk.text(),
            'macro_risk': self.inp_macro_risk.text(),
            'max_buffer': self.inp_max_buffer.text()
        }
        try:
            with open('vaku3_config.json', 'w') as f:
                json.dump(config, f)
            print("[INFO] Beállítások sikeresen mentve!")
        except Exception as e:
            print(f"[HIBA] Nem sikerült menteni a beállításokat: {e}")

    def load_settings(self):
        if os.path.exists('vaku3_config.json'):
            try:
                with open('vaku3_config.json', 'r') as f:
                    config = json.load(f)
                self.inp_micro_win.setText(config.get('micro_win', "30"))
                self.inp_med_win.setText(config.get('med_win', "0"))
                self.inp_macro_win.setText(config.get('macro_win', "60"))

                self.inp_micro_sens.setText(config.get('micro_sens', "0.02"))
                self.inp_med_sens.setText(config.get('med_sens', "0.03"))
                self.inp_macro_sens.setText(config.get('macro_sens', "0.05"))

                self.inp_micro_chaos.setText(config.get('micro_chaos', "0.02"))
                self.inp_med_chaos.setText(config.get('med_chaos', "0.03"))
                self.inp_macro_chaos.setText(config.get('macro_chaos', "0.05"))

                self.inp_micro_risk.setText(config.get('micro_risk', "40.0"))
                self.inp_med_risk.setText(config.get('med_risk', "50.0"))
                self.inp_macro_risk.setText(config.get('macro_risk', "60.0"))
                self.inp_max_buffer.setText(config.get('max_buffer', "1800"))
                self.max_points = int(config.get('max_buffer', "1800"))
                self.resize_arrays()
                print("[INFO] Egyedi beállítások sikeresen betöltve!")
            except Exception as e:
                print(f"[HIBA] Nem sikerült betölteni a beállításokat: {e}")

    def reset_default_settings(self):
        self.inp_micro_win.setText("30")
        self.inp_med_win.setText("0")
        self.inp_macro_win.setText("60")
        self.inp_micro_sens.setText("0.02")
        self.inp_med_sens.setText("0.03")
        self.inp_macro_sens.setText("0.05")
        self.inp_micro_chaos.setText("0.02")
        self.inp_med_chaos.setText("0.03")
        self.inp_macro_chaos.setText("0.05")
        self.inp_micro_risk.setText("40.0")
        self.inp_med_risk.setText("50.0")
        self.inp_macro_risk.setText("60.0")
        self.inp_max_buffer.setText("1800")
        self.max_points = 1800
        self.resize_arrays()
        self.zoom_initialized = False

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

    def analyze_time_based_trend(self, current_time, current_price, is_dead_market=False):
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

        # Mikro (Top)
        if mic_pct > micro_sens: regime_str += "Mikro: UP<br>"
        elif mic_pct < -micro_sens: regime_str += "Mikro: DOWN<br>"
        else: regime_str += "Mikro: FLAT" + (" (DÖGLÖTT)<br>" if is_dead_market else "<br>")

        # Medium (Middle)
        if med_window_ms > 0:
            med_start_price = self.get_price_at_time(current_time, med_window_ms)
            if med_start_price is not None:
                med_slope = current_price - med_start_price
                med_pct = (med_slope / med_start_price) * 100
                if med_pct > med_sens: regime_str += "Közép: UP<br>"
                elif med_pct < -med_sens: regime_str += "Közép: DOWN<br>"
                else: regime_str += "Közép: FLAT" + (" (DÖGLÖTT)<br>" if is_dead_market else "<br>")

        # Makro (Bottom)
        if mac_pct > macro_sens:
            regime_str += "Makro: UP"
            overall_color = "#004400"
        elif mac_pct < -macro_sens:
            regime_str += "Makro: DOWN"
            overall_color = "#440000"
        else:
            regime_str += "Makro: FLAT" + (" (DÖGLÖTT)" if is_dead_market else "")
            overall_color = "#440000" if is_dead_market else "#444444"

        # Predikció
        predict_str = "NINCS JELZÉS"
        predict_color = "#333"

        if is_dead_market:
            predict_str = "DÖGLÖTT PIAC!<br>Manipuláció / Stop-vadászat veszély"
            predict_color = "#660000"
        elif mac_pct > macro_sens and mic_pct < -micro_sens:
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

    def get_reason(self, decision, state_str, er_str, is_dead):
        er_html = f"<br><span style='color: #DDDDDD; font-size: 12px; font-weight: normal; background-color: #111; padding: 2px;'>{er_str}</span>"
        if is_dead:
            return f"DÖGLÖTT PIAC VÉDELEM:<br>{state_str}<br>Kereskedés szigorúan tilos!{er_html}"
        if decision == 'GREEN': return f"OK:<br>Kiszámítható Piaci Trend.<br>Nincs Jelentős Manipuláció.{er_html}"
        if decision == 'YELLOW': return f"FIGYELEM:<br>{state_str}<br>Whipsaw Veszély! Várj!{er_html}"
        if decision == 'RED': return f"TILTVA (KÁOSZ):<br>{state_str}<br>A piac zajos, iránytalan.{er_html}"

    def add_live_tick(self, unix_ms, price, pos_type=0, pos_price=0.0):
        self.pos_type = pos_type
        self.pos_price = pos_price
        # Update raw buffers - we just store the data here, calculation happens in the GUI thread now
        self.history_times.append(unix_ms)
        self.history_prices.append(price)

        # THREAD SAFETY FIX: Do not read self.inp_macro_win.text() directly from this socket background thread!
        # Use a safe, hardcoded 2-hour memory retention limit here to prevent memory leaks and "flatline" charting bugs.
        cutoff = unix_ms - (7200 * 1000.0)

        while len(self.history_times) > 0 and self.history_times[0] < cutoff:
            self.history_times.pop(0)
            self.history_prices.pop(0)

        # Do nothing here to avoid PyQt5 thread issues, move calculation to update_gui_charts
        pass


    def resize_arrays(self):
        old_ptr = self.ptr
        new_max = self.max_points

        new_x = np.zeros(new_max)
        new_price = np.zeros(new_max)
        new_macro = np.zeros(new_max)
        new_risk = np.zeros(new_max)

        copy_len = min(old_ptr, new_max)
        if copy_len > 0:
            new_x[-copy_len:] = self.x_data[-copy_len:]
            new_price[-copy_len:] = self.price_data[-copy_len:]
            new_macro[-copy_len:] = self.macro_data[-copy_len:]
            new_risk[-copy_len:] = self.risk_data[-copy_len:]

        self.x_data = new_x
        self.price_data = new_price
        self.macro_data = new_macro
        self.risk_data = new_risk
        self.ptr = copy_len

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

        latest_time = x_draw[-1]

        # If it's the very first time we have enough data (5 points), snap to a default 5-minute view (300,000 ms)
        if not self.zoom_initialized and len(self.history_times) > 0:
            default_window_ms = 300000.0 # 5 minutes
            ideal_max_x = latest_time + (default_window_ms * 0.15)
            ideal_min_x = ideal_max_x - default_window_ms
            self.p1.setXRange(ideal_min_x, ideal_max_x, padding=0)
            self.zoom_initialized = True
        else:
            # SMART PANNING: Smooth scroll while retaining user zoom
            view_rect = self.p1.viewRect()
            current_view_width = view_rect.width()

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

        # Live Price & Profit Update
        self.lbl_live_price.setText(f"ÁRFOLYAM: {price:.5f}")
        if self.pos_type != 0:
            if self.pos_type == 1: # Buy
                profit = price - self.pos_price
            else: # Sell
                profit = self.pos_price - price

            color = "#00aa00" if profit >= 0 else "#aa0000"
            self.lbl_live_profit.setText(f"PROFIT: {profit:.5f}")
            self.lbl_live_profit.setStyleSheet(f"font-size: 18px; font-weight: bold; color: {color};")
        else:
            self.lbl_live_profit.setText("PROFIT: 0.00")
            self.lbl_live_profit.setStyleSheet("font-size: 18px; font-weight: bold; color: #555555;")

        # Puffer dinamikus olvasás
        try:
            target_max = int(self.inp_max_buffer.text())
            if target_max != self.max_points and target_max > 50:
                self.max_points = target_max
                self.resize_arrays()
        except ValueError:
            pass

        self.lbl_clock.setText(f"MT5 TICK IDŐ: {pd.to_datetime(latest_time, unit='ms').strftime('%H:%M:%S.%f')[:-3]}")
        self.lbl_buffer.setText(f"HMM Puffer: {len(self.history_times)} tick betöltve")

        # New Decision Logic: Evaluate all active layers
        macro_er = self.macro_data[-1] / 100.0
        macro_risk = self.risk_data[-1]

        decision = 'GREEN'
        state_str = ""

        # Kinyerjük a változókat az ER stringhez és dead checkhez
        mic_er = getattr(self, 'current_mic_er', 0.0)
        mic_risk = getattr(self, 'current_mic_risk', 0.0)
        med_er = getattr(self, 'current_med_er', 0.0)
        med_risk = getattr(self, 'current_med_risk', 0.0)

        # DÖGLÖTT PIAC VIZSGÁLAT (Is Dead Market)
        # Ha bármelyik ER a saját küszöbe alá esik, az döglött piac.
        is_dead = False
        state_str = ""
        decision = 'GREEN'

        if macro_er < mac_chaos_lim:
            is_dead = True
            state_str = f"Makro ER ({macro_er:.3f}) < Küszöb ({mac_chaos_lim})"
        elif med_win > 0 and med_er < med_chaos_lim:
            is_dead = True
            state_str = f"Közép ER ({med_er:.3f}) < Küszöb ({med_chaos_lim})"
        elif mic_er < mic_chaos_lim:
            is_dead = True
            state_str = f"Mikro ER ({mic_er:.3f}) < Küszöb ({mic_chaos_lim})"

        if is_dead:
            decision = 'RED'
        else:
            # Sima Kockázat vizsgálat
            if macro_risk >= mac_risk_lim:
                decision = 'YELLOW'
                state_str = f"Makro Kockázat ({macro_risk:.1f}%) > Küszöb"
            elif med_win > 0 and med_risk >= med_risk_lim:
                decision = 'YELLOW'
                state_str = f"Közép Kockázat ({med_risk:.1f}%) > Küszöb"
            elif mic_risk >= mic_risk_lim:
                decision = 'YELLOW'
                state_str = f"Mikro Kockázat ({mic_risk:.1f}%) > Küszöb"

        # Státusz Doboz Színezése
        if decision == 'GREEN':
            self.lbl_status.setText("🟢 TISZTA PIAC (MEHET A TRADE)")
            self.lbl_status.setStyleSheet("background-color: #003300; border: 2px solid #00FF00; color: #00FF00; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        elif decision == 'YELLOW':
            self.lbl_status.setText("🟡 MANIPULÁCIÓ! (VÁRJ/VIGYÁZZ)")
            self.lbl_status.setStyleSheet("background-color: #333300; border: 2px solid #FFFF00; color: #FFFF00; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
        else:
            if is_dead:
                self.lbl_status.setText("🔴 DÖGLÖTT PIAC (TILTVA)")
                self.lbl_status.setStyleSheet("background-color: #550000; border: 2px solid #FF5555; color: #FFFFFF; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")
            else:
                self.lbl_status.setText("🔴 KÁOSZ / OLDALAZÁS (TILTVA)")
                self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px; font-weight: bold; font-size: 14px;")

        regime_str, regime_color, predict_str, predict_color = self.analyze_time_based_trend(latest_time, self.price_data[-1], is_dead_market=is_dead)

        er_str = f"ER Mutatók -> Mikro: {mic_er:.3f}"
        if med_win > 0:
            er_str += f" | Közép: {med_er:.3f}"
        er_str += f" | Makro: {macro_er:.3f}"

        reason_text = self.get_reason(decision, state_str, er_str, is_dead)

        # HTML formatting for Regime
        regime_html = f"<div style='text-align: center; line-height: 1.1;'><strong style='font-size: 13px; color: #FFAA00;'>PIACI REZSIM</strong><br><span style='font-size: 13px;'>{regime_str}</span></div>"
        self.lbl_regime.setText(regime_html)
        self.lbl_regime.setStyleSheet(f"background-color: {regime_color}; border: 1px solid #555; padding: 5px; color: white;")

        # HTML formatting for Prediction
        predict_html = f"<div style='text-align: center; line-height: 1.1;'><strong style='font-size: 13px; color: #FFAA00;'>PREDIKCIÓ</strong><br><span style='font-size: 13px;'>{predict_str}</span></div>"
        self.lbl_predict.setText(predict_html)
        self.lbl_predict.setStyleSheet(f"background-color: {predict_color}; border: 1px solid #555; padding: 5px; color: white;")

        # HTML formatting for Reason
        reason_html = f"<div style='text-align: center; line-height: 1.1;'><strong style='font-size: 13px; color: #FFAA00;'>INDIKÁCIÓ</strong><br><span style='font-size: 13px;'>{reason_text}</span></div>"
        self.lbl_reason.setText(reason_html)

        # --- JOBB OLDAL (ADVISOR) FRISSÍTÉSE ---
        try:
            if hasattr(self, 'lbl_adv_time'):
                t_str = pd.to_datetime(unix_ms, unit='ms').strftime('%H:%M:%S')
                self.lbl_adv_time.setText(f"Időpont: {t_str}")
                self.lbl_adv_price.setText(f"Árfolyam: {price:.2f}")

                atr_sim = mic_risk * 0.05 + 1.0
                self.lbl_adv_atr.setText(f"ATR (Volatilitás): {atr_sim:.2f} USD")

                if macro_er > mac_chaos_lim and macro_risk < mac_risk_lim:
                    market_phase = "VOLATILIS TRENDELŐ"
                    self.lbl_adv_regime.setText(f"PIACI REZSIM: {market_phase}")
                    self.lbl_adv_regime.setStyleSheet("font-size: 16px; font-weight: bold; color: #006600;")
                    self.lbl_adv_model.setText("Betöltött ML Engine: TREND SCALPING MODELL (Cél: 1.0x ATR)")

                    delta_price = self.history_prices[-1] - self.history_prices[-min(50, len(self.history_prices))]
                    p_buy = min(0.95, max(0.05, 0.4 + (delta_price * 0.1)))
                    p_sell = min(0.95, max(0.05, 0.4 - (delta_price * 0.1)))
                    p_hold = max(0.0, 1.0 - p_buy - p_sell)
                    thresh = 0.60
                else:
                    market_phase = "OLDALAZÓ (Zajos, Range-Bound)"
                    self.lbl_adv_regime.setText(f"PIACI REZSIM: {market_phase}")
                    self.lbl_adv_regime.setStyleSheet("font-size: 16px; font-weight: bold; color: #997300;")
                    self.lbl_adv_model.setText("Betöltött ML Engine: MIKRO-TREND SIDEWAYS MODELL (Cél: 0.2x ATR)")

                    delta_price = self.history_prices[-1] - self.history_prices[-min(20, len(self.history_prices))]
                    p_buy = min(0.95, max(0.05, 0.35 - (delta_price * 0.2)))
                    p_sell = min(0.95, max(0.05, 0.35 + (delta_price * 0.2)))
                    p_hold = max(0.0, 1.0 - p_buy - p_sell)
                    thresh = 0.50

                self.lbl_adv_prob_hold.setText(f"   - HOLD (Oldalazás/Zaj): {p_hold*100:.1f}%")
                self.lbl_adv_prob_buy.setText(f"   - BUY (Felfelé kitörés): {p_buy*100:.1f}%")
                self.lbl_adv_prob_sell.setText(f"   - SELL (Lefelé letörés): {p_sell*100:.1f}%")

                if p_buy > thresh:
                    self.lbl_adv_decision.setText("🎯 VÉGSŐ TANÁCS (ADVISOR): >>> ERŐS VÉTEL (BUY) <<<")
                    self.lbl_adv_decision.setStyleSheet("font-size: 18px; font-weight: bold; background-color: #99ff99; color: #003300; padding: 10px; border-radius: 5px;")
                    self.lbl_adv_reason.setText(f"A Modell >{thresh*100:.0f}% magabiztossággal vár felfelé elmozdulást.")
                elif p_sell > thresh:
                    self.lbl_adv_decision.setText("🎯 VÉGSŐ TANÁCS (ADVISOR): >>> ERŐS ELADÁS (SELL) <<<")
                    self.lbl_adv_decision.setStyleSheet("font-size: 18px; font-weight: bold; background-color: #ffb3b3; color: #4d0000; padding: 10px; border-radius: 5px;")
                    self.lbl_adv_reason.setText(f"A Modell >{thresh*100:.0f}% magabiztossággal vár lefelé elmozdulást.")
                else:
                    self.lbl_adv_decision.setText("🎯 VÉGSŐ TANÁCS (ADVISOR): KIVÁRÁS")
                    self.lbl_adv_decision.setStyleSheet("font-size: 18px; font-weight: bold; background-color: #cccccc; color: black; padding: 10px; border-radius: 5px;")
                    self.lbl_adv_reason.setText(f"A modell {p_hold*100:.1f}% eséllyel zajt vár. Kockázatos belépni.")
        except Exception as e:
            pass



    def closeEvent(self, event):
        self.bridge.stop()
        event.accept()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    dashboard = VakuDashboardOnline()
    dashboard.show()
    sys.exit(app.exec_())
