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

# --- IDŐTENGELY FORMÁZÓ (DateAxisItem) ---
class TimeAxisItem(pg.AxisItem):
    def tickStrings(self, values, scale, spacing):
        return [pd.to_datetime(value, unit='ms').strftime('%H:%M:%S') for value in values]

class MockDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0

        try:
            if os.path.exists(file_path):
                self.df = pd.read_csv(file_path)
                # Használjuk a nyers TickMSC-t milliszekundumban az időszinkronizáláshoz
                if 'TickMSC' not in self.df.columns and 'TimeMsc' in self.df.columns:
                    self.df['TickMSC'] = self.df['TimeMsc']
            else:
                self._generate_fake_data()
        except Exception as e:
            print(f"Hiba a fájl betöltésekor: {e}")
            self._generate_fake_data()

    def _generate_fake_data(self):
        N = 10000
        start_time = int(time.time() * 1000)
        # Minden tick között pontosan 1000 ms (1 mp)
        unix_time = start_time + (np.arange(N) * 1000)
        price = np.sin(np.linspace(0, 20, N)) * 0.05 + 1.1500 + np.cumsum(np.random.randn(N)*0.001)
        macro_er = np.random.uniform(0.1, 0.9, N)
        risk = np.random.uniform(0, 100, N)
        macro_er = pd.Series(macro_er).rolling(50).mean().fillna(0.5)
        risk = pd.Series(risk).rolling(5).mean().fillna(10)

        decisions = []
        for i in range(N):
            if macro_er[i] >= 0.3 and risk[i] < 20: decisions.append('GREEN')
            elif macro_er[i] >= 0.3 and risk[i] >= 20: decisions.append('YELLOW')
            else: decisions.append('RED')

        self.df = pd.DataFrame({
            'TickMSC': unix_time,
            'Price': price,
            'Macro_ER': macro_er,
            'Theater_Risk_Pct': risk,
            'Hybrid_Decision': decisions
        })

    def peek_next_tick_time(self):
        if self.current_idx >= len(self.df):
            return None
        return float(self.df.iloc[self.current_idx]['TickMSC'])

    def get_next_tick(self):
        if self.current_idx >= len(self.df):
            self.current_idx = 0
        row = self.df.iloc[self.current_idx]
        self.current_idx += 1
        return row

