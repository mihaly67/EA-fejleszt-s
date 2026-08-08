import sys
import json
import zmq
import pyqtgraph as pg
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QLabel
from PyQt5.QtCore import QThread, pyqtSignal, Qt


from PyQt5.QtGui import QPicture, QPainter
class CandlestickItem(pg.GraphicsObject):
    def __init__(self, data):
        pg.GraphicsObject.__init__(self)
        self.data = data  # data must have fields: time, open, close, min, max
        self.generatePicture()
    def generatePicture(self):
        self.picture = QPicture()
        p = QPainter(self.picture)
        p.setPen(pg.mkPen('w'))
        w = (self.data[1][0] - self.data[0][0]) / 3. if len(self.data) > 1 else 0.2
        for (t, open, close, min, max) in self.data:
            p.drawLine(pg.QtCore.QPointF(t, min), pg.QtCore.QPointF(t, max))
            if open > close:
                p.setBrush(pg.mkBrush('firebrick'))
                p.setPen(pg.mkPen('firebrick'))
            else:
                p.setBrush(pg.mkBrush('forestgreen'))
                p.setPen(pg.mkPen('forestgreen'))
            p.drawRect(pg.QtCore.QRectF(t-w, open, w*2, close-open))
        p.end()
    def paint(self, p, *args):
        p.drawPicture(0, 0, self.picture)
    def boundingRect(self):
        return pg.QtCore.QRectF(self.picture.boundingRect())

class ZMQListener(QThread):
    data_received = pyqtSignal(dict)

    def __init__(self):
        super().__init__()
        self.running = True

    def run(self):
        context = zmq.Context()
        socket = context.socket(zmq.SUB)
        socket.connect("tcp://127.0.0.1:5557")
        socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

        while self.running:
            try:
                msg = socket.recv_string()
                # Format: "HUD {"timestamp": ...}"
                _, json_str = msg.split(" ", 1)
                data = json.loads(json_str)
                self.data_received.emit(data)
            except Exception as e:
                print(f"ZMQ Error: {e}")


class CopilotHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("LGBM Copilot HUD - Feature Fusion")
        self.setGeometry(100, 100, 1200, 800)

        # Dark mode styling
        self.setStyleSheet("background-color: #121212; color: #FFFFFF;")

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)

        # --- Top Info Panel ---
        self.info_label = QLabel("Waiting for data...")
        self.info_label.setAlignment(Qt.AlignCenter)
        self.info_label.setStyleSheet("font-size: 20px; font-weight: bold; color: #CCCCCC; padding: 10px;")
        layout.addWidget(self.info_label)

        # --- Top Chart (Price & Signals) ---
        pg.setConfigOption('background', '#121212')
        pg.setConfigOption('foreground', '#CCCCCC')

        self.price_plot = pg.PlotWidget(title="Live Tick/M1 Price")
        self.price_plot.showGrid(x=True, y=True, alpha=0.3)
        layout.addWidget(self.price_plot, stretch=2)

        # --- Bottom Chart (Probabilities) ---
        self.prob_plot = pg.PlotWidget(title="4D Asymmetric Probabilities")
        self.prob_plot.showGrid(x=True, y=True, alpha=0.3)
        self.prob_plot.setYRange(0, 1)
        layout.addWidget(self.prob_plot, stretch=1)

        # Data arrays
        self.times = []
        self.prices = []

        self.p_long_data = []
        self.p_short_data = []
        self.p_noise_data = []

        # Curves
        self.candle_data = []
        self.candlestick_item = None
        self.p_long_curve = self.prob_plot.plot(pen=pg.mkPen('forestgreen', width=2), name="P_Long")
        self.p_short_curve = self.prob_plot.plot(pen=pg.mkPen('firebrick', width=2), name="P_Short")
        self.p_noise_curve = self.prob_plot.plot(pen=pg.mkPen('#555555', width=2, style=Qt.DashLine), name="P_Noise")

        # Threshold Lines
        self.prob_plot.addLine(y=0.55, pen=pg.mkPen('forestgreen', width=1, style=Qt.DotLine))
        self.prob_plot.addLine(y=0.45, pen=pg.mkPen('firebrick', width=1, style=Qt.DotLine))

        # Signal markers
        self.signal_scatter = pg.ScatterPlotItem(size=14, pen=pg.mkPen(None))
        self.price_plot.addItem(self.signal_scatter)

        # ZMQ Thread
        self.zmq_thread = ZMQListener()
        self.zmq_thread.data_received.connect(self.update_hud)
        self.zmq_thread.start()

    def closeEvent(self, event):
        self.zmq_thread.running = False
        self.zmq_thread.quit()
        self.zmq_thread.wait()
        event.accept()

    def update_hud(self, data):
        # Limit data size
        if len(self.times) > 1000:
            self.times.pop(0)
            self.prices.pop(0)
            self.p_long_data.pop(0)
            self.p_short_data.pop(0)
            self.p_noise_data.pop(0)
            if self.candle_data:
                self.candle_data.pop(0)

        idx = self.times[-1] + 1 if self.times else 0
        self.times.append(idx)

        current_price = data.get("price", 0.0)
        self.prices.append(current_price)

        self.p_long_data.append(data.get("p_long", 0.0))
        self.p_short_data.append(data.get("p_short", 0.0))
        self.p_noise_data.append(data.get("p_noise", 0.0))

        # Update curves
        o = data.get("open", current_price)
        h = data.get("high", current_price)
        l = data.get("low", current_price)
        c = data.get("close", current_price)
        self.candle_data.append((idx, o, c, l, h))

        if self.candlestick_item is not None:
            self.price_plot.removeItem(self.candlestick_item)

        self.candlestick_item = CandlestickItem(self.candle_data)
        self.price_plot.addItem(self.candlestick_item)

        self.p_long_curve.setData(self.times, self.p_long_data)
        self.p_short_curve.setData(self.times, self.p_short_data)
        self.p_noise_curve.setData(self.times, self.p_noise_data)

        # Update signals (Scatter)
        signal = data.get("signal", 0)
        if signal != 0:
            color = 'forestgreen' if signal == 1 else 'firebrick'
            symbol = 't1' if signal == 1 else 't' # triangle up/down
            # Y-offset for triangles
            offset = 1.0 if signal == -1 else -1.0

            self.signal_scatter.addPoints([{'pos': (idx, current_price + offset), 'brush': color, 'symbol': symbol}])

        # Update Stability Label
        is_stable = data.get("is_stable", False)
        if is_stable and signal == 1:
            self.info_label.setText("🔥 STABLE LONG TREND 🔥")
            self.info_label.setStyleSheet("font-size: 24px; font-weight: bold; color: forestgreen; padding: 10px;")
        elif is_stable and signal == -1:
            self.info_label.setText("🔥 STABLE SHORT TREND 🔥")
            self.info_label.setStyleSheet("font-size: 24px; font-weight: bold; color: firebrick; padding: 10px;")
        else:
            self.info_label.setText("Várjuk a megerősítést (Zaj / Instabil)")
            self.info_label.setStyleSheet("font-size: 20px; font-weight: bold; color: #888888; padding: 10px;")


if __name__ == '__main__':
    app = QApplication(sys.argv)
    hud = CopilotHUD()
    hud.show()
    sys.exit(app.exec_())
