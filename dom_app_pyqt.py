import sys
import threading
import time
import pandas as pd
import numpy as np
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout,
                             QWidget, QLabel, QTableWidget, QTableWidgetItem,
                             QHeaderView, QAbstractItemView, QStyledItemDelegate, QSlider, QPushButton, QProgressBar)
from PyQt5.QtCore import QTimer, Qt, pyqtSignal, QObject, QRect
from PyQt5.QtGui import QColor, QFont, QPainter, QBrush

# --- GLOBÁLIS ADATTÁR ---
LATEST_DOM_DATA = {
    'time': 0, 'price': 0.0,
    'av1': 0, 'av2': 0, 'bv1': 0, 'bv2': 0,
    'ap1': 0.0, 'ap2': 0.0, 'bp1': 0.0, 'bp2': 0.0
}

class SignalEmitter(QObject):
    data_updated = pyqtSignal()

emitter = SignalEmitter()

# --- CSV OFFLINE PLAYER (HÁTTÉRSZÁL EPOCH SZIMULÁCIÓVAL) ---
class CSVDOMPlayer(threading.Thread):
    def __init__(self, filepath, speed=1.0):
        super().__init__()
        self.filepath = filepath
        self.speed = speed
        self.running = False
        self.paused = False
        self.df = None
        self.current_idx = 0
        self.total_rows = 0
        self.virtual_epoch_msc = 0.0
        self.last_real_time = 0.0

    def load_data(self):
        print(f"[CSV-PLAYER] Fájl betöltése: {self.filepath}")
        try:
            self.df = pd.read_csv(self.filepath)
            original_rows = len(self.df)
            # Töröljük a 0 ms-os duplikált DOM screenshotokat, hogy csak a valós elmozdulások maradjanak (teljesítmény javítás)
            self.df = self.df.drop_duplicates(subset=['TimeMsc'], keep='last').reset_index(drop=True)
            self.total_rows = len(self.df)
            print(f"[CSV-PLAYER] Sikeresen betöltve {original_rows} sor. Szűrés után (duplikátumok nélkül): {self.total_rows} VALÓS tick.")
            return True
        except Exception as e:
            print(f"[CSV-PLAYER] Hiba a fájl beolvasásakor: {e}")
            return False

    def run(self):
        if self.df is None and not self.load_data():
            return

        self.running = True
        print("[CSV-PLAYER] Epoch Lejátszás indítva...")

        while self.running:
            if self.paused or self.current_idx >= self.total_rows:
                time.sleep(0.05)
                self.last_real_time = 0.0 # reset on pause
                continue

            # Inicializáljuk az epoch órát a legelső tickből induláskor vagy tekerés után
            if self.last_real_time == 0.0:
                self.virtual_epoch_msc = float(self.df.iloc[self.current_idx]['TimeMsc'])
                self.last_real_time = time.time()

            # Frissítjük a virtuális Epoch órát a valós eltelt idő * sebesség alapján
            current_real_time = time.time()
            real_delta_sec = current_real_time - self.last_real_time
            self.virtual_epoch_msc += (real_delta_sec * 1000.0) * self.speed
            self.last_real_time = current_real_time

            # Beküldjük az ÖSSZES ticket, aminek az Epoch ideje <= a mi virtuális óránknál
            # Így nagy sebességnél is garantáltan beküld minden sorozatot, nem hagy ki semmit.
            ticks_sent = 0
            while self.current_idx < self.total_rows:
                row = self.df.iloc[self.current_idx]
                tick_epoch = float(row['TimeMsc'])

                # Extrém szünet (pl. hétvége gap) kezelése: ha a következő tick több mint 1 percre van, tekerjük előre az órát
                if (tick_epoch - self.virtual_epoch_msc) > 60000.0:
                    self.virtual_epoch_msc = tick_epoch - 50.0

                if tick_epoch <= self.virtual_epoch_msc:
                    global LATEST_DOM_DATA
                    LATEST_DOM_DATA['time'] = tick_epoch
                    # Fallback logikák a különböző CSV formátumok miatti hiányzó kulcsok elkerülésére
                    if 'Type' in row:
                        if row['Type'] == 1: # Ask
                            ask = float(row['Price'])
                            bid = float(row.get('Bid', ask - 0.01))
                            av1 = int(row['Volume'])
                            bv1 = int(row.get('BidVol', 0))
                        else: # Bid
                            bid = float(row['Price'])
                            ask = float(row.get('Ask', bid + 0.01))
                            bv1 = int(row['Volume'])
                            av1 = int(row.get('AskVol', 0))
                        ap1 = ask
                        bp1 = bid
                        av2 = 0
                        bv2 = 0
                        ap2 = ask + 0.01
                        bp2 = bid - 0.01
                    else:
                        # Ha megvannak az explicit oszlopok (Merkava DOM Miner formátum)
                        bid = float(row.get('Bid', row.get('Bid_Price_1', 0)))
                        ask = float(row.get('Ask', row.get('Ask_Price_1', 0)))
                        av1 = int(row.get('Ask_Vol_1', 0))
                        av2 = int(row.get('Ask_Vol_2', 0))
                        bv1 = int(row.get('Bid_Vol_1', 0))
                        bv2 = int(row.get('Bid_Vol_2', 0))
                        ap1 = float(row.get('Ask_Price_1', 0))
                        ap2 = float(row.get('Ask_Price_2', 0))
                        bp1 = float(row.get('Bid_Price_1', 0))
                        bp2 = float(row.get('Bid_Price_2', 0))

                    LATEST_DOM_DATA['price'] = (bid + ask) / 2.0
                    LATEST_DOM_DATA['av1'] = av1
                    LATEST_DOM_DATA['av2'] = av2
                    LATEST_DOM_DATA['bv1'] = bv1
                    LATEST_DOM_DATA['bv2'] = bv2
                    LATEST_DOM_DATA['ap1'] = ap1
                    LATEST_DOM_DATA['ap2'] = ap2
                    LATEST_DOM_DATA['bp1'] = bp1
                    LATEST_DOM_DATA['bp2'] = bp2

                    emitter.data_updated.emit()
                    self.current_idx += 1
                    ticks_sent += 1

                    # Ha már sokat küldtünk egy ciklus alatt (pl. egy burst), adjunk esélyt a GUI-nak frissíteni
                    if ticks_sent > 10:
                        break
                else:
                    break # A következő tick a jövőben van, várjunk a következő ciklusra

            # GUI kímélő szünet - fontos hogy a GUI szál ne fagyjon le a sok emittől
            time.sleep(0.01)

    def set_position(self, percentage):
        if self.total_rows > 0:
            self.current_idx = int((percentage / 100.0) * (self.total_rows - 1))
            self.last_real_time = 0.0 # Force clock reset on seek

    def set_speed(self, new_speed):
        self.speed = float(new_speed)

    def toggle_pause(self):
        self.paused = not self.paused
        if self.paused: self.last_real_time = 0.0 # Force clock reset
        return self.paused