class VakuDashboard(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VAKU 3.0 - Valós Idejű Advisory Műszerfal V5 (Strict Real-Time)")
        self.resize(1600, 950)
        self.setStyleSheet("background-color: #0b0e14; color: #FFFFFF;")

        self.stream = MockDataStream("reports_tmp/HYBRID_EVAL_EURUSD.csv")

        self.max_points = 1000
        self.x_data = np.zeros(self.max_points)
        self.price_data = np.zeros(self.max_points)
        self.macro_data = np.zeros(self.max_points)
        self.risk_data = np.zeros(self.max_points)
        self.ptr = 0

        self.micro_prices = []
        self.medium_prices = []
        self.macro_prices = []

        # Szigorú Valós Idejű Lejátszás (Strict Real-Time Clock)
        self.playback_speed_multiplier = 1.0
        self.is_paused = False

        # A szimulátor belső órája milliszekundumban
        first_tick_time = self.stream.peek_next_tick_time()
        self.virtual_clock_ms = first_tick_time if first_tick_time is not None else int(time.time() * 1000)
        self.last_update_wall_time = time.perf_counter()

        self.init_ui()

        # A Timer gyakrabban pörög (16ms = 60 FPS), de csak akkor rajzol és léptet, ha a belső óra utolérte a tick időbélyegét
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_dashboard)
        self.timer.start(16)

    def init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)

        # ==========================================
        # 0. VEZÉRLŐ PANEL (Lejátszás, Sebesség)
        # ==========================================
        control_panel = QWidget()
        control_layout = QHBoxLayout(control_panel)
        control_layout.setContentsMargins(5, 5, 5, 5)

        btn_pause = QPushButton("PAUSE / PLAY")
        btn_pause.setStyleSheet("background-color: #333; padding: 5px; font-weight: bold;")
        btn_pause.clicked.connect(self.toggle_pause)

        lbl_speed = QLabel("SEBESSÉG:")
        self.combo_speed = QComboBox()
        self.combo_speed.addItems(["1x (Valós Idő)", "5x", "10x", "50x", "MAX (Stress Test)"])
        self.combo_speed.setStyleSheet("background-color: #222; color: white;")
        self.combo_speed.currentIndexChanged.connect(self.change_speed)

        self.lbl_clock = QLabel("SZIMULÁLT ÓRA: 00:00:00")
        self.lbl_clock.setStyleSheet("color: #00FF00; font-weight: bold; margin-left: 20px;")

        control_layout.addWidget(btn_pause)
        control_layout.addWidget(lbl_speed)
        control_layout.addWidget(self.combo_speed)
        control_layout.addWidget(self.lbl_clock)
        control_layout.addStretch()

        layout.addWidget(control_panel)

        # ==========================================
        # 1. INFORMÁCIÓS PANEL
        # ==========================================
        info_panel = QWidget()
        info_layout = QGridLayout(info_panel)

        self.lbl_status = QLabel("EA STÁTUSZ: WAITING")
        self.lbl_status.setFont(QFont("Arial", 22, QFont.Bold))
        self.lbl_status.setAlignment(Qt.AlignCenter)
        self.lbl_status.setStyleSheet("background-color: #222222; border: 2px solid #555555; border-radius: 8px; padding: 10px;")

        self.lbl_regime = QLabel("PIACI REZSIM:\nISMERETLEN")
        self.lbl_regime.setFont(QFont("Arial", 12))
        self.lbl_regime.setAlignment(Qt.AlignCenter)
        self.lbl_regime.setStyleSheet("background-color: #1a1a2e; border: 1px solid #333333; padding: 5px;")

        self.lbl_predict = QLabel("FORDULÓ PREDIKCIÓ:\nNINCS JELZÉS")
        self.lbl_predict.setFont(QFont("Arial", 12, QFont.Bold))
        self.lbl_predict.setAlignment(Qt.AlignCenter)
        self.lbl_predict.setStyleSheet("background-color: #1a1a2e; border: 1px solid #333333; padding: 5px; color: #a9b7c6;")

        self.lbl_reason = QLabel("DÖNTÉS OKA:\nINICIALIZÁLÁS...")
        self.lbl_reason.setFont(QFont("Arial", 12))
        self.lbl_reason.setAlignment(Qt.AlignCenter)
        self.lbl_reason.setStyleSheet("background-color: #1a1a2e; border: 1px solid #333333; padding: 5px; color: #a9b7c6;")

        info_layout.addWidget(self.lbl_status, 0, 0, 2, 2)
        info_layout.addWidget(self.lbl_regime, 0, 2)
        info_layout.addWidget(self.lbl_predict, 1, 2)
        info_layout.addWidget(self.lbl_reason, 0, 3, 2, 1)

        layout.addWidget(info_panel)

        # ==========================================
        # 2. PYQTGRAPH DIAGRAMOK
        # ==========================================
        pg.setConfigOptions(antialias=True)
        self.plot_widget = pg.GraphicsLayoutWidget()
        layout.addWidget(self.plot_widget)

        date_axis = TimeAxisItem(orientation='bottom')
        self.p1 = self.plot_widget.addPlot(title="Élő Árfolyam (Jobbra tolva a jövőnek)", axisItems={'bottom': date_axis})
        self.p1.showGrid(x=True, y=True, alpha=0.4)

        self.p1.setMouseEnabled(x=True, y=True)
        self.p1.setAutoVisible(y=True)

        self.curve_price = self.p1.plot(pen=pg.mkPen(color='#00d4ff', width=2))

        self.scatter_green = pg.ScatterPlotItem(size=8, pen=pg.mkPen(None), brush=pg.mkBrush(0, 255, 0, 200))
        self.scatter_yellow = pg.ScatterPlotItem(size=12, pen=pg.mkPen(None), brush=pg.mkBrush(255, 165, 0, 255))
        self.scatter_red = pg.ScatterPlotItem(size=8, pen=pg.mkPen(None), brush=pg.mkBrush(255, 0, 0, 100))
        self.p1.addItem(self.scatter_green)
        self.p1.addItem(self.scatter_yellow)
        self.p1.addItem(self.scatter_red)

        self.plot_widget.nextRow()

        date_axis2 = TimeAxisItem(orientation='bottom')
        self.p2 = self.plot_widget.addPlot(title="Makro Trend Erő (Kék) vs HMM Kockázat (Piros)", axisItems={'bottom': date_axis2})
        self.p2.showGrid(x=True, y=True, alpha=0.4)
        self.p2.setYRange(0, 100)
        self.p2.setMouseEnabled(x=True, y=False)

        self.curve_macro = self.p2.plot(pen=pg.mkPen(color='#0055ff', width=3))
        self.curve_risk = self.p2.plot(pen=pg.mkPen(color='#ff3333', width=2))

        hline20 = pg.InfiniteLine(angle=0, movable=False, pen=pg.mkPen(color=(255, 165, 0, 150), style=Qt.DashLine))
        hline20.setPos(20.0)
        self.p2.addItem(hline20)

        self.p2.setXLink(self.p1)

    def toggle_pause(self):
        self.is_paused = not self.is_paused
        # Resetáljuk az órát, hogy ne ugorjon egy nagyot a pause után
        self.last_update_wall_time = time.perf_counter()

    def change_speed(self, index):
        if index == 0: self.playback_speed_multiplier = 1.0
        elif index == 1: self.playback_speed_multiplier = 5.0
        elif index == 2: self.playback_speed_multiplier = 10.0
        elif index == 3: self.playback_speed_multiplier = 50.0
        elif index == 4: self.playback_speed_multiplier = 10000.0 # Max
        self.last_update_wall_time = time.perf_counter()

    def calculate_trend_slope(self, arr):
        if len(arr) < 10: return 0
        return arr[-1] - arr[0]

    def analyze_multi_trend(self):
        if len(self.macro_prices) < 2000:
            return "Kevés adat", "#333", "NINCS JELZÉS", "#333"

        micro_slope = self.calculate_trend_slope(self.micro_prices)
        med_slope = self.calculate_trend_slope(self.medium_prices)
        mac_slope = self.calculate_trend_slope(self.macro_prices)

        regime_str = ""
        overall_color = "#333"

        if mac_slope > 0.0005:
            regime_str += "Makro: 🔼 UP\n"
            overall_color = "#004400"
        elif mac_slope < -0.0005:
            regime_str += "Makro: 🔽 DOWN\n"
            overall_color = "#440000"
        else:
            regime_str += "Makro: ➡️ FLAT\n"
            overall_color = "#444444"

        if med_slope > 0.0002: regime_str += "Közép: 🔼 UP\n"
        elif med_slope < -0.0002: regime_str += "Közép: 🔽 DOWN\n"
        else: regime_str += "Közép: ➡️ FLAT\n"

        if micro_slope > 0.0001: regime_str += "Mikro: 🔼 UP"
        elif micro_slope < -0.0001: regime_str += "Mikro: 🔽 DOWN"
        else: regime_str += "Mikro: ➡️ FLAT"

        predict_str = "NINCS JELZÉS"
        predict_color = "#333"

        if mac_slope > 0.0005 and med_slope < 0 and micro_slope < -0.0002:
            predict_str = "⚠️ MEDVE FORDULÓ VÁRHATÓ!\n(A mikro trend divergál lefelé)"
            predict_color = "#880000"
        elif mac_slope < -0.0005 and med_slope > 0 and micro_slope > 0.0002:
            predict_str = "⚠️ BIKA FORDULÓ VÁRHATÓ!\n(A mikro trend divergál felfelé)"
            predict_color = "#008800"
        elif (mac_slope > 0 and med_slope < 0 and micro_slope > 0) or (mac_slope < 0 and med_slope > 0 and micro_slope < 0):
            predict_str = "⚡ WHIPSAW VESZÉLY!\n(Konfliktus az idősíkok között)"
            predict_color = "#888800"
        else:
            predict_str = "✅ TREND STABIL\n(Az idősíkok egyetértenek)"
            predict_color = "#1a1a2e"

        return regime_str, overall_color, predict_str, predict_color

    def get_reason(self, decision, macro_er, risk):
        if decision == 'GREEN': return "OK:\nKiszámítható Makro Trend.\nNincs Brókeri Manipuláció."
        if decision == 'YELLOW': return f"OK:\nA Makro Trend Erős (ER={macro_er:.2f}), DE a HMM \nvalószínűsít egy Whipsaw-t (Kockázat={risk:.1f}%).\nVárj a belépéssel!"
        if decision == 'RED':
            if macro_er < 0.3: return f"OK (LÁTSZÓLAG BIZTONSÁGOS, DE TILTOTT):\nA görbe laposnak tűnhet, de a Makro ER nagyon\nalacsony ({macro_er:.2f}). A piac zajos (Oldalazás).\nA robottal ilyenkor belépni orosz rulett."
            else: return f"OK (TÖKÉLETES VIHAR):\nExtrém magas Brókeri Kockázat ({risk:.1f}%).\nSpread tágítás vagy azonnali fordulat várható."

    def update_dashboard(self):
        if self.is_paused:
            self.last_update_wall_time = time.perf_counter()
            return

        # 1. BELSŐ ÓRA LÉPTETÉSE (SZIGORÚ VALÓS IDŐ)
        current_wall_time = time.perf_counter()
        delta_wall_time = current_wall_time - self.last_update_wall_time
        self.last_update_wall_time = current_wall_time

        # A virtuális óra a falióra telt idejével növekszik, megszorozva a sebességgel (milliszekundumban)
        self.virtual_clock_ms += (delta_wall_time * 1000.0) * self.playback_speed_multiplier

        # Óra frissítése a GUI-n
        self.lbl_clock.setText(f"SZIMULÁLT ÓRA: {pd.to_datetime(self.virtual_clock_ms, unit='ms').strftime('%H:%M:%S.%f')[:-3]}")

        # 2. ADATOK FELDOLGOZÁSA (Csak addig, amíg a tick ideje <= belső óra)
        ticks_processed_this_frame = 0
        has_new_data = False

        # Max limit a lefagyás ellen MAX sebességen
        max_ticks_per_frame = 100 if self.playback_speed_multiplier < 10000 else 500

        while ticks_processed_this_frame < max_ticks_per_frame:
            next_tick_time = self.stream.peek_next_tick_time()
            if next_tick_time is None:
                break # Vége a fájlnak

            # Ha a következő tick Még a Jövőben van a mi belső óránkhoz képest, megállunk (1x Valós Idő Érzet!)
            if next_tick_time > self.virtual_clock_ms:
                break

            # Jöhet a feldolgozás
            row = self.stream.get_next_tick()
            unix_ms = float(row['TickMSC'])
            price = float(row['Price'])
            macro_er = float(row['Macro_ER'])
            risk = float(row.get('Theater_Risk_Pct', 0.0))
            decision = row.get('Hybrid_Decision', 'RED')

            self.micro_prices.append(price)
            self.medium_prices.append(price)
            self.macro_prices.append(price)

            if len(self.micro_prices) > 100: self.micro_prices.pop(0)
            if len(self.medium_prices) > 500: self.medium_prices.pop(0)
            if len(self.macro_prices) > 2000: self.macro_prices.pop(0)

            self.x_data[:-1] = self.x_data[1:]
            self.x_data[-1] = unix_ms

            self.price_data[:-1] = self.price_data[1:]
            self.price_data[-1] = price

            self.macro_data[:-1] = self.macro_data[1:]
            self.macro_data[-1] = macro_er * 100

            self.risk_data[:-1] = self.risk_data[1:]
            self.risk_data[-1] = risk

            self.ptr += 1
            ticks_processed_this_frame += 1
            has_new_data = True

        # 3. RAJZOLÁS (Csak ha volt új adat)
        if not has_new_data or self.ptr < 5:
            return

        draw_len = min(self.ptr, self.max_points)
        x_draw = self.x_data[-draw_len:]

        self.curve_price.setData(x_draw, self.price_data[-draw_len:])
        self.curve_macro.setData(x_draw, self.macro_data[-draw_len:])
        self.curve_risk.setData(x_draw, self.risk_data[-draw_len:])

        # --- JOBB ELTOLÁS BEÁLLÍTÁSA (Right Margin) ---
        latest_time = x_draw[-1]
        earliest_time = x_draw[0]
        time_span = latest_time - earliest_time

        x_min = earliest_time
        x_max = latest_time + (time_span * 0.25) # 25% üres tér a jövőnek
        self.p1.setXRange(x_min, x_max, padding=0)

        # --- STÁTUSZ PANELEK FRISSÍTÉSE ---
        # Itt biztosítjuk, hogy minden panel KÖTELEZŐEN frissüljön a legutolsó tick adataival!
        regime_str, regime_color, predict_str, predict_color = self.analyze_multi_trend()
        reason_text = self.get_reason(decision, macro_er, risk)

        self.lbl_regime.setText(f"3-SZINTŰ REZSIM:\n{regime_str}")
        self.lbl_regime.setStyleSheet(f"background-color: {regime_color}; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_predict.setText(f"PREDIKCIÓ:\n{predict_str}")
        self.lbl_predict.setStyleSheet(f"background-color: {predict_color}; border: 1px solid #555; padding: 5px; color: white;")

        self.lbl_reason.setText(reason_text)

        if decision == 'GREEN':
            self.lbl_status.setText("🟢 TISZTA PIAC (MEHET A TRADE)")
            self.lbl_status.setStyleSheet("background-color: #003300; border: 2px solid #00FF00; color: #00FF00; border-radius: 8px; padding: 10px;")
        elif decision == 'YELLOW':
            self.lbl_status.setText("🟡 MANIPULÁCIÓ! (VÁRJ/VIGYÁZZ)")
            self.lbl_status.setStyleSheet("background-color: #333300; border: 2px solid #FFFF00; color: #FFFF00; border-radius: 8px; padding: 10px;")
        else:
            self.lbl_status.setText("🔴 KÁOSZ / OLDALAZÁS (TILTVA)")
            self.lbl_status.setStyleSheet("background-color: #330000; border: 2px solid #FF0000; color: #FF0000; border-radius: 8px; padding: 10px;")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    dashboard = VakuDashboard()
    dashboard.show()
    sys.exit(app.exec_())
