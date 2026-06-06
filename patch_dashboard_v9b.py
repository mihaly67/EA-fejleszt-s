import re

with open("vaku3_dashboard_v9.py", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Kicseréljük a MockDataStream hívást a RealDataStream-re (ami beolvassa a 2 napos CSV-t)
if "self.stream = MockDataStream" in content:
    content = content.replace('self.stream = MockDataStream("reports_tmp/HYBRID_EVAL_EURUSD.csv")',
                              'self.stream = RealDataStream("data/Merkava_XAUUSD_v1.10_20260408_025931.csv")')
else:
    content = content.replace('self.stream = RealDataStream("reports_tmp/HYBRID_EVAL_EURUSD.csv")',
                              'self.stream = RealDataStream("data/Merkava_XAUUSD_v1.10_20260408_025931.csv")')

# Győződjünk meg róla, hogy a RealDataStream osztály létezik a V9 fájlban, ha nem, akkor ez egy visszamaradt MockDataStream verzió
# (A V7-ben bevezettük a RealDataStream-et, de lehet, hogy a V8/V9 patch véletlenül a V6 MockStream alapját húzta tovább)

if "class RealDataStream:" not in content:
    # Cseréljük ki a MockDataStream osztályt RealDataStreamre
    mock_class = """class MockDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0

        try:
            if os.path.exists(file_path):
                self.df = pd.read_csv(file_path)
                if 'TickMSC' not in self.df.columns and 'TimeMsc' in self.df.columns:
                    self.df['TickMSC'] = self.df['TimeMsc']
            else:
                self._generate_fake_data()
        except Exception as e:
            print(f"Hiba a fájl betöltésekor: {e}")
            self._generate_fake_data()

    def _generate_fake_data(self):
        print("MOCK ADAT GENERÁLÁSA...")
        N = 10000
        start_time = int(time.time() * 1000)
        unix_time = start_time + (np.arange(N) * 1000)
        price = np.sin(np.linspace(0, 20, N)) * 0.05 + 1.1500 + np.cumsum(np.random.randn(N)*0.001)
        macro_er = np.random.uniform(0.1, 0.9, N)
        risk = np.random.uniform(0, 100, N)
        macro_er = pd.Series(macro_er).rolling(50).mean().fillna(0.5)
        risk = pd.Series(risk).rolling(5).mean().fillna(10)

        decisions = []
        for i in range(N):
            if macro_er[i] >= 0.3 and risk[i] < 20: decisions.append('GREEN')
            elif macro_er[i] >= 0.3 and risk[i] >= 20: decisions.append('YELLOW')
            else: decisions.append('RED')

        self.df = pd.DataFrame({
            'TickMSC': unix_time,
            'Price': price,
            'Macro_ER': macro_er,
            'Theater_Risk_Pct': risk,
            'Hybrid_Decision': decisions,
            'Velocity': np.zeros(N),
            'Hybrid_MACD': np.zeros(N)
        })

    def peek_next_tick_time(self):
        if self.current_idx >= len(self.df):
            return None
        return float(self.df.iloc[self.current_idx]['TickMSC'])

    def get_next_tick(self):
        if self.current_idx >= len(self.df):
            self.current_idx = 0
        row = self.df.iloc[self.current_idx]
        self.current_idx += 1
        return row"""

    real_class = """class RealDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0
        self.instrument_name = "ISMERETLEN"

        # A fájlnévből kinyerjük a devizapárt (pl. Merkava_XAUUSD_v1.10 -> XAUUSD)
        filename = os.path.basename(file_path)
        if "XAUUSD" in filename: self.instrument_name = "XAUUSD"
        elif "EURUSD" in filename: self.instrument_name = "EURUSD"
        elif "SPY" in filename: self.instrument_name = "SPY"

        try:
            print(f"BEOVASÁS: {file_path} (Ez eltarthat egy darabig a nagy méret miatt...)")
            self.df = pd.read_csv(file_path, nrows=100000) # Demóhoz az első 100k tick

            # Időoszlop normalizálása
            if 'TickMSC' not in self.df.columns and 'TimeMsc' in self.df.columns:
                self.df['TickMSC'] = self.df['TimeMsc']

            # Árfolyam normalizálása
            if 'Price' not in self.df.columns:
                if 'Ask' in self.df.columns and 'Bid' in self.df.columns:
                    self.df['Price'] = (self.df['Ask'] + self.df['Bid']) / 2.0
                elif 'Last' in self.df.columns:
                    self.df['Price'] = self.df['Last']
                else:
                    self.df['Price'] = self.df.iloc[:, 1]

            print(f"Sikeresen betöltve: {len(self.df)} tick.")
        except Exception as e:
            print(f"Hiba a fájl betöltésekor: {e}")
            sys.exit(1)

    def peek_next_tick_time(self):
        if self.current_idx >= len(self.df):
            return None
        return float(self.df.iloc[self.current_idx]['TickMSC'])

    def get_next_tick(self):
        if self.current_idx >= len(self.df):
            self.current_idx = 0
        row = self.df.iloc[self.current_idx]
        self.current_idx += 1
        return row"""

    content = content.replace(mock_class, real_class)
    # Plusz update a stream inicializálásra:
    content = content.replace('self.stream = MockDataStream', 'self.stream = RealDataStream')

with open("vaku3_dashboard_v9b.py", "w", encoding="utf-8") as f:
    f.write(content)
