import sys
import numpy as np
import pandas as pd
import threading
import time
import os

from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QLabel, QPushButton
from PyQt5.QtCore import QTimer, Qt
from PyQt5.QtGui import QColor, QFont
import pyqtgraph as pg

# Dummy (szimulált) adatforrás a teszteléshez
class MockDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0

        # Próbáljuk betölteni az előre generált Hibrid CSV-t, vagy ha nincs, generálunk fake adatot
        try:
            if os.path.exists(file_path):
                self.df = pd.read_csv(file_path)
            else:
                self._generate_fake_data()
        except:
            self._generate_fake_data()

    def _generate_fake_data(self):
        print("MOCK ADAT GENERÁLÁSA A DASHBOARDHOZ...")
        N = 10000
        time_msc = np.arange(N) * 1000  # 1 sec tickek
        price = np.cumsum(np.random.randn(N)) + 1.1500
        macro_er = np.random.uniform(0.1, 0.9, N)
        risk = np.random.uniform(0, 100, N)

        # Smootholjuk a fake adatokat
        macro_er = pd.Series(macro_er).rolling(50).mean().fillna(0.5)
        risk = pd.Series(risk).rolling(5).mean().fillna(10)

        decisions = []
        for i in range(N):
            if macro_er[i] >= 0.3 and risk[i] < 20: decisions.append('GREEN')
            elif macro_er[i] >= 0.3 and risk[i] >= 20: decisions.append('YELLOW')
            else: decisions.append('RED')

        self.df = pd.DataFrame({
            'TickMSC': time_msc,
            'Price': price,
            'Macro_ER': macro_er,
            'Theater_Risk_Pct': risk,
            'Hybrid_Decision': decisions
        })

    def get_next_tick(self):
        if self.current_idx >= len(self.df):
            self.current_idx = 0 # Loop

        row = self.df.iloc[self.current_idx]
        self.current_idx += 1
        return row

