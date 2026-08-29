
import sys
import os
import json
import zmq
import pandas as pd
from datetime import datetime

os.environ["QTWEBENGINE_DISABLE_GPU"] = "1"
os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = "--disable-gpu --disable-software-rasterizer"
sys.argv.append("--disable-gpu")
sys.argv.append("--no-sandbox")

from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QHBoxLayout, QLabel
from PyQt5.QtCore import QThread, pyqtSignal, Qt, QTimer
from PyQt5.QtWebEngineWidgets import QWebEngineView
from lightweight_charts.widgets import QtChart

class ZMQReceiverThread(QThread):
    data_received = pyqtSignal(dict)

    def __init__(self, port=5557, host='0.0.0.0'):
        super().__init__()
        self.port = port
        self.host = host
        self.running = True

    def run(self):
        context = zmq.Context()
        socket = context.socket(zmq.SUB)
        socket.connect(f"tcp://127.0.0.1:{self.port}")
        socket.setsockopt_string(zmq.SUBSCRIBE, "HUD ")

        self.msleep(2000)

        while self.running:
            latest_data = None
            while True:
                try:
                    msg = socket.recv_string(flags=zmq.NOBLOCK)
                    if msg.startswith("HUD "):
                        json_data = msg[4:]
                        latest_data = json.loads(json_data)
                except zmq.Again:
                    break
                except Exception as e:
                    print(f"ZMQ HUD Vételi Hiba: {e}", flush=True)
                    break

            if latest_data is not None:
                self.data_received.emit(latest_data)

            self.msleep(10)

    def stop(self):
        self.running = False
        self.wait()

class DualPaneHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules LGBM Copilot System v1.58")
        self.resize(1000, 800)
        self.setStyleSheet("background-color: #121212; color: #ffffff;")

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)

        info_layout = QHBoxLayout()
        self.signal_label = QLabel("Waiting for Prediction...")
        self.signal_label.setStyleSheet("color: gray; font-size: 18px; font-weight: bold;")
        self.signal_label.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        self.prob_label = QLabel("P_Long: 0.00 | P_Short: 0.00 | P_Noise: 0.00")
        self.prob_label.setStyleSheet("color: white; font-size: 16px; font-weight: bold;")
        self.prob_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        info_layout.addWidget(self.signal_label)
        info_layout.addWidget(self.prob_label)
        main_layout.addLayout(info_layout)

        self.chart = QtChart(inner_width=1, inner_height=0.6)
        self.chart.layout(background_color='#121212', text_color='#ffffff')
        self.chart.grid(vert_enabled=False, horz_enabled=False)
        self.chart.time_scale(visible=True, right_offset=15)
        self.chart.get_webview().setStyleSheet("background-color: #121212;")
        main_layout.addWidget(self.chart.get_webview(), stretch=3)

        self.bid_line = self.chart.horizontal_line(0.0, color='royalblue', width=1, style='dotted')
        self.ask_line = self.chart.horizontal_line(0.0, color='red', width=1, style='dotted')
        self.res_mic_line = self.chart.horizontal_line(0.0, color='rgba(255,165,0,0.4)', width=1, style='dashed')
        self.sup_mic_line = self.chart.horizontal_line(0.0, color='rgba(255,165,0,0.4)', width=1, style='dashed')
        self.res_sec_line = self.chart.horizontal_line(0.0, color='rgba(135,206,250,0.5)', width=2, style='solid')
        self.sup_sec_line = self.chart.horizontal_line(0.0, color='rgba(135,206,250,0.5)', width=2, style='solid')
        self.res_ter_line = self.chart.horizontal_line(0.0, color='rgba(255,0,255,0.6)', width=2, style='solid')
        self.sup_ter_line = self.chart.horizontal_line(0.0, color='rgba(255,0,255,0.6)', width=2, style='solid')
        self.pos_lines = {}

        self.subchart = self.chart.create_subchart(position='bottom', width=1, height=0.4, sync=True)
        self.subchart.time_scale(visible=True, seconds_visible=False, right_offset=15)
        self.subchart.candle_style(
            up_color='rgba(0,0,0,0)', down_color='rgba(0,0,0,0)',
            border_up_color='rgba(0,0,0,0)', border_down_color='rgba(0,0,0,0)',
            wick_up_color='rgba(0,0,0,0)', wick_down_color='rgba(0,0,0,0)'
        )

        self.p_long_line = self.subchart.create_line('P_Long', color='forestgreen', width=2, price_line=False)
        self.p_short_line = self.subchart.create_line('P_Short', color='firebrick', width=2, price_line=False)
        self.p_noise_line = self.subchart.create_line('P_Noise', color='gray', width=1, style='dotted', price_line=False)
        self.thr_long = self.subchart.horizontal_line(0.35, color='forestgreen', width=1, style='dashed', text='Thr_Long_Min')
        self.thr_short = self.subchart.horizontal_line(0.36, color='firebrick', width=1, style='dashed', text='Thr_Short_Min')
        self.thr_noise = self.subchart.horizontal_line(0.47, color='gray', width=1, style='dashed', text='Thr_Noise_Max')
        self.dummy_min = self.subchart.create_line('DummyMin', color='rgba(0,0,0,0)', width=1, price_label=True)
        self.dummy_max = self.subchart.create_line('DummyMax', color='rgba(0,0,0,0)', width=1, price_label=True)

        self.is_initialized = False
        self.current_minute_ts = None
        self.current_open = 0.0
        self.current_high = 0.0
        self.current_low = float('inf')

        self.zmq_thread = ZMQReceiverThread()
        self.zmq_thread.data_received.connect(self.on_data_received)
        self.chart.get_webview().loadFinished.connect(lambda: QTimer.singleShot(1000, self.zmq_thread.start))

    def on_data_received(self, data):
        try:
            raw_ts = pd.to_datetime(data['timestamp'], unit='s')
            minute_ts_dt = raw_ts.floor('min')
            ts_str = minute_ts_dt.strftime('%Y-%m-%d %H:%M:%S')

            price = data['close']

            if self.current_minute_ts != ts_str:
                self.current_minute_ts = ts_str
                self.current_open = data.get('open', price)
                self.current_high = data.get('high', price)
                self.current_low = data.get('low', price)

            self.current_high = max(self.current_high, price)
            self.current_low = min(self.current_low, price)

            candle_df = pd.DataFrame([{'time': ts_str, 'open': self.current_open, 'high': self.current_high, 'low': self.current_low, 'close': price}])
            dummy_df = pd.DataFrame([{'time': ts_str, 'open': 0.0, 'high': 1.0, 'low': 0.0, 'close': 0.5}])

            p_long_df = pd.DataFrame([{'time': ts_str, 'P_Long': data.get('p_long', 0.0)}])
            p_short_df = pd.DataFrame([{'time': ts_str, 'P_Short': data.get('p_short', 0.0)}])
            p_noise_df = pd.DataFrame([{'time': ts_str, 'P_Noise': data.get('p_noise', 0.0)}])

            if not self.is_initialized:
                import os
                csv_paths = [
                    "/home/misi/.wine/drive_c/Program Files/MetaTrader 5 IC Markets EU/MQL5/Files/history_init.csv",
                    "/home/misi/.mt5/drive_c/Program Files/Pepperstone MetaTrader 5/MQL5/Files/history_init.csv"
                ]
                df_hist = None
                for p in csv_paths:
                    if os.path.exists(p):
                        try:
                            df_hist = pd.read_csv(p)
                            break
                        except:
                            pass

                if df_hist is not None:
                    try:
                        df_hist['time'] = pd.to_datetime(df_hist['time'].astype(int), unit='s').dt.strftime('%Y-%m-%d %H:%M:%S')
                        final_df = pd.concat([df_hist, candle_df], ignore_index=True)
                        final_df = final_df.drop_duplicates(subset=['time'], keep='last')

                        self.chart.set(final_df)

                        times = final_df['time']
                        long_hist = pd.DataFrame({'time': times, 'P_Long': 0.0})
                        short_hist = pd.DataFrame({'time': times, 'P_Short': 0.0})
                        noise_hist = pd.DataFrame({'time': times, 'P_Noise': 0.0})

                        dummy_hist = pd.DataFrame({'time': times, 'open': 0.0, 'high': 1.0, 'low': 0.0, 'close': 0.5})
                        dmin_hist = pd.DataFrame({'time': times, 'DummyMin': 0.0})
                        dmax_hist = pd.DataFrame({'time': times, 'DummyMax': 1.0})

                        self.subchart.set(dummy_hist)
                        self.p_long_line.set(long_hist)
                        self.p_short_line.set(short_hist)
                        self.p_noise_line.set(noise_hist)
                        self.dummy_min.set(dmin_hist)
                        self.dummy_max.set(dmax_hist)

                        print("History fully loaded.", flush=True)
                    except Exception as e:
                        print("History load failed:", e)
                        self.chart.set(candle_df)
                        self.subchart.set(dummy_df)
                        self.p_long_line.set(p_long_df)
                        self.p_short_line.set(p_short_df)
                        self.p_noise_line.set(p_noise_df)
                        self.dummy_min.set(pd.DataFrame([{'time': ts_str, 'DummyMin': 0.0}]))
                        self.dummy_max.set(pd.DataFrame([{'time': ts_str, 'DummyMax': 1.0}]))
                else:
                    self.chart.set(candle_df)
                    self.subchart.set(dummy_df)
                    self.p_long_line.set(p_long_df)
                    self.p_short_line.set(p_short_df)
                    self.p_noise_line.set(p_noise_df)
                    self.dummy_min.set(pd.DataFrame([{'time': ts_str, 'DummyMin': 0.0}]))
                    self.dummy_max.set(pd.DataFrame([{'time': ts_str, 'DummyMax': 1.0}]))

                self.bid_line.update(data.get('bid', price))
                self.ask_line.update(data.get('ask', price))
                self.res_mic_line.update(data.get('res_micro', 0.0001))
                self.sup_mic_line.update(data.get('sup_micro', 0.0001))
                self.res_sec_line.update(data.get('res_sec', 0.0001))
                self.sup_sec_line.update(data.get('sup_sec', 0.0001))
                self.res_ter_line.update(data.get('res_ter', 0.0001))
                self.sup_ter_line.update(data.get('sup_ter', 0.0001))

                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])

                active_prices = []
                for pt, pp in zip(pos_types, pos_prices):
                    if pt != 0:
                        active_prices.append(pp)

                for pp in active_prices:
                    if pp not in self.pos_lines:
                        self.pos_lines[pp] = self.chart.horizontal_line(pp, color='cyan', width=1, style='solid')
                    else:
                        self.pos_lines[pp].update(pp)

                prices_to_delete = []
                for existing_pp in self.pos_lines.keys():
                    if existing_pp not in active_prices:
                        self.pos_lines[existing_pp].delete()
                        prices_to_delete.append(existing_pp)

                for pp in prices_to_delete:
                    del self.pos_lines[pp]

                self.is_initialized = True
            else:
                # Update loop
                s_c = candle_df.iloc[0].copy()
                s_c.name = None
                self.chart.update(s_c)

                self.bid_line.update(data.get('bid', price))
                self.ask_line.update(data.get('ask', price))
                self.res_mic_line.update(data.get('res_micro', 0.0001))
                self.sup_mic_line.update(data.get('sup_micro', 0.0001))
                self.res_sec_line.update(data.get('res_sec', 0.0001))
                self.sup_sec_line.update(data.get('sup_sec', 0.0001))
                self.res_ter_line.update(data.get('res_ter', 0.0001))
                self.sup_ter_line.update(data.get('sup_ter', 0.0001))

                pos_types = data.get('pos_types', [0])
                pos_prices = data.get('pos_prices', [0.0])

                active_prices = []
                for pt, pp in zip(pos_types, pos_prices):
                    if pt != 0:
                        active_prices.append(pp)

                for pp in active_prices:
                    if pp not in self.pos_lines:
                        self.pos_lines[pp] = self.chart.horizontal_line(pp, color='cyan', width=1, style='solid')
                    else:
                        self.pos_lines[pp].update(pp)

                prices_to_delete = []
                for existing_pp in self.pos_lines.keys():
                    if existing_pp not in active_prices:
                        self.pos_lines[existing_pp].delete()
                        prices_to_delete.append(existing_pp)

                for pp in prices_to_delete:
                    del self.pos_lines[pp]

                dummy_s = dummy_df.iloc[0].copy()
                dummy_s.name = None
                self.subchart.update(dummy_s)

                s_l = pd.Series({'time': ts_str, 'P_Long': data.get('p_long', 0.0)})
                s_l.name = 'P_Long'
                self.p_long_line.update(s_l)

                s_s = pd.Series({'time': ts_str, 'P_Short': data.get('p_short', 0.0)})
                s_s.name = 'P_Short'
                self.p_short_line.update(s_s)

                s_n = pd.Series({'time': ts_str, 'P_Noise': data.get('p_noise', 0.0)})
                s_n.name = 'P_Noise'
                self.p_noise_line.update(s_n)

                s_min = pd.Series({'time': ts_str, 'DummyMin': 0.0})
                s_min.name = 'DummyMin'
                self.dummy_min.update(s_min)

                s_max = pd.Series({'time': ts_str, 'DummyMax': 1.0})
                s_max.name = 'DummyMax'
                self.dummy_max.update(s_max)

            s_val = data.get('signal', 0)
            if s_val == 1:
                self.signal_label.setText(f"SIGNAL: BUY")
                self.signal_label.setStyleSheet("color: forestgreen; font-size: 18px; font-weight: bold;")
            elif s_val == -1:
                self.signal_label.setText(f"SIGNAL: SELL")
                self.signal_label.setStyleSheet("color: firebrick; font-size: 18px; font-weight: bold;")
            else:
                self.signal_label.setText(f"SIGNAL: HOLD")
                self.signal_label.setStyleSheet("color: gray; font-size: 18px; font-weight: bold;")

            p_l = data.get('p_long', 0)
            p_s = data.get('p_short', 0)
            p_n = data.get('p_noise', 0)
            self.prob_label.setText(f"P_Long: {p_l:.2f} | P_Short: {p_s:.2f} | P_Noise: {p_n:.2f}")

        except Exception as e:
            print(f"Exception in HUD data logic: {e}", flush=True)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = DualPaneHUD()
    window.show()
    sys.exit(app.exec_())