# --- DYNAMIC BAR DELEGATE ---
class DOMBarDelegate(QStyledItemDelegate):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.max_vol = 1

    def set_max_vol(self, mv):
        self.max_vol = mv if mv > 0 else 1

    def paint(self, painter, option, index):
        painter.save()

        bg_color_role = index.data(Qt.BackgroundRole)
        if bg_color_role:
            if isinstance(bg_color_role, QBrush): painter.fillRect(option.rect, bg_color_role.color())
            else: painter.fillRect(option.rect, bg_color_role)
        else:
            painter.fillRect(option.rect, QColor(11, 14, 20))

        text = index.data(Qt.DisplayRole)
        col = index.column()

        is_current_price = index.data(Qt.UserRole)

        # Sárga háttér CSAK a középső (Árfolyam) oszlopban
        if is_current_price and col == 1:
            painter.fillRect(option.rect, QColor(252, 213, 53, 50))

        if text and text.replace('.', '', 1).isdigit():
            if col == 0 or col == 2:
                vol = int(float(text))
                if vol > 0:
                    width_ratio = min(vol / self.max_vol, 1.0)
                    bar_width = int(option.rect.width() * width_ratio)

                    if col == 0:
                        bar_rect = QRect(option.rect.right() - bar_width, option.rect.top() + 4, bar_width, option.rect.height() - 8)
                        painter.fillRect(bar_rect, QColor(0, 230, 118, 60))
                        painter.fillRect(QRect(option.rect.right() - 2, option.rect.top() + 4, 2, option.rect.height() - 8), QColor(0, 230, 118, 200))
                    elif col == 2:
                        bar_rect = QRect(option.rect.left(), option.rect.top() + 4, bar_width, option.rect.height() - 8)
                        painter.fillRect(bar_rect, QColor(255, 82, 82, 60))
                        painter.fillRect(QRect(option.rect.left(), option.rect.top() + 4, 2, option.rect.height() - 8), QColor(255, 82, 82, 200))

        # Szöveg kiírása a sávok FELÉ
        text_color_role = index.data(Qt.ForegroundRole)
        if text_color_role:
            if isinstance(text_color_role, QBrush): painter.setPen(text_color_role.color())
            else: painter.setPen(text_color_role)
        else:
            painter.setPen(QColor(255, 255, 255))

        align = index.data(Qt.TextAlignmentRole)
        if not align: align = Qt.AlignCenter | Qt.AlignVCenter

        text_rect = option.rect.adjusted(10, 0, -10, 0)
        painter.drawText(text_rect, align, text if text else "")

        painter.restore()