class VakuDashboard(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VAKU 3.0 - Valós Idejű Advisory Műszerfal")
        self.resize(1200, 800)
        self.setStyleSheet("background-color: #121212; color: #FFFFFF;")

        # Adatfolyam inicializálása
        self.stream = MockDataStream("reports_tmp/HYBRID_EVAL_EURUSD.csv")

        # Adattárolók a grafikonhoz
        self.max_points = 500
        self.x_data = np.zeros(self.max_points)
        self.price_data = np.zeros(self.max_points)
        self.macro_data = np.zeros(self.max_points)
        self.risk_data = np.zeros(self.max_points)
        self.ptr = 0

        self.init_ui()

        # Timer a valós idejű frissítéshez (pl. 100ms = 10 FPS)
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_dashboard)
        self.timer.start(100) # 100 ms

    def init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)

        # --- FEJLÉC (Állapot és Közlekedési Lámpa) ---
        header_layout = QHBoxLayout()

        self.lbl_status = QLabel("EA STÁTUSZ: WAITING")
        self.lbl_status.setFont(QFont("Arial", 24, QFont.Bold))
        self.lbl_status.setAlignment(Qt.AlignCenter)
        self.lbl_status.setStyleSheet("background-color: #333333; padding: 10px; border-radius: 5px;")

        self.lbl_risk = QLabel("KOCKÁZAT: 0.0%")
        self.lbl_risk.setFont(QFont("Arial", 18))
        self.lbl_risk.setAlignment(Qt.AlignCenter)

        self.lbl_macro = QLabel("MAKRO TREND (ER): 0.00")
        self.lbl_macro.setFont(QFont("Arial", 18))
        self.lbl_macro.setAlignment(Qt.AlignCenter)

        header_layout.addWidget(self.lbl_macro)
        header_layout.addWidget(self.lbl_status)
        header_layout.addWidget(self.lbl_risk)
        layout.addLayout(header_layout)

        # --- PYQTGRAPH DIAGRAMOK ---
        pg.setConfigOptions(antialias=True)
        self.plot_widget = pg.GraphicsLayoutWidget()
        layout.addWidget(self.plot_widget)

        # 1. Árfolyam Chart
        self.p1 = self.plot_widget.addPlot(title="Élő Árfolyam (Tick)")
        self.p1.showGrid(x=True, y=True, alpha=0.3)
        self.curve_price = self.p1.plot(pen=pg.mkPen(color='#00BFFF', width=2))

        # Scatter pontok a döntésekhez
        self.scatter_green = pg.ScatterPlotItem(size=10, pen=pg.mkPen(None), brush=pg.mkBrush(0, 255, 0, 200))
        self.scatter_yellow = pg.ScatterPlotItem(size=15, pen=pg.mkPen(None), brush=pg.mkBrush(255, 165, 0, 255))
        self.scatter_red = pg.ScatterPlotItem(size=10, pen=pg.mkPen(None), brush=pg.mkBrush(255, 0, 0, 150))
        self.p1.addItem(self.scatter_green)
        self.p1.addItem(self.scatter_yellow)
        self.p1.addItem(self.scatter_red)

        self.plot_widget.nextRow()

        # 2. Makro / Mikro Kockázat Chart
        self.p2 = self.plot_widget.addPlot(title="Makro ER & Viterbi Kockázat")
        self.p2.showGrid(x=True, y=True, alpha=0.3)
        self.p2.setYRange(0, 100)

        self.curve_macro = self.p2.plot(pen=pg.mkPen(color='#AAAAAA', width=2)) # Makro ER (0-100-ra skálázva vizuálisan)
        self.curve_risk = self.p2.plot(pen=pg.mkPen(color='#FF3333', width=2)) # Theater Risk (0-100%)

        # Kockázati Vonal (20%)
        hline = pg.InfiniteLine(angle=0, movable=False, pen=pg.mkPen('r', style=Qt.DashLine))
        hline.setPos(20.0)
        self.p2.addItem(hline)

    def update_dashboard(self):
        # 1. Új adat lekérése
        row = self.stream.get_next_tick()
        price = float(row['Price'])
        macro_er = float(row['Macro_ER'])
        risk = float(row.get('Theater_Risk_Pct', 0.0))
        decision = row.get('Hybrid_Decision', 'RED')

        # 2. Adatok tárolása
        self.x_data[:-1] = self.x_data[1:]
        self.x_data[-1] = self.ptr

        self.price_data[:-1] = self.price_data[1:]
        self.price_data[-1] = price

        self.macro_data[:-1] = self.macro_data[1:]
        self.macro_data[-1] = macro_er * 100 # Skálázzuk fel 100-ra a közös grafikonhoz

        self.risk_data[:-1] = self.risk_data[1:]
        self.risk_data[-1] = risk

        self.ptr += 1

        # Csak akkor rajzolunk, ha már feltöltődött a buffer kicsit
        if self.ptr < 5:
            return

        # 3. Görbék frissítése
        self.curve_price.setData(self.x_data, self.price_data)
        self.curve_macro.setData(self.x_data, self.macro_data)
        self.curve_risk.setData(self.x_data, self.risk_data)

        # 4. Fejléc Frissítése
        self.lbl_macro.setText(f"MAKRO ER: {macro_er:.2f}")
        self.lbl_risk.setText(f"KOCKÁZAT: {risk:.1f}%")

        if decision == 'GREEN':
            self.lbl_status.setText("🟢 TISZTA PIAC (ENGEDÉLYEZVE)")
            self.lbl_status.setStyleSheet("background-color: #004400; color: #00FF00; padding: 10px; border-radius: 5px;")
        elif decision == 'YELLOW':
            self.lbl_status.setText("🟡 MANIPULÁCIÓ VESZÉLY (VÁRAKOZÁS)")
            self.lbl_status.setStyleSheet("background-color: #444400; color: #FFFF00; padding: 10px; border-radius: 5px;")
        else:
            self.lbl_status.setText("🔴 KÁOSZ / OLDALAZÁS (TILTVA)")
            self.lbl_status.setStyleSheet("background-color: #440000; color: #FF0000; padding: 10px; border-radius: 5px;")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    dashboard = VakuDashboard()
    dashboard.show()
    sys.exit(app.exec_())
