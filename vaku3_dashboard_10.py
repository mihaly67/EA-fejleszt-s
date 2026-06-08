import sys
import numpy as np
import pandas as pd
import time
import os

from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout,
                             QWidget, QLabel, QGridLayout, QPushButton, QComboBox, QSlider)
from PyQt5.QtCore import QTimer, Qt
from PyQt5.QtGui import QColor, QFont
import pyqtgraph as pg

# Ehelyett behúzzuk az új modort
from vaku3_online_hybrid import HybridStreamingEngine

class TimeAxisItem(pg.AxisItem):
    def tickStrings(self, values, scale, spacing):
        return [pd.to_datetime(value, unit='ms').strftime('%H:%M:%S') for value in values]

class RealDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0
        self.instrument_name = "ISMERETLEN"

        filename = os.path.basename(file_path)
        if "XAUUSD" in filename or "GOLD" in filename.upper(): self.instrument_name = "XAUUSD"
        elif "EURUSD" in filename: self.instrument_name = "EURUSD"
        elif "SPY" in filename: self.instrument_name = "SPY"

    def load_data(self):
        print(f"Adatok betöltése memóriába: {self.file_path}")
        self.df = pd.read_csv(self.file_path)

        time_cols = [c for c in self.df.columns if c.lower() in ['timemsc', 'time_msc', 'tickmsc', 'time']]
        if time_cols:
            self.t_col = time_cols[0]
            if pd.api.types.is_string_dtype(self.df[self.t_col]):
                self.df[self.t_col] = pd.to_datetime(self.df[self.t_col]).astype(np.int64) // 10**6
        else:
             print("Nincs időoszlop")
             sys.exit()

        if 'Price' not in self.df.columns:
            if 'Ask' in self.df.columns and 'Bid' in self.df.columns:
                 self.df['Price'] = (self.df['Ask'] + self.df['Bid']) / 2.0
            else:
                 self.df['Price'] = self.df.iloc[:, 1]

        if 'Spread' not in self.df.columns:
            if 'Ask' in self.df.columns and 'Bid' in self.df.columns:
                self.df['Spread'] = self.df['Ask'] - self.df['Bid']
            else:
                self.df['Spread'] = 1.0

        self.df = self.df.sort_values(by=self.t_col).reset_index(drop=True)
        print(f"Betöltve {len(self.df)} tick.")

    def get_start_time_ms(self):
        if self.df is not None and not self.df.empty:
            return float(self.df.iloc[0][self.t_col])
        return 0.0

    def peek_next_tick_time(self):
        if self.current_idx < len(self.df):
            return float(self.df.iloc[self.current_idx][self.t_col])
        return None

    def get_next_tick(self):
        if self.current_idx < len(self.df):
            row = self.df.iloc[self.current_idx]
            self.current_idx += 1
            return row
        return None

