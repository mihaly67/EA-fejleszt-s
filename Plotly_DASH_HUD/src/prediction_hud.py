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
# We severely reduce MAX_POINTS. To have a "rolling window",
# we only keep the last e.g. 150 ticks in memory for plotting.
MAX_POINTS = 150
time_data = deque(maxlen=MAX_POINTS)
p_long_data = deque(maxlen=MAX_POINTS)
p_short_data = deque(maxlen=MAX_POINTS)
p_noise_data = deque(maxlen=MAX_POINTS)

def zmq_listener():
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect("tcp://127.0.0.1:5557")
    socket.setsockopt_string(zmq.SUBSCRIBE, "HUD ")

    while True:
        try:
            msg = socket.recv_string()
            if msg.startswith("HUD "):
                data = json.loads(msg[4:])

                # Plotly uses standard datetime objects for time series
                ts = datetime.datetime.fromtimestamp(data['timestamp'])

                time_data.append(ts)
                p_long_data.append(data.get('p_long', 0.0))
                p_short_data.append(data.get('p_short', 0.0))
                p_noise_data.append(data.get('p_noise', 0.0))
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
        interval=500, # 500 ms = 2 updates per second
        n_intervals=0
    )
])

@app.callback(Output('live-update-graph', 'figure'),
              Input('interval-component', 'n_intervals'))
def update_graph_live(n):
    fig = go.Figure()

    # Convert deques to lists to plot them
    t_list = list(time_data)
    l_list = list(p_long_data)
    s_list = list(p_short_data)
    n_list = list(p_noise_data)

    if len(t_list) > 0:
        fig.add_trace(go.Scatter(
            x=t_list,
            y=l_list,
            name='P_Long',
            mode='lines',
            line=dict(color='forestgreen', width=2, shape='linear')
        ))

        fig.add_trace(go.Scatter(
            x=t_list,
            y=s_list,
            name='P_Short',
            mode='lines',
            line=dict(color='firebrick', width=2, shape='linear')
        ))

        fig.add_trace(go.Scatter(
            x=t_list,
            y=n_list,
            name='P_Noise',
            mode='lines',
            line=dict(color='gray', width=1, dash='dot', shape='linear')
        ))

        # Dynamically set X-axis range to enforce the rolling window visually
        x_min = t_list[0]
        x_max = t_list[-1]
    else:
        # Default empty range if no data yet
        x_min = None
        x_max = None

    # Add dynamic horizontal lines for Asymmetric Thresholds (e.g. 0.45)
    fig.add_hline(y=0.45, line_dash="dash", line_color="forestgreen", annotation_text="Long Threshold", annotation_position="top right")
    fig.add_hline(y=0.40, line_dash="dash", line_color="firebrick", annotation_text="Short Threshold", annotation_position="bottom right")

    fig.update_layout(
        template='plotly_dark',
        plot_bgcolor='#121212',
        paper_bgcolor='#121212',
        margin=dict(l=0, r=40, t=0, b=0),
        # By setting the range dynamically, the chart strictly follows the points without auto-scaling all of history
        xaxis=dict(range=[x_min, x_max] if x_min and x_max else None, showgrid=True, gridcolor='#333333', rangeslider=dict(visible=False)),
        yaxis=dict(range=[0, 1], showgrid=True, gridcolor='#333333', side='right', tickformat='.2f'),
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1
        ),
        # Optimize performance for real-time updates
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
        self.resize(1000, 400) # Only probability chart for now

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(0, 0, 0, 0)

        # Allow Dash server to boot
        time.sleep(1)

        self.browser = QWebEngineView()
        self.browser.setUrl(QUrl("http://127.0.0.1:8050"))
        layout.addWidget(self.browser)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = DashHUD()
    window.show()
    sys.exit(app.exec_())
