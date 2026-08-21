import sys
import os
import time
import json
import threading
from collections import deque
import zmq
import pandas as pd
import datetime

import dash
from dash import dcc, html
from dash.dependencies import Input, Output
import plotly.graph_objects as go

from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from PyQt5.QtCore import QUrl
from PyQt5.QtWebEngineWidgets import QWebEngineView

# Disable GPU for remote RDP compatibility
os.environ["QTWEBENGINE_DISABLE_GPU"] = "1"
os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] = "--disable-gpu --disable-software-rasterizer"

# Data Cache
# We only store the *actual prediction points* (when Dollar Bars close) to connect them with straight lines.
MAX_PRED_POINTS = 50
pred_time_data = deque(maxlen=MAX_PRED_POINTS)
p_long_data = deque(maxlen=MAX_PRED_POINTS)
p_short_data = deque(maxlen=MAX_PRED_POINTS)
p_noise_data = deque(maxlen=MAX_PRED_POINTS)

# Track the absolute latest tick time for smooth X-axis panning
latest_tick_time = None

def zmq_listener():
    global latest_tick_time
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect("tcp://127.0.0.1:5557")
    socket.setsockopt_string(zmq.SUBSCRIBE, "HUD ")

    last_signal = None
    last_pl = None
    last_ps = None
    last_pn = None

    while True:
        try:
            msg = socket.recv_string()
            if msg.startswith("HUD "):
                data = json.loads(msg[4:])

                # Update the continuous time clock for smooth panning
                ts = datetime.datetime.fromtimestamp(data['timestamp'])
                latest_tick_time = ts

                pl = data.get('p_long', 0.0)
                ps = data.get('p_short', 0.0)
                pn = data.get('p_noise', 0.0)
                sig = data.get('signal', 0)

                # ONLY append a new point if the prediction actually changed!
                # This ensures we connect point A to point B diagonally, rather than building a staircase
                if (pl != last_pl or ps != last_ps or pn != last_pn):

                    # Prevent identical timestamps causing back-and-forth loops
                    if len(pred_time_data) == 0 or ts > pred_time_data[-1]:
                        pred_time_data.append(ts)
                        p_long_data.append(pl)
                        p_short_data.append(ps)
                        p_noise_data.append(pn)

                        last_pl = pl
                        last_ps = ps
                        last_pn = pn

        except Exception as e:
            print(f"ZMQ Error: {e}")

# Start ZMQ thread
threading.Thread(target=zmq_listener, daemon=True).start()
print("ZMQ listener configured and started.")

# --- Dash App Setup ---
app = dash.Dash(__name__)

app.layout = html.Div(style={'backgroundColor': '#121212', 'height': '100vh', 'margin': '0'}, children=[
    dcc.Graph(id='live-update-graph', style={'height': '100%'}),
    dcc.Interval(
        id='interval-component',
        interval=250, # Fast 250ms update for smooth panning
        n_intervals=0
    )
])

@app.callback(Output('live-update-graph', 'figure'),
              Input('interval-component', 'n_intervals'))
def update_graph_live(n):
    fig = go.Figure()

    t_list = list(pred_time_data)
    l_list = list(p_long_data)
    s_list = list(p_short_data)
    n_list = list(p_noise_data)

    if len(t_list) > 0:
        # Add actual prediction nodes connected by straight diagonal lines
        fig.add_trace(go.Scatter(
            x=t_list,
            y=l_list,
            name='P_Long',
            mode='lines+markers',
            marker=dict(size=6, color='forestgreen'),
            line=dict(color='forestgreen', width=2, shape='linear')
        ))

        fig.add_trace(go.Scatter(
            x=t_list,
            y=s_list,
            name='P_Short',
            mode='lines+markers',
            marker=dict(size=6, color='firebrick'),
            line=dict(color='firebrick', width=2, shape='linear')
        ))

        fig.add_trace(go.Scatter(
            x=t_list,
            y=n_list,
            name='P_Noise',
            mode='lines+markers',
            marker=dict(size=6, color='gray'),
            line=dict(color='gray', width=1, dash='dot', shape='linear')
        ))

    # Calculate Smooth Panning Window (e.g., show the last X minutes based on latest tick)
    x_min = None
    x_max = None

    if latest_tick_time:
        # Always pin the right side to the absolute latest tick time (smooth scroll)
        x_max = latest_tick_time
        # Show a static rolling window width (e.g., 20 minutes)
        x_min = latest_tick_time - datetime.timedelta(minutes=20)
    elif len(t_list) > 0:
        x_max = t_list[-1]
        x_min = t_list[0]

    # Add dynamic horizontal lines for Asymmetric Thresholds
    fig.add_hline(y=0.45, line_dash="dash", line_color="forestgreen", annotation_text="Long Threshold", annotation_position="top left")
    fig.add_hline(y=0.40, line_dash="dash", line_color="firebrick", annotation_text="Short Threshold", annotation_position="bottom left")

    fig.update_layout(
        template='plotly_dark',
        plot_bgcolor='#121212',
        paper_bgcolor='#121212',
        margin=dict(l=0, r=40, t=0, b=0),
        xaxis=dict(
            range=[x_min, x_max] if x_min and x_max else None,
            showgrid=True,
            gridcolor='#333333',
            rangeslider=dict(visible=False),
            type='date'
        ),
        yaxis=dict(
            range=[0, 1],
            showgrid=True,
            gridcolor='#333333',
            side='right',
            tickformat='.2f'
        ),
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1
        ),
        # Optimize performance for real-time panning updates
        uirevision='constant'
    )

    return fig

def run_dash():
    app.run(debug=False, port=8050, use_reloader=False)

# Start Dash server in a background thread
dash_thread = threading.Thread(target=run_dash, daemon=True)
dash_thread.start()
print("Dash server started on port 8050.")

# --- PyQt5 Wrapper ---
class DashHUD(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Merkava Copilot - Plotly Dash HUD")
        self.resize(1000, 400)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)

        time.sleep(1)

        self.browser = QWebEngineView()
        self.browser.setUrl(QUrl("http://127.0.0.1:8050"))
        layout.addWidget(self.browser)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = DashHUD()
    window.show()
    sys.exit(app.exec_())
