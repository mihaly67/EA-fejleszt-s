import sys
import zmq
import json
import numpy as np
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QLabel
from PyQt5.QtGui import QPicture, QPainter
from PyQt5.QtCore import QTimer, Qt, QRectF, QPointF
from PyQt5.QtCore import QTimer, Qt
import pyqtgraph as pg

# Configure PyQtGraph for Dark Mode and Performance
pg.setConfigOption('background', 'k')  # Pure black background
pg.setConfigOption('foreground', 'w')
pg.setConfigOptions(antialias=True)

class CandlestickItem(pg.GraphicsObject):
    def __init__(self, data):
        pg.GraphicsObject.__init__(self)
        self.data = data
        self.generatePicture()

    def generatePicture(self):
        self.picture = QPicture()
        p = QPainter(self.picture)

        # Colors requested by user: Forest Green and Brick Red, Solid bodies
        w = (self.data[1][0] - self.data[0][0]) / 3.0 if len(self.data) > 1 else 0.5

        for (t, open_p, close_p, min_p, max_p) in self.data:
            if close_p >= open_p:
                p.setPen(pg.mkPen('forestgreen'))
                p.setBrush(pg.mkBrush('forestgreen'))
            else:
                p.setPen(pg.mkPen('firebrick'))
                p.setBrush(pg.mkBrush('firebrick'))

            # Draw wick
            p.drawLine(QPointF(t, min_p), QPointF(t, max_p))
            # Draw body
            p.drawRect(QRectF(t - w, open_p, w * 2, close_p - open_p))

        p.end()

    def paint(self, p, *args):
        p.drawPicture(0, 0, self.picture)

    def boundingRect(self):
        return QRectF(self.picture.boundingRect())

class CopilotHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Merkava V1.9 Beta Copilot HUD")
        self.setGeometry(100, 100, 1400, 900)

        # Central widget and layout
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.layout = QVBoxLayout(self.central_widget)

        # ZMQ Context
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.SUB)
        self.socket.connect("tcp://127.0.0.1:5557")
        self.socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

        # Data Buffers (Fixed 100 candles)
        self.max_candles = 100
        self.ohlc_data = [] # List of tuples: (time_index, O, C, L, H)
        self.p_long_data = []
        self.p_short_data = []
        self.p_noise_data = []
        self.stoch_k_data = []
        self.time_indices = []
        self.current_idx = 0

        self.last_signal = 0
        self.entry_price = 0.0

        self.init_ui()

        # Update Timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_data)
        self.timer.start(50) # 20 Hz update

    def init_ui(self):
        # Header Status
        self.status_label = QLabel("Waiting for live data...")
        self.status_label.setStyleSheet("font-size: 24px; font-weight: bold; color: white;")
        self.status_label.setAlignment(Qt.AlignCenter)
        self.layout.addWidget(self.status_label)

        # Top Plot: Candles
        self.pw_candles = pg.PlotWidget(title="M1 Price Action & Entry Levels")
        self.layout.addWidget(self.pw_candles, stretch=7)
        self.pw_candles.showGrid(x=True, y=True, alpha=0.3)

        self.candle_item = None
        self.bid_line = pg.InfiniteLine(angle=0, movable=False, pen=pg.mkPen(color='gray', width=1, dash=[2, 2]))
        self.ask_line = pg.InfiniteLine(angle=0, movable=False, pen=pg.mkPen(color='lightgray', width=1, dash=[2, 2]))
        self.entry_line = pg.InfiniteLine(angle=0, movable=False, pen=pg.mkPen(color='yellow', width=2))

        self.pw_candles.addItem(self.bid_line)
        self.pw_candles.addItem(self.ask_line)
        self.pw_candles.addItem(self.entry_line)

        # Bottom Plot: Oscillators
        self.pw_osc = pg.PlotWidget(title="Probabilities & Stoch_K")
        self.layout.addWidget(self.pw_osc, stretch=3)
        self.pw_osc.showGrid(x=True, y=True, alpha=0.3)
        self.pw_osc.setYRange(0, 1.0, padding=0)

        self.curve_long = self.pw_osc.plot(pen=pg.mkPen('forestgreen', width=2), name="P_Long")
        self.curve_short = self.pw_osc.plot(pen=pg.mkPen('firebrick', width=2), name="P_Short")

        # P_Noise: grayish white, slightly dimmed so it doesn't blind
        self.curve_noise = self.pw_osc.plot(pen=pg.mkPen(color=(220, 220, 220, 200), width=1.5, style=Qt.DashLine), name="P_Noise")

        # Stoch_K: normalized to 0-1, different color
        self.curve_stoch = self.pw_osc.plot(pen=pg.mkPen(color=(200, 180, 100, 150), width=1.5), name="Stoch_K")

        # Threshold Lines
        self.pw_osc.addItem(pg.InfiniteLine(pos=0.45, angle=0, pen=pg.mkPen('forestgreen', width=1, style=Qt.DotLine)))
        self.pw_osc.addItem(pg.InfiniteLine(pos=0.37, angle=0, pen=pg.mkPen('firebrick', width=1, style=Qt.DotLine)))
        self.pw_osc.addItem(pg.InfiniteLine(pos=0.47, angle=0, pen=pg.mkPen(color=(220, 220, 220, 100), width=1, style=Qt.DotLine)))

    def update_data(self):
        try:
            # Non-blocking ZMQ receive
            while True:
                msg = self.socket.recv_string(flags=zmq.NOBLOCK)
                if msg.startswith("HUD "):
                    data_str = msg[4:]
                    try:
                        payload = json.loads(data_str)
                        self.process_payload(payload)
                    except Exception as e:
                        print(f"JSON Error: {e}")
        except zmq.Again:
            pass # No message available

    def process_payload(self, p):
        self.current_idx += 1
        idx = self.current_idx

        o = p.get('open', 0)
        h = p.get('high', 0)
        l = p.get('low', 0)
        c = p.get('close', 0)

        bid = p.get('bid', c)
        ask = p.get('ask', c)

        p_long = p.get('p_long', 0)
        p_short = p.get('p_short', 0)
        p_noise = p.get('p_noise', 0)
        stoch_k = p.get('stoch_k', 50.0) / 100.0 # Normalize 0-100 to 0.0-1.0

        sig = p.get('signal', 0)

        # Update buffers
        self.ohlc_data.append((idx, o, c, l, h))
        self.p_long_data.append(p_long)
        self.p_short_data.append(p_short)
        self.p_noise_data.append(p_noise)
        self.stoch_k_data.append(stoch_k)
        self.time_indices.append(idx)

        if len(self.ohlc_data) > self.max_candles:
            self.ohlc_data.pop(0)
            self.p_long_data.pop(0)
            self.p_short_data.pop(0)
            self.p_noise_data.pop(0)
            self.stoch_k_data.pop(0)
            self.time_indices.pop(0)

        # Draw Candles
        if self.candle_item:
            self.pw_candles.removeItem(self.candle_item)
        self.candle_item = CandlestickItem(self.ohlc_data)
        self.pw_candles.addItem(self.candle_item)

        # Draw Curves
        self.curve_long.setData(self.time_indices, self.p_long_data)
        self.curve_short.setData(self.time_indices, self.p_short_data)
        self.curve_noise.setData(self.time_indices, self.p_noise_data)
        self.curve_stoch.setData(self.time_indices, self.stoch_k_data)

        # Update Lines
        self.bid_line.setValue(bid)
        self.ask_line.setValue(ask)

        if sig == 1:
            self.last_signal = 1
            self.entry_price = ask
            self.status_label.setText("🟢 ACTIVE LONG SIGNAL")
            self.status_label.setStyleSheet("font-size: 24px; font-weight: bold; color: forestgreen;")
        elif sig == -1:
            self.last_signal = -1
            self.entry_price = bid
            self.status_label.setText("🔴 ACTIVE SHORT SIGNAL")
            self.status_label.setStyleSheet("font-size: 24px; font-weight: bold; color: firebrick;")
        elif sig == 0 and self.last_signal != 0:
            # We don't reset entry line immediately, let it stay to see how the trade plays out
            pass

        if self.entry_price > 0:
            self.entry_line.setValue(self.entry_price)
            # Color the entry line based on direction
            color = 'lime' if self.last_signal == 1 else 'red'
            self.entry_line.setPen(pg.mkPen(color=color, width=2))

        # Set X Range to leave 15% empty space on the right
        # Total view = 100 candles.
        # If current max index is idx, we show from idx - 100 to idx + 15
        if len(self.time_indices) > 0:
            min_x = self.time_indices[0]
            max_x = idx + 15
            self.pw_candles.setXRange(min_x, max_x, padding=0)
            self.pw_osc.setXRange(min_x, max_x, padding=0)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    hud = CopilotHUD()
    hud.show()
    sys.exit(app.exec_())
