with open("vaku3_dashboard_v9.py", "r", encoding="utf-8") as f:
    content = f.read()

# Completely replace MockDataStream with RealDataStream
mock_start = content.find("class MockDataStream:")
mock_end = content.find("class VakuDashboard(QMainWindow):")

real_class = """class RealDataStream:
    def __init__(self, file_path):
        self.file_path = file_path
        self.df = None
        self.current_idx = 0
        self.instrument_name = "ISMERETLEN"
        
        filename = os.path.basename(file_path)
        if "XAUUSD" in filename: self.instrument_name = "XAUUSD"
        elif "EURUSD" in filename: self.instrument_name = "EURUSD"
        elif "SPY" in filename: self.instrument_name = "SPY"
        
        try:
            print(f"BEOVASÁS: {file_path} (Ez eltarthat egy darabig...)")
            self.df = pd.read_csv(file_path)
            
            if 'TickMSC' not in self.df.columns and 'TimeMsc' in self.df.columns:
                self.df['TickMSC'] = self.df['TimeMsc']
                
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
        return row

"""

content = content[:mock_start] + real_class + content[mock_end:]

# Ensure VakuDashboard uses RealDataStream
content = content.replace("self.stream = MockDataStream(\"reports_tmp/HYBRID_EVAL_EURUSD.csv\")", "self.stream = RealDataStream(\"data/Merkava_XAUUSD_v1.10_20260408_025931.csv\")")

with open("vaku3_dashboard_v9c.py", "w", encoding="utf-8") as f:
    f.write(content)

