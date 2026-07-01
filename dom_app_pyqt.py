import sys
import socket
import threading
import numpy as np
from PyQt5.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QLabel, QTableWidget, QTableWidgetItem, QHeaderView, QAbstractItemView, QStyledItemDelegate, QStyle
from PyQt5.QtCore import QTimer, Qt, pyqtSignal, QObject, QRect
from PyQt5.QtGui import QColor, QFont, QPainter, QBrush

# --- GLOBÁLIS ADATTÁR ---
LATEST_DOM_DATA = {
    'time': 0,
    'price': 0.0,
    'av1': 0, 'av2': 0, 'bv1': 0, 'bv2': 0,
    'ap1': 0.0, 'ap2': 0.0, 'bp1': 0.0, 'bp2': 0.0
}

# Jelsugárzó a UI szál értesítésére
class SignalEmitter(QObject):
    data_updated = pyqtSignal()

emitter = SignalEmitter()

# --- MT5 ZMQ/TCP BRIDGE (HÁTTÉRSZÁL) ---
class MT5DOMBridge(threading.Thread):
    def __init__(self, host='0.0.0.0', port=5555):
        super().__init__()
        self.host = host
        self.port = port
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        self.client_socket = None

    def run(self):
        print(f"[DOM-BRIDGE] DOM HUD Bridge indul ezen: {self.host}:{self.port}")
        while self.running:
            try:
                self.server_socket.settimeout(2.0)
                try:
                    client, addr = self.server_socket.accept()
                    self.client_socket = client
                    self.client_socket.settimeout(None)
                    print(f"[DOM-BRIDGE] EA Csatlakozott: {addr}")
                except socket.timeout:
                    continue

                buffer = ""
                while self.running and self.client_socket:
                    try:
                        data = self.client_socket.recv(1048576).decode('utf-8')
                        if not data:
                            print("[DOM-BRIDGE] EA Kapcsolat megszakadt.")
                            break
                        buffer += data
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            self.process_message(line.strip())
                    except Exception as e:
                        print(f"[DOM-BRIDGE] Hiba a hálózatban: {e}")
                        break
            except Exception as e:
                print(f"[DOM-BRIDGE] Fő ciklus hiba: {e}")

    def process_message(self, message):
        global LATEST_DOM_DATA
        if not message: return
        parts = message.split('|')
        cmd = parts[0]

        if cmd == "TICK":
            if len(parts) < 15: return
            try:
                LATEST_DOM_DATA['time'] = float(parts[1])
                LATEST_DOM_DATA['price'] = (float(parts[2]) + float(parts[3])) / 2.0

                LATEST_DOM_DATA['av1'] = int(parts[7])
                LATEST_DOM_DATA['av2'] = int(parts[8])
                LATEST_DOM_DATA['bv1'] = int(parts[9])
                LATEST_DOM_DATA['bv2'] = int(parts[10])

                LATEST_DOM_DATA['ap1'] = float(parts[11])
                LATEST_DOM_DATA['ap2'] = float(parts[12])
                LATEST_DOM_DATA['bp1'] = float(parts[13])
                LATEST_DOM_DATA['bp2'] = float(parts[14])

                # Értesítjük a GUI-t a frissítésről
                emitter.data_updated.emit()
            except ValueError:
                pass


# --- DYNAMIC BAR DELEGATE ---
class DOMBarDelegate(QStyledItemDelegate):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.max_vol = 1

    def set_max_vol(self, mv):
        self.max_vol = mv if mv > 0 else 1

    def paint(self, painter, option, index):
        painter.save()

        # Alap háttér rajzolása
        bg_color_role = index.data(Qt.BackgroundRole)
        if bg_color_role:
            if isinstance(bg_color_role, QBrush):
                painter.fillRect(option.rect, bg_color_role.color())
            else:
                painter.fillRect(option.rect, bg_color_role)
        else:
            painter.fillRect(option.rect, QColor(11, 14, 20))

        # Adat beolvasása (Volumen)
        text = index.data(Qt.DisplayRole)
        col = index.column()

        if text and text.isdigit():
            vol = int(text)
            if vol > 0:
                # Kiszámítjuk a százalékos szélességet a cella aktuális méretéből
                width_ratio = min(vol / self.max_vol, 1.0)
                bar_width = int(option.rect.width() * width_ratio)

                # Oszlop 0 (Bid): Zöld sáv, ami a cella jobb széléről indul balra (középpontból kifelé)
                if col == 0:
                    bar_rect = QRect(option.rect.right() - bar_width, option.rect.top() + 4, bar_width, option.rect.height() - 8)
                    painter.fillRect(bar_rect, QColor(0, 230, 118, 60))
                    painter.fillRect(QRect(option.rect.right() - 2, option.rect.top() + 4, 2, option.rect.height() - 8), QColor(0, 230, 118, 200)) # Erős perem

                # Oszlop 2 (Ask): Piros sáv, ami a cella bal széléről indul jobbra (középpontból kifelé)
                elif col == 2:
                    bar_rect = QRect(option.rect.left(), option.rect.top() + 4, bar_width, option.rect.height() - 8)
                    painter.fillRect(bar_rect, QColor(255, 82, 82, 60))
                    painter.fillRect(QRect(option.rect.left(), option.rect.top() + 4, 2, option.rect.height() - 8), QColor(255, 82, 82, 200)) # Erős perem

        # Szöveg kiírása a sávok FELÉ
        text_color_role = index.data(Qt.ForegroundRole)
        if text_color_role:
            if isinstance(text_color_role, QBrush):
                painter.setPen(text_color_role.color())
            else:
                painter.setPen(text_color_role)
        else:
            painter.setPen(QColor(255, 255, 255))

        align = index.data(Qt.TextAlignmentRole)
        if not align: align = Qt.AlignCenter | Qt.AlignVCenter

        # Pici padding a szövegnek
        text_rect = option.rect.adjusted(10, 0, -10, 0)
        painter.drawText(text_rect, align, text if text else "")

        painter.restore()