class Vaku3Dashboard(QMainWindow):
    def __init__(self, file_path):
        super().__init__()

        self.setWindowTitle("Vaku 3.0 ML Pipeline - 3-State HMM (CT-HMM/Rolling) Dashboard")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet("background-color: #121212; color: #FFFFFF;")

        self.stream = RealDataStream(file_path)
        self.stream.load_data()

        self.engine = HybridStreamingEngine()

        # UI Setup
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.main_layout = QVBoxLayout(self.central_widget)

        self.setup_header()
        self.setup_status_panels()
        self.setup_charts()
        self.setup_controls()

        # State setup
        self.playback_speed_multiplier = 1.0
        self.is_paused = False

        self.virtual_clock_ms = self.stream.get_start_time_ms()
        self.last_update_wall_time = time.perf_counter()

        # Data buffers for plotting
        self.display_points = 500
        self.x_data = np.zeros(self.display_points)
        self.price_data = np.zeros(self.display_points)
        self.macro_data = np.zeros(self.display_points)
        self.risk_data = np.zeros(self.display_points)

        # Pre-fill X with virtual clock starting point
        self.x_data.fill(self.virtual_clock_ms)
        self.ptr = 0

        # Engine counters
        self.total_ticks = 0
        self.macro_window_ms = 5 * 60 * 1000

        # UI Timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_dashboard)
        self.timer.start(16)  # ~60 FPS

    def setup_header(self):
        header_layout = QHBoxLayout()
        title = QLabel("VAKU 3.0 PREDICTIVE ML PIPELINE")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        header_layout.addWidget(title)

        self.lbl_clock = QLabel("SZIMULÁLT ÓRA: 00:00:00")
        self.lbl_clock.setFont(QFont("Arial", 12))
        header_layout.addWidget(self.lbl_clock, alignment=Qt.AlignRight)

        self.main_layout.addLayout(header_layout)

    def setup_status_panels(self):
        panel_layout = QGridLayout()

        # Traffic Light
        self.lbl_traffic_light = QLabel("NO TRADE")
        self.lbl_traffic_light.setFont(QFont("Arial", 24, QFont.Bold))
        self.lbl_traffic_light.setAlignment(Qt.AlignCenter)
        self.lbl_traffic_light.setStyleSheet("background-color: #555555; color: white; padding: 20px; border-radius: 10px;")
        panel_layout.addWidget(self.lbl_traffic_light, 0, 0, 2, 1)

        # Macro State
        self.lbl_macro = QLabel("PIACI ÁLLAPOT: VÁRAKOZÁS")
        self.lbl_macro.setFont(QFont("Arial", 12))
        self.lbl_macro.setStyleSheet("background-color: #222222; padding: 10px;")
        panel_layout.addWidget(self.lbl_macro, 0, 1)

        # HMM State
        self.lbl_hmm = QLabel("HMM REZSIM: ISMERETLEN")
        self.lbl_hmm.setFont(QFont("Arial", 12))
        self.lbl_hmm.setStyleSheet("background-color: #222222; padding: 10px;")
        panel_layout.addWidget(self.lbl_hmm, 1, 1)

        # Explanation
        self.lbl_reason = QLabel("INDOKLÁS: Rendszer inicializálása folyamatban...")
        self.lbl_reason.setFont(QFont("Arial", 10))
        self.lbl_reason.setWordWrap(True)
        self.lbl_reason.setStyleSheet("background-color: #222222; padding: 10px; border-left: 5px solid #FFAA00;")
        panel_layout.addWidget(self.lbl_reason, 0, 2, 2, 1)

        self.main_layout.addLayout(panel_layout)

    def setup_charts(self):
        pg.setConfigOptions(antialias=True)

        # Price Chart
        self.pw_price = pg.PlotWidget(title=f"Nyers Árfolyam Tickek ({self.stream.instrument_name})", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.pw_price.showGrid(x=True, y=True, alpha=0.3)
        self.plot_price = self.pw_price.plot(pen=pg.mkPen('w', width=2))
        self.main_layout.addWidget(self.pw_price, stretch=2)

        # Sub-charts layout
        sub_layout = QHBoxLayout()

        # Macro Chart
        self.pw_macro = pg.PlotWidget(title="Efficiency Ratio (Makro & Mikro) & Spread", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.pw_macro.showGrid(x=True, y=True, alpha=0.3)
        self.plot_macro = self.pw_macro.plot(pen=pg.mkPen('c', width=2), name="Macro ER")
        sub_layout.addWidget(self.pw_macro, stretch=1)

        # Risk Chart
        self.pw_risk = pg.PlotWidget(title="Prediktív 'Calm/Oldalazás' Veszély (%)", axisItems={'bottom': TimeAxisItem(orientation='bottom')})
        self.pw_risk.showGrid(x=True, y=True, alpha=0.3)
        self.pw_risk.setYRange(0, 100)
        self.plot_risk = self.pw_risk.plot(pen=pg.mkPen('r', width=2), fillLevel=0, brush=(255,0,0,50))

        self.risk_threshold_line = pg.InfiniteLine(angle=0, pen=pg.mkPen('y', style=Qt.DashLine))
        self.risk_threshold_line.setValue(20.0)
        self.pw_risk.addItem(self.risk_threshold_line)

        sub_layout.addWidget(self.pw_risk, stretch=1)

        self.main_layout.addLayout(sub_layout, stretch=1)

    def setup_controls(self):
        ctrl_layout = QHBoxLayout()

        self.btn_pause = QPushButton("PAUSE")
        self.btn_pause.setCheckable(True)
        self.btn_pause.clicked.connect(self.toggle_pause)
        ctrl_layout.addWidget(self.btn_pause)

        self.combo_speed = QComboBox()
        self.combo_speed.addItems(["1x (Valós idő)", "5x", "10x", "50x", "100x", "MAX (Stress Test)"])
        self.combo_speed.setCurrentIndex(2) # Default 10x
        self.combo_speed.currentIndexChanged.connect(self.change_speed)
        ctrl_layout.addWidget(self.combo_speed)

        self.main_layout.addLayout(ctrl_layout)
        self.change_speed()

    def toggle_pause(self):
        self.is_paused = self.btn_pause.isChecked()
        self.btn_pause.setText("PLAY" if self.is_paused else "PAUSE")
        if not self.is_paused:
            self.last_update_wall_time = time.perf_counter()

    def change_speed(self):
        idx = self.combo_speed.currentIndex()
        speeds = [1.0, 5.0, 10.0, 50.0, 100.0, 999999.0]
        self.playback_speed_multiplier = speeds[idx]

    def update_dashboard(self):
        if self.is_paused:
            self.last_update_wall_time = time.perf_counter()
            return

        current_wall_time = time.perf_counter()
        delta_wall_time = current_wall_time - self.last_update_wall_time
        self.last_update_wall_time = current_wall_time

        self.virtual_clock_ms += (delta_wall_time * 1000.0) * self.playback_speed_multiplier
        self.lbl_clock.setText(f"SZIMULÁLT ÓRA: {pd.to_datetime(self.virtual_clock_ms, unit='ms').strftime('%H:%M:%S.%f')[:-3]}")

        ticks_processed_this_frame = 0
        has_new_data = False
        max_ticks_per_frame = 100 if self.playback_speed_multiplier < 10000 else 1000

        while ticks_processed_this_frame < max_ticks_per_frame:
            next_tick_time = self.stream.peek_next_tick_time()
            if next_tick_time is None or next_tick_time > self.virtual_clock_ms:
                break

            row = self.stream.get_next_tick()
            try:
                unix_ms = float(row[self.stream.t_col])
            except ValueError:
                unix_ms = pd.to_datetime(row[self.stream.t_col]).timestamp() * 1000.0
            price = float(row['Price'])
            spread = float(row['Spread'])

            # 1. Hibrid Motor etetése
            self.engine.time_buffer.push(unix_ms)
            self.engine.price_buffer.push(price)
            self.engine.spread_buffer.push(spread)
            self.total_ticks += 1

            if self.total_ticks < self.engine.micro_window:
                ticks_processed_this_frame += 1
                continue

            # Features & Training
            log_return, avg_spread, tick_density = self.engine.get_micro_features()
            macro_er = abs(log_return) * 100.0
            obs = [log_return, avg_spread, tick_density]
            self.engine.training_buffer.append(obs)

            if len(self.engine.training_buffer) > 300:
                self.engine.training_buffer.pop(0)

            if self.total_ticks % 50 == 0 and len(self.engine.training_buffer) == 300:
                self.engine.fit_and_map_hmm(np.array(self.engine.training_buffer))

            # Prediction
            risk = 0.0
            current_state_name = "N/A"
            decision = "NO TRADE"
            confidence = 0.0

            if self.engine.is_hmm_trained:
                 state_id, risk, confidence = self.engine.predict_future_state(np.array(self.engine.training_buffer))
                 for name, sid in self.engine.state_map.items():
                     if sid == state_id:
                         current_state_name = name

                 # Logic mapping
                 if confidence < 80.0:
                     decision = "NO TRADE"
                 elif current_state_name in ["ImpulsiveUp", "ImpulsiveDown"]:
                     if risk < 20.0:
                         decision = "GREEN"
                     else:
                         decision = "YELLOW"
                 else:
                     decision = "RED"

            # Adatok frissítése GUI-hoz
            self.x_data[:-1] = self.x_data[1:]
            self.x_data[-1] = unix_ms

            self.price_data[:-1] = self.price_data[1:]
            self.price_data[-1] = price

            self.macro_data[:-1] = self.macro_data[1:]
            self.macro_data[-1] = macro_er

            self.risk_data[:-1] = self.risk_data[1:]
            self.risk_data[-1] = risk

            self.ptr += 1
            ticks_processed_this_frame += 1
            has_new_data = True

            # Csak minden X-edik ticknél frissítjük a szöveges panelt a performancia miatt
            if self.ptr % 5 == 0:
                self.update_labels(decision, current_state_name, confidence, risk)

        if has_new_data:
            # 25% Right Margin (Hagyunk helyet a jövőnek a grafikonon)
            x_min = self.x_data[0]
            x_max = self.x_data[-1]
            x_range = x_max - x_min
            right_padding = x_range * 0.25

            self.pw_price.setXRange(x_min, x_max + right_padding)
            self.pw_macro.setXRange(x_min, x_max + right_padding)
            self.pw_risk.setXRange(x_min, x_max + right_padding)

            self.plot_price.setData(self.x_data, self.price_data)
            self.plot_macro.setData(self.x_data, self.macro_data)
            self.plot_risk.setData(self.x_data, self.risk_data)

    def update_labels(self, decision, state_name, confidence, risk):
        if decision == 'GREEN':
            self.lbl_traffic_light.setText("🟢 ENGEDÉLYEZETT")
            self.lbl_traffic_light.setStyleSheet("background-color: #00AA00; color: white; padding: 20px; border-radius: 10px;")
            self.lbl_reason.setText(f"INDOKLÁS: Tiszta impulzív piac ({state_name}). Kicsi esély a visszarendeződésre/oldalazásra ({risk:.1f}%). Belépés javasolt!")
            self.lbl_reason.setStyleSheet("background-color: #222222; padding: 10px; border-left: 5px solid #00AA00;")
        elif decision == 'YELLOW':
            self.lbl_traffic_light.setText("🟡 VESZÉLY / KISZÁLLÓ")
            self.lbl_traffic_light.setStyleSheet("background-color: #DDDD00; color: black; padding: 20px; border-radius: 10px;")
            self.lbl_reason.setText(f"INDOKLÁS: Trendelő ({state_name}), DE a HMM predikciós Mátrixa megnövekedett esélyt lát ({risk:.1f}%) a nyugalomba/oldalazásba (Calm) való visszaesésre. Profit realizálás javasolt!")
            self.lbl_reason.setStyleSheet("background-color: #222222; padding: 10px; border-left: 5px solid #DDDD00;")
        elif decision == 'RED':
            self.lbl_traffic_light.setText("🔴 TILTOTT (CALM)")
            self.lbl_traffic_light.setStyleSheet("background-color: #AA0000; color: white; padding: 20px; border-radius: 10px;")
            self.lbl_reason.setText("INDOKLÁS: A piac 'Calm' (nyugodt/oldalazó) állapotban van. A Spread megeszi a hasznot. Skalpolni szigorúan tilos!")
            self.lbl_reason.setStyleSheet("background-color: #222222; padding: 10px; border-left: 5px solid #AA0000;")
        else:
            self.lbl_traffic_light.setText("⚪ NO TRADE")
            self.lbl_traffic_light.setStyleSheet("background-color: #555555; color: white; padding: 20px; border-radius: 10px;")
            self.lbl_reason.setText(f"INDOKLÁS: HMM bizonytalan. Konfidencia: {confidence:.1f}% (Minimum 80% kellene). Várakozás...")
            self.lbl_reason.setStyleSheet("background-color: #222222; padding: 10px; border-left: 5px solid #555555;")

        self.lbl_hmm.setText(f"HMM ÁLLAPOT: {state_name.upper()} ({confidence:.1f}%)")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    # Default file for testing
    test_file = "data/Merkava_XAUUSD_v1.10_20260408_025931.csv"
    if not os.path.exists(test_file):
        test_file = "Showcase_Indicators/GOLD_M1_1Day.csv"

    main_window = Vaku3Dashboard(test_file)
    main_window.show()
    sys.exit(app.exec_())
