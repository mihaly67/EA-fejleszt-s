import sys
import json
import zmq
import pandas as pd
from datetime import datetime
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from PyQt5.QtCore import QThread, pyqtSignal
from lightweight_charts.widgets import QtChart

class ZMQReceiverThread(QThread):
    data_received = pyqtSignal(dict)

    def __init__(self, port=5557, host='127.0.0.1'):
        super().__init__()
        self.port = port
        self.host = host
        self.running = True

    def run(self):
        context = zmq.Context()
        socket = context.socket(zmq.SUB)
        socket.connect(f"tcp://{self.host}:{self.port}")
        socket.setsockopt_string(zmq.SUBSCRIBE, "HUD")

        while self.running:
            try:
                # Wait for the next message
                msg = socket.recv_string(flags=zmq.NOBLOCK)
                if msg.startswith("HUD "):
                    data_str = msg[4:] # Remove "HUD " prefix
                    data = json.loads(data_str)
                    self.data_received.emit(data)
            except zmq.Again:
                self.msleep(50)  # Sleep 50ms if no message
            except Exception as e:
                print(f"ZMQ Error: {e}")
                self.msleep(500)

    def stop(self):
        self.running = False
        self.wait()


class HUDWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Tick-Level Candlestick Rendering Prototype")
        self.resize(800, 600)

        # Main Layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)

        # Initialize lightweight-charts QtChart
        self.chart = QtChart(inner_width=1, inner_height=1)
        layout.addWidget(self.chart.get_webview())

        # Start ZMQ Thread
        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.zmq_thread.start()

    def on_data_received(self, data):
        # Format the incoming dict into a pandas Series as expected by lightweight-charts update_from_tick
        # Convert MT5 numeric timestamp (seconds) to datetime
        ts = pd.to_datetime(data['timestamp'], unit='s')

        tick_data = pd.Series({
            'time': ts,
            'open': data['open'],
            'high': data['high'],
            'low': data['low'],
            'close': data['close']
        })

        try:
            self.chart.update(tick_data)
        except Exception as e:
            print(f"Chart update error: {e}")

    def closeEvent(self, event):
        self.zmq_thread.stop()
        event.accept()

if __name__ == '__main__':
    from PyQt5.QtCore import QThread, pyqtSignal, QTimer
    app = QApplication(sys.argv)
    window = HUDWindow()
    window.show()
    sys.exit(app.exec_())
