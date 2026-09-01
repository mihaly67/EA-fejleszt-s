import sys
import subprocess
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QWidget,
                             QLabel, QTextEdit, QSystemTrayIcon, QMenu, QAction, QStyle)
from PyQt5.QtCore import QTimer, Qt

class SysMonitor(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Jules SSH & Tailscale Monitor")
        self.resize(650, 500)

        # Main Widget and Layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)

        # Title Label
        self.title_label = QLabel("<b>Jules Box Rendszer Állapot (MX Linux / SysVinit)</b>")
        self.title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.title_label)

        # Text Area for Status
        self.status_text = QTextEdit()
        self.status_text.setReadOnly(True)
        # Apply some basic styling
        self.status_text.setStyleSheet("background-color: #1e1e1e; color: #ffffff; font-family: monospace; font-size: 13px;")
        layout.addWidget(self.status_text)

        # Setup System Tray
        self.tray_icon = QSystemTrayIcon(self)
        self.tray_icon.setIcon(self.style().standardIcon(QStyle.SP_ComputerIcon))

        show_action = QAction("Show", self)
        quit_action = QAction("Exit", self)
        hide_action = QAction("Hide", self)

        show_action.triggered.connect(self.showNormal)
        hide_action.triggered.connect(self.hide)
        quit_action.triggered.connect(QApplication.instance().quit)

        tray_menu = QMenu()
        tray_menu.addAction(show_action)
        tray_menu.addAction(hide_action)
        tray_menu.addAction(quit_action)

        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()

        # Update Timer
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_status)
        self.timer.start(5000) # 5 seconds

        # Initial Update
        self.update_status()

    def run_cmd(self, cmd):
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=3)
            return result.stdout.strip() if result.stdout else result.stderr.strip()
        except Exception as e:
            return str(e)

    def update_status(self):
        output = "=== SSH SZOLGÁLTATÁS ÁLLAPOTA ===\n"
        # Since it is MX Linux with SysVinit, we directly query the init script
        ssh_status = self.run_cmd("/etc/init.d/ssh status")
        output += f"{ssh_status}\n\n"

        output += "=== NYITOTT PORTOK (Tűzfal / Listen) ===\n"
        ports = self.run_cmd("ss -ltn | grep -E ':22 |:8000 |:8765 |:5555 |:5556 |:5557 '")
        output += f"{ports}\n\n"

        output += "=== TAILSCALE HÁLÓZAT (Devboxok) ===\n"
        ts_status = self.run_cmd("tailscale status")
        output += f"{ts_status}\n"

        self.status_text.setText(output)

    def closeEvent(self, event):
        # Override close event to minimize to tray instead of exiting
        event.ignore()
        self.hide()
        self.tray_icon.showMessage(
            "Monitor Fut",
            "Az alkalmazás a tálcára került.",
            QSystemTrayIcon.Information,
            2000
        )

if __name__ == "__main__":
    app = QApplication(sys.argv)
    QApplication.setQuitOnLastWindowClosed(False)

    monitor = SysMonitor()
    monitor.show()

    sys.exit(app.exec_())