# --- PYQT5 NATIVE UI ---
class DOMWindow(QMainWindow):
    def __init__(self, player):
        super().__init__()
        self.setWindowTitle("🧱 Tőzsdei DOM Monitor (OFFLINE PLAYER)")
        self.resize(500, 800)
        self.setStyleSheet("background-color: #121212; color: #ffffff;")
        self.depth_levels = 10
        self.tick_size_estimate = 0.05
        self.history_imbalance = []
        self.player = player

        self.init_ui()

        self.timer = QTimer()
        self.timer.timeout.connect(self.update_gui)
        self.timer.start(100) # Gyors GUI frissités

        emitter.data_updated.connect(self.update_gui)

    def init_ui(self):
        central_widget = QWidget()
        layout = QVBoxLayout(central_widget)

        # --- PLAYER CONTROLS ---
        from PyQt5.QtWidgets import QComboBox
        control_layout = QHBoxLayout()
        self.btn_play_pause = QPushButton("⏸ Pause")
        self.btn_play_pause.clicked.connect(self.toggle_playback)
        self.btn_play_pause.setStyleSheet("background-color: #fcd535; color: black; font-weight: bold; padding: 10px; border-radius: 5px;")

        self.cb_speed = QComboBox()
        self.cb_speed.addItems(["1x", "5x", "10x", "50x", "100x"])
        self.cb_speed.setCurrentText("10x")
        self.cb_speed.currentTextChanged.connect(self.change_speed)
        self.cb_speed.setStyleSheet("background-color: #2b2b2b; color: white; padding: 10px; border-radius: 5px; font-weight: bold;")

        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(0, 100)
        self.slider.setValue(0)
        self.slider.sliderMoved.connect(self.seek_position)

        control_layout.addWidget(self.btn_play_pause)
        control_layout.addWidget(self.cb_speed)
        control_layout.addWidget(self.slider)
        layout.addLayout(control_layout)

        # --- KPI Header ---
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

        # --- Anomália Panel ---
        self.lbl_anom = QLabel("Várakozás DOM adatokra...")
        self.lbl_anom.setAlignment(Qt.AlignCenter)
        self.lbl_anom.setStyleSheet("background-color: #1e1e1e; padding: 10px; border-radius: 5px; font-weight: bold; font-size: 13px;")
        layout.addWidget(self.lbl_anom)

        # --- Összegző Sáv (Imbalance Bar) ---
        imb_layout = QHBoxLayout()
        imb_layout.setSpacing(0)

        # A bal oldalon van a Bid (Vétel) logikailag a táblázatban is.
        # A felhasználó kérése: a Bid (zöld) térjen ki a saját irányába (balra), az Ask (piros) pedig jobbra.
        self.imb_bar_bid = QProgressBar()
        self.imb_bar_bid.setRange(0, 100)
        self.imb_bar_bid.setValue(0)
        self.imb_bar_bid.setTextVisible(False)
        self.imb_bar_bid.setInvertedAppearance(True) # A bal oldali sáv jobbról balra nő ki a középpontból
        self.imb_bar_bid.setFixedHeight(10)
        self.imb_bar_bid.setStyleSheet("""
            QProgressBar { border: none; background-color: #1e1e1e; }
            QProgressBar::chunk { background-color: #228B22; } /* Erdőzöld */
        """)

        self.imb_bar_ask = QProgressBar()
        self.imb_bar_ask.setRange(0, 100)
        self.imb_bar_ask.setValue(0)
        self.imb_bar_ask.setTextVisible(False)
        self.imb_bar_ask.setFixedHeight(10)
        self.imb_bar_ask.setStyleSheet("""
            QProgressBar { border: none; background-color: #1e1e1e; }
            QProgressBar::chunk { background-color: #B22222; } /* Téglavörös */
        """)

        imb_layout.addWidget(self.imb_bar_bid)
        imb_layout.addWidget(self.imb_bar_ask)
        layout.addLayout(imb_layout)

        # --- DOM Létra Táblázat ---
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

    def toggle_playback(self):
        is_paused = self.player.toggle_pause()
        self.btn_play_pause.setText("▶ Play" if is_paused else "⏸ Pause")

    def seek_position(self, value):
        self.player.set_position(value)

    def change_speed(self, text):
        speed_val = float(text.replace('x', ''))
        self.player.set_speed(speed_val)

    def get_dom_data(self, live_data):
        mid_price = live_data['price']
        if mid_price == 0.0: mid_price = 150.00

        # Mivel a brókerek az utolsó 0-kat sokszor lehagyják a floatok végéről (pl. 4081.50 -> 4081.5),
        # az egyszerű tizedesjegy-számlálás nagyon ugráló tick size-t okozhat.
        # Megbízhatóbb, ha az aktuális 1. és 2. szint közötti távolságból próbálunk deriválni,
        # vagy egy kőkemény fixet adunk a BTCUSD/XAUUSD-hez. (0.1 a Micro Gold, 1.0 a BTC)

        # Próbáljuk meg kikövetkeztetni a valós lépésközt az Ask_Price_1 és Ask_Price_2 különbségéből (ha van)
        inferred_tick = 0.0
        if live_data['ap2'] > 0 and live_data['ap1'] > 0:
            inferred_tick = round(abs(live_data['ap2'] - live_data['ap1']), 5)
        elif live_data['bp1'] > 0 and live_data['bp2'] > 0:
            inferred_tick = round(abs(live_data['bp1'] - live_data['bp2']), 5)

        # Extrém erős kikényszerítés a rács illeszkedésére!
        # SOHA ne hagyatkozzunk csak a bróker csonkolt különbségére. Megnézzük a tizedesjegyek valós számát is!
        decimal_tick = 0.0
        str_price = str(live_data['bp1']) if live_data['bp1'] > 0 else str(live_data['price'])
        if '.' in str_price:
            decimals = len(str_price.split('.')[1])
            decimal_tick = 1.0 / (10 ** decimals)

        if inferred_tick > 0:
            self.tick_size_estimate = min(inferred_tick, decimal_tick) if decimal_tick > 0 else inferred_tick
        else:
            self.tick_size_estimate = decimal_tick if decimal_tick > 0 else 0.1

        # BTC Fallback override: Ha a bróker "0.18"-at ad vissza tick különbségnek (spread hiba miatt), a grid szétesik.
        # Mindig kerekítsük le a legközelebbi power-of-10-re (pl 0.1, 0.01)
        import math
        if self.tick_size_estimate > 0:
            power = math.floor(math.log10(self.tick_size_estimate))
            self.tick_size_estimate = 10 ** power

        if self.tick_size_estimate < 0.00001: self.tick_size_estimate = 0.00001

        mid_rounded = np.round(mid_price / self.tick_size_estimate) * self.tick_size_estimate

        best_bid = live_data['bp1'] if live_data['bp1'] > 0 else mid_rounded - self.tick_size_estimate
        best_ask = live_data['ap1'] if live_data['ap1'] > 0 else mid_rounded + self.tick_size_estimate

        # Új Dinamikus Viewport (Grid) Számítás, ami nem ignorálja a hatalmas spread-et.
        # A probléma: ha a Spread hatalmas (pl. 300 dollár BTC-n), akkor a grid 300/0.01 = 30000 soros lenne!
        # Ha a korábbi logika egyszerűen "levágta" 200 sorra a gridet a Mid Price körül, akkor a valós A1 és B1 árak (amik mondjuk 300 dollárra vannak)
        # fizikailag KIESTEK a generált táblázatból, ezért dobtuk el őket!

        # A megoldás: Ha a Spread óriási (mert a demó bróker furcsa), akkor is be kell foglalni az A1 és B1 árakat a gridbe!
        # Tehát mindig a TÉNYLEGES best_ask és best_bid a viewport két határa (plusz némi padding).

        top_price = best_ask + (self.depth_levels * self.tick_size_estimate)
        if live_data['ap2'] > 0: top_price = max(top_price, live_data['ap2'] + (self.depth_levels * self.tick_size_estimate))

        bottom_price = best_bid - (self.depth_levels * self.tick_size_estimate)
        if live_data['bp2'] > 0: bottom_price = min(bottom_price, live_data['bp2'] - (self.depth_levels * self.tick_size_estimate))

        # Új Erős Kompresszió a Spread alapján:
        # A felhasználó kérése alapján a Bid és Ask ne a képernyő két legszélére szoruljon extrém spread esetén.
        # Ehelyett úgy számoljuk a dinamikus tick_size-t, hogy a TÉNYLEGES SPREAD (best_ask - best_bid)
        # nagyjából 4-5 sort (köztes rést) tegyen ki a rács közepén.
        # Így a Spread felett és alatt is marad elég hely (sor) a további depth szinteknek (ap2, bp2 stb.).
        spread = best_ask - best_bid
        target_spread_rows = 5.0

        if spread / self.tick_size_estimate > target_spread_rows:
             raw_tick = spread / target_spread_rows
             # Matematikai kerekítés értelmes kereskedési lépésközre (pl. 64.24 -> 50 vagy 100)
             # Hogy az árak vizuálisan emberiek maradjanak, és a rács egy stabil ponthoz horgonyozzon.
             magnitude = 10 ** np.floor(np.log10(raw_tick))
             normalized = raw_tick / magnitude
             if normalized < 1.5:
                 step = 1.0
             elif normalized < 3.5:
                 step = 2.0
             elif normalized < 7.5:
                 step = 5.0
             else:
                 step = 10.0
             self.tick_size_estimate = step * magnitude

        # Ahelyett, hogy folyamatosan a változó best_ask/best_bid köré építenénk a rácsot
        # (ami miatt a sávok sosem mozognának fel/le, hanem az árak ugrálnának mellettük),
        # A rácsot egy stabil ponthoz (Mid Price) horgonyozzuk le, ami kerekítve van a lépésközre.
        mid_anchor = np.round(mid_price / self.tick_size_estimate) * self.tick_size_estimate

        # A top és bottom ár innentől a stabil horgonyponthoz képest fix távolságra van!
        # Ha extrém nagy ugrás van az árban, a horgony (és így a rács) követi, de egy ticken belül
        # az ask és bid sávok tudnak liftezni fel és le a fix rácson.
        target_half_rows = int(self.depth_levels * 1.5) # Kicsit több puffer a kompresszió miatt

        top_price = mid_anchor + (target_half_rows * self.tick_size_estimate)
        bottom_price = mid_anchor - (target_half_rows * self.tick_size_estimate)

        prices = np.arange(top_price, bottom_price - self.tick_size_estimate, -self.tick_size_estimate)
        prices = np.round(prices, 5)

        # A felhasználó kérése: Ne legyen 2-2 zöld/piros sáv egyetlen Bid vagy Ask szint miatt!
        # A laza tolerancia miatt előfordult, hogy egy valós ár két szomszédos Grid szinthez is bekerült.
        # Megoldás: Hozzuk létre üresen a listákat, majd KIKERESSÜK az EGYETLEN LEGJOBBAN ILLESZKEDŐ (closest) sort.
        bids = [0] * len(prices)
        asks = [0] * len(prices)

        # Segédfüggvény, amely megkeresi a legközelebbi indexet a `prices` tömbben
        def find_closest_index(target_price):
            if target_price <= 0: return -1
            return int(np.argmin(np.abs(prices - target_price)))

        # 1. Ask Level 2
        if live_data['av2'] > 0 and live_data['ap2'] > 0:
            idx = find_closest_index(live_data['ap2'])
            if idx != -1: asks[idx] = live_data['av2']

        # 2. Ask Level 1 (ez felülírja a Level 2-t, ha pont ugyanabba a sorba esnek a kompresszió miatt)
        if live_data['av1'] > 0 and live_data['ap1'] > 0:
            idx = find_closest_index(live_data['ap1'])
            if idx != -1: asks[idx] = live_data['av1']

        # 3. Bid Level 1
        if live_data['bv1'] > 0 and live_data['bp1'] > 0:
            idx = find_closest_index(live_data['bp1'])
            if idx != -1: bids[idx] = live_data['bv1']

        # 4. Bid Level 2 (csak akkor írja felül, ha valamiért egybe esne a B1-el, ami nem logikus, de biztosítjuk)
        if live_data['bv2'] > 0 and live_data['bp2'] > 0:
            idx = find_closest_index(live_data['bp2'])
            if idx != -1 and bids[idx] == 0: bids[idx] = live_data['bv2']

        spread_value = max(0, best_ask - best_bid)

        # --- DIAGNOSZTIKA: Bemenet vs. Kimenet ellenőrzése ---
        # A file alapú logolást kikommenteljük a performancia miatt, a terminalba írunk helyette ha van hiányzó
        matched_asks = sum([1 for a in asks if a > 0])
        matched_bids = sum([1 for b in bids if b > 0])
        input_asks = sum([1 for v in [live_data['av1'], live_data['av2']] if v > 0])
        input_bids = sum([1 for v in [live_data['bv1'], live_data['bv2']] if v > 0])

        if (input_asks > 0 and matched_asks == 0) or (input_bids > 0 and matched_bids == 0):
            print(f"[HIBA] Tick elveszett a rácson! Epoch: {live_data['time']} | Grid top: {top_price} | A1: {live_data['ap1']} B1: {live_data['bp1']}")

        # Nagyon fontos: Mivel `prices` matematikai tömb, visszatérünk annak az indexével is,
        # hogy a GUI-ban a spread pontosan tudja, mely sorok esnek a Bid és Ask KÖZÉ.
        ask1_idx = find_closest_index(best_ask)
        bid1_idx = find_closest_index(best_bid)

        return prices, bids, asks, best_bid, best_ask, spread_value, ask1_idx, bid1_idx

    def update_gui(self):
        current_data = LATEST_DOM_DATA.copy()
        prices, bids, asks, best_bid, best_ask, spread, ask1_idx, bid1_idx = self.get_dom_data(current_data)

        # --- Imbalance Logika ---
        av1, av2 = current_data['av1'], current_data['av2']
        bv1, bv2 = current_data['bv1'], current_data['bv2']
        total_ask = av1 + av2
        total_bid = bv1 + bv2

        imbalance = 0.0
        if (total_ask + total_bid) > 0:
            imbalance = (total_bid - total_ask) / (total_bid + total_ask)

        self.history_imbalance.append(imbalance)
        if len(self.history_imbalance) > 100: self.history_imbalance.pop(0)
        mean_imbalance = sum(self.history_imbalance) / len(self.history_imbalance) if self.history_imbalance else 0

        # --- Összegző Sáv Update ---
        # A felhasználó kérése: mindkét sáv egyszerre jelenjen meg a volumenek arányában.
        # Ha total_ask = 60 és total_bid = 40, akkor a piros sáv 60%-ig, a zöld 40%-ig ér.
        if (total_ask + total_bid) > 0:
            bid_pct = int((total_bid / (total_ask + total_bid)) * 100)
            ask_pct = int((total_ask / (total_ask + total_bid)) * 100)
            self.imb_bar_bid.setValue(bid_pct)
            self.imb_bar_ask.setValue(ask_pct)
        else:
            self.imb_bar_bid.setValue(0)
            self.imb_bar_ask.setValue(0)

        # --- KPI & Anomália Update ---
        if best_bid > 0 and best_ask > 0 and current_data['price'] > 0:
            self.lbl_bid.setText(f"Legjobb Vétel:\n{best_bid:.5f}")
            self.lbl_ask.setText(f"Legjobb Eladás:\n{best_ask:.5f}")
            self.lbl_spread.setText(f"Spread:\n{spread:.5f}")

            if mean_imbalance < -0.3:
                self.lbl_anom.setText("⚠️ KONZISZTENS ELADÓI (ASK) NYOMÁS")
                self.lbl_anom.setStyleSheet("background-color: #aa5500; color: white; padding: 10px; border-radius: 5px; font-weight: bold; font-size: 13px;")
            elif mean_imbalance > 0.3:
                self.lbl_anom.setText("⚠️ KONZISZTENS VÉTELI (BID) NYOMÁS")
                self.lbl_anom.setStyleSheet("background-color: #00aa55; color: white; padding: 10px; border-radius: 5px; font-weight: bold; font-size: 13px;")
            else:
                self.lbl_anom.setText("✅ DOM KIEGYENLÍTETT (STABIL ÁTLAG)")
                self.lbl_anom.setStyleSheet("background-color: #008800; color: white; padding: 10px; border-radius: 5px; font-weight: bold; font-size: 13px;")

        # A dinamikus max volumen alapja kikerült a kőbevésett 10-ből, mert Bitcoin esetén a 160+ lotok
        # azonnal kiakasztották, viszont csendesebb piacon (pl Micro Gold 1-2 lot) aránytalanul eltűntek.
        # Inkább egy dinamikus padlót használunk, ami mindig alkalmazkodik.
        current_max_vol = 1
        if bids: current_max_vol = max(current_max_vol, max(bids))
        if asks: current_max_vol = max(current_max_vol, max(asks))

        # Hogy egy 1 lot-os izolált tick ne ugrássza be a képernyő 100%-át Micro Goldon:
        if current_max_vol < 10: current_max_vol = 10

        self.delegate.set_max_vol(current_max_vol)

        # Formázó string a megfelelő tizedesjegyhez
        decimal_format = f"{{:.{max(0, int(-np.floor(np.log10(self.tick_size_estimate))))}f}}" if self.tick_size_estimate < 1 else "{:.2f}"

        self.table.setRowCount(len(prices))
        for i in range(len(prices)):
            price = prices[i]
            bid_vol = bids[i]
            ask_vol = asks[i]

            item_bid = QTableWidgetItem(str(bid_vol) if bid_vol > 0 else "")
            item_bid.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)

            # Dinamikus formázás (pl. BTC 2 tizedes, EURUSD 5 tizedes)
            price_str = decimal_format.format(price)
            item_price = QTableWidgetItem(price_str)
            item_price.setTextAlignment(Qt.AlignCenter | Qt.AlignVCenter)
            item_ask = QTableWidgetItem(str(ask_vol) if ask_vol > 0 else "")
            item_ask.setTextAlignment(Qt.AlignLeft | Qt.AlignVCenter)

            # Ahhoz, hogy a grid vizuálisan pontos legyen a Spread esetén, a sorok fizikai pozíciójára
            # (indexére) kell hagyatkoznunk, nem a dinamikusan tömörített `price`-ra, ami átcsúszhat a tolerancián.
            # Mivel a `prices` tömb csökkenő (legmagasabb ár van legfelül/0. index), az Ask indexe kisebb, mint a Bid indexe.

            is_spread_row = False
            if ask1_idx != -1 and bid1_idx != -1:
                # Két érvényes indexünk van, minden ami közöttük van (exkluzív) az a spread
                if ask1_idx < i < bid1_idx:
                    is_spread_row = True

            if ask_vol > 0:
                item_ask.setForeground(QColor(255, 82, 82))
                item_price.setBackground(QColor(19, 23, 34)); item_price.setForeground(QColor(255, 82, 82))
                item_ask.setBackground(QColor(11, 14, 20)); item_bid.setBackground(QColor(11, 14, 20))
            elif bid_vol > 0:
                item_bid.setForeground(QColor(0, 230, 118))
                item_price.setBackground(QColor(19, 23, 34)); item_price.setForeground(QColor(0, 230, 118))
                item_ask.setBackground(QColor(11, 14, 20)); item_bid.setBackground(QColor(11, 14, 20))
            elif is_spread_row:
                bg_spread = QColor(30, 34, 45); bg_spread_price = QColor(42, 46, 57)
                item_bid.setBackground(bg_spread); item_ask.setBackground(bg_spread)
                item_price.setBackground(bg_spread_price); item_price.setForeground(QColor(120, 123, 134))
            else:
                item_bid.setBackground(QColor(11, 14, 20)); item_ask.setBackground(QColor(11, 14, 20))
                item_price.setBackground(QColor(19, 23, 34)); item_price.setForeground(QColor(200, 200, 200))

            if abs(price - current_data['price']) <= (self.tick_size_estimate / 2.0) and current_data['price'] > 0:
                item_bid.setData(Qt.UserRole, True)
                item_price.setData(Qt.UserRole, True)
                item_ask.setData(Qt.UserRole, True)
                item_price.setForeground(QColor(252, 213, 53))

            self.table.setItem(i, 0, item_bid)
            self.table.setItem(i, 1, item_price)
            self.table.setItem(i, 2, item_ask)

        # Update Slider
        if self.player.total_rows > 0 and not self.slider.isSliderDown():
            pct = int((self.player.current_idx / self.player.total_rows) * 100)
            self.slider.blockSignals(True)
            self.slider.setValue(pct)
            self.slider.blockSignals(False)

