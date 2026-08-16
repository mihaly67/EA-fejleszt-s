import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget
from lightweight_charts.widgets import QtChart
import sys

app = QApplication(sys.argv)
window = QMainWindow()
chart = QtChart()

line = chart.create_line('Test')
ts = pd.to_datetime(1786842947.2848263, unit='s')
p_long_data = pd.Series({'time': ts, 'Test': 0.5})

try:
    line.update(p_long_data)
    print("Success: update works.")
except Exception as e:
    print("Error with update:", e)