# --- PYQT5 NATIVE UI ---
class DOMWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🧱 Tőzsdei DOM Monitor (PyQt5)")
        self.resize(500, 700)
        self.setStyleSheet("background-color: #121212; color: #ffffff;")
        self.depth_levels = 10
        self.tick_size_estimate = 0.05

        self.init_ui()

        # 1.5 másodpercenként garantált vizuális frissítés akkor is, ha nincs friss tick
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_gui)
        self.timer.start(1500)

        # Ha érkezik egy Tick, azonnal frissítjük a GUI-t
        emitter.data_updated.connect(self.update_gui)

    def init_ui(self):
        central_widget = QWidget()
        layout = QVBoxLayout(central_widget)

        # KPI Header
        kpi_layout = QHBoxLayout()
        self.lbl_bid = QLabel("Legjobb Vétel:\n-")
        self.lbl_ask = QLabel("Legjobb Eladás:\n-")
        self.lbl_spread = QLabel("Spread:\n-")

        for lbl in [self.lbl_bid, self.lbl_ask, self.lbl_spread]:
            lbl.setAlignment(Qt.AlignCenter)
            lbl.setFont(QFont("Arial", 12, QFont.Bold))
            lbl.setStyleSheet("background-color: #1e1e1e; padding: 10px; border-radius: 5px;")
            kpi_layout.addWidget(lbl)

        layout.addLayout(kpi_layout)

        # DOM Létra Táblázat
        self.table = QTableWidget()
        self.table.setColumnCount(3)
        self.table.setHorizontalHeaderLabels(["Vétel (Bid)", "Ár", "Eladás (Ask)"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.verticalHeader().setVisible(False)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setSelectionMode(QAbstractItemView.NoSelection)
        self.table.setFocusPolicy(Qt.NoFocus)
        self.table.setShowGrid(False)
        self.table.setStyleSheet("""
            QTableWidget { background-color: #0b0e14; border: none; font-family: 'Courier New'; font-size: 15px; font-weight: bold;}
            QHeaderView::section { background-color: #1e222d; color: #787b86; padding: 10px; font-weight: bold; border: 1px solid #2B2B43;}
        """)

        self.delegate = DOMBarDelegate(self.table)
        self.table.setItemDelegateForColumn(0, self.delegate)
        self.table.setItemDelegateForColumn(2, self.delegate)

        layout.addWidget(self.table)
        self.setCentralWidget(central_widget)

    def get_dom_data(self, live_data):
        mid_price = live_data['price']
        if mid_price == 0.0: mid_price = 150.00

        # Dinamikus Tick size
        if live_data['bp1'] > 0 and live_data['ap1'] > 0:
            self.tick_size_estimate = live_data['ap1'] - live_data['bp1']
            if self.tick_size_estimate == 0: self.tick_size_estimate = 0.01
            if self.tick_size_estimate > 1.0: self.tick_size_estimate = 0.1

        mid_rounded = np.round(mid_price / self.tick_size_estimate) * self.tick_size_estimate
        prices = np.arange(mid_rounded + (self.depth_levels * self.tick_size_estimate), mid_rounded - (self.depth_levels * self.tick_size_estimate) - self.tick_size_estimate, -self.tick_size_estimate)
        prices = np.round(prices, 5)

        bids, asks = [], []
        best_bid = live_data['bp1'] if live_data['bp1'] > 0 else mid_rounded - self.tick_size_estimate
        best_ask = live_data['ap1'] if live_data['ap1'] > 0 else mid_rounded + self.tick_size_estimate

        for p in prices:
            # Ask Levels
            if abs(p - live_data['ap2']) < 0.00001 and live_data['av2'] > 0:
                bids.append(0); asks.append(live_data['av2'])
            elif abs(p - live_data['ap1']) < 0.00001 and live_data['av1'] > 0:
                bids.append(0); asks.append(live_data['av1'])
            # Bid Levels
            elif abs(p - live_data['bp1']) < 0.00001 and live_data['bv1'] > 0:
                bids.append(live_data['bv1']); asks.append(0)
            elif abs(p - live_data['bp2']) < 0.00001 and live_data['bv2'] > 0:
                bids.append(live_data['bv2']); asks.append(0)
            else:
                bids.append(0); asks.append(0)

        spread_value = max(0, best_ask - best_bid)
        return prices, bids, asks, best_bid, best_ask, spread_value

    def update_gui(self):
        current_data = LATEST_DOM_DATA.copy()
        prices, bids, asks, best_bid, best_ask, spread = self.get_dom_data(current_data)

        # Frissítjük a KPI fejléceket
        if best_bid > 0 and best_ask > 0 and current_data['price'] > 0:
            self.lbl_bid.setText(f"Legjobb Vétel:\n{best_bid:.5f}")
            self.lbl_ask.setText(f"Legjobb Eladás:\n{best_ask:.5f}")
            self.lbl_spread.setText(f"Spread:\n{spread:.5f}")

        # Dinamikus Max Volumen kiszámítása a Delegate skálázásához
        current_max_vol = 0
        if bids: current_max_vol = max(current_max_vol, max(bids))
        if asks: current_max_vol = max(current_max_vol, max(asks))
        self.delegate.set_max_vol(current_max_vol)

        # Táblázat feltöltése
        self.table.setRowCount(len(prices))
        for i in range(len(prices)):
            price = prices[i]
            bid_vol = bids[i]
            ask_vol = asks[i]

            # --- CELLÁK LÉTREHOZÁSA ---
            item_bid = QTableWidgetItem(str(bid_vol) if bid_vol > 0 else "")
            item_bid.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)

            item_price = QTableWidgetItem(f"{price:.5f}")
            item_price.setTextAlignment(Qt.AlignCenter | Qt.AlignVCenter)

            item_ask = QTableWidgetItem(str(ask_vol) if ask_vol > 0 else "")
            item_ask.setTextAlignment(Qt.AlignLeft | Qt.AlignVCenter)

            # --- SZÍNEZÉS ÉS MEGJELENÉS (DELEGATE KEZELI A HÁTTEREKET) ---
            # 1. Eladás (Ask) sor
            if ask_vol > 0:
                item_ask.setForeground(QColor(255, 82, 82))
                item_price.setBackground(QColor(19, 23, 34)); item_price.setForeground(QColor(255, 82, 82))
                item_ask.setBackground(QColor(11, 14, 20)); item_bid.setBackground(QColor(11, 14, 20))

            # 2. Vétel (Bid) sor
            elif bid_vol > 0:
                item_bid.setForeground(QColor(0, 230, 118))
                item_price.setBackground(QColor(19, 23, 34)); item_price.setForeground(QColor(0, 230, 118))
                item_ask.setBackground(QColor(11, 14, 20)); item_bid.setBackground(QColor(11, 14, 20))

            # 3. Spread mező
            elif best_bid < price < best_ask:
                bg_spread = QColor(30, 34, 45)
                bg_spread_price = QColor(42, 46, 57)
                item_bid.setBackground(bg_spread)
                item_ask.setBackground(bg_spread)
                item_price.setBackground(bg_spread_price)
                item_price.setForeground(QColor(120, 123, 134))

            # 4. Üres sor
            else:
                item_bid.setBackground(QColor(11, 14, 20))
                item_ask.setBackground(QColor(11, 14, 20))
                item_price.setBackground(QColor(19, 23, 34))
                item_price.setForeground(QColor(200, 200, 200))

            self.table.setItem(i, 0, item_bid)
            self.table.setItem(i, 1, item_price)
            self.table.setItem(i, 2, item_ask)


if __name__ == '__main__':
    # ZMQ Bridge elindítása
    bridge = MT5DOMBridge(host='0.0.0.0', port=5556)
    bridge.start()

    # GUI elindítása
    app = QApplication(sys.argv)
    window = DOMWindow()
    window.show()
    sys.exit(app.exec_())