if __name__ == '__main__':
    import os
    import glob

    # 1. Automatikus keresés a raw mappában a legfrissebb DOM fájlra
    raw_dir = "/home/misi/Merkava_ML_Ops/data/raw/"
    csv_file = None

    if os.path.exists(raw_dir):
        # Keresünk minden DOM_Data kezdetű fájlt, és a legújabbat választjuk (időbélyegtől függetlenül)
        dom_files = glob.glob(os.path.join(raw_dir, "DOM_Data*.csv"))
        if dom_files:
            csv_file = max(dom_files, key=os.path.getmtime)

    # 2. Fallback a lokális mappára, ha a saját gépen fut
    if not csv_file or not os.path.exists(csv_file):
        local_files = glob.glob("DOM_Data*.csv")
        if local_files:
            csv_file = max(local_files, key=os.path.getmtime)
        else:
            csv_file = "DOM_Data.csv" # Végső fallback

    if not os.path.exists(csv_file):
        print(f"[HIBA] Nem talalhato CSV fajl! ({csv_file}) - Kerlek, tolts le egyet a mappaba!")
        sys.exit(1)

    player = CSVDOMPlayer(filepath=csv_file, speed=10.0) # 10x-es gyorsított lejátszás
    player.start()

    app = QApplication(sys.argv)
    window = DOMWindow(player)
    window.show()
    sys.exit(app.exec_())
